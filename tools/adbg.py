#!/usr/bin/env python3
import argparse
import socket
import logging
import cmd
import signal
import struct
import shlex
import re
from capstone import Cs, CS_ARCH_X86, CS_MODE_16, CS_MODE_32

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("adbg_cli")

FAS_SIG = 0x1A736166

def u8(b, o): return b[o]
def u16(b, o): return struct.unpack_from("<H", b, o)[0]
def u32(b, o): return struct.unpack_from("<I", b, o)[0]
def u64(b, o): return struct.unpack_from("<Q", b, o)[0]
def i32(b, o): return struct.unpack_from("<i", b, o)[0]

class FasFile:
	def __init__(self, data: bytes):
		self.data = data
		self.header_len = 0
		self.off_str = self.len_str = 0
		self.off_sym = self.len_sym = 0
		self.off_src = self.len_src = 0
		self.off_asm = self.len_asm = 0
		self.off_secn = self.len_secn = 0
		self.off_syref = self.len_syref = 0

		self.input_name_off = 0
		self.output_name_off = 0

		self.section_names = []
		self.symbols = []
		self.addr2line = {}
		self._parse_header()
		self._parse_sections()
		self._parse_symbols()
		self._parse_asm_dump_addr2line()

	def _parse_header(self):
		b = self.data
		if len(b) < 16:
			raise ValueError("FAS: too small")
		sig = u32(b, 0)
		if sig != FAS_SIG:
			raise ValueError("FAS: bad signature")
		maj = u8(b, 4)
		min_ = u8(b, 5)
		self.header_len = u16(b, 6)

		self.input_name_off = u32(b, 8)
		self.output_name_off = u32(b, 12)
		self.off_str = u32(b, 16)
		self.len_str = u32(b, 20)

		if self.header_len >= 64:
			self.off_sym = u32(b, 24); self.len_sym = u32(b, 28)
			self.off_src = u32(b, 32); self.len_src = u32(b, 36)
			self.off_asm = u32(b, 40); self.len_asm = u32(b, 44)
			self.off_secn = u32(b, 48); self.len_secn = u32(b, 52)
			self.off_syref = u32(b, 56); self.len_syref = u32(b, 60)

		logger.debug(f"FAS header: v{maj}.{min_}, hdr={self.header_len} bytes, "
					 f"strings@{self.off_str}+{self.len_str}, syms@{self.off_sym}+{self.len_sym}, "
					 f"src@{self.off_src}+{self.len_src}, asm@{self.off_asm}+{self.len_asm}")

	def _bounds(self, off, length):
		if off == 0 or length == 0:
			return False
		if off + length > len(self.data):
			return False
		return True

	def get_str_from_strtab(self, off_in_strtab) -> str:
		if off_in_strtab == 0:
			return ""
		start = self.off_str + off_in_strtab
		end = self.data.find(b"\x00", start, self.off_str + self.len_str)
		if end == -1:
			end = self.off_str + self.len_str
		return self.data[start:end].decode("utf-8", errors="replace")

	def get_cstr_from_preproc(self, off_in_preproc) -> str:
		if off_in_preproc == 0:
			return ""
		start = self.off_src + off_in_preproc
		end = self.data.find(b"\x00", start, self.off_src + self.len_src)
		if end == -1:
			end = self.off_src + self.len_src
		return self.data[start:end].decode("utf-8", errors="replace")

	def get_pascal_from_preproc(self, off_in_preproc) -> str:
		if off_in_preproc == 0:
			return ""
		p = self.off_src + off_in_preproc
		if p >= self.off_src + self.len_src:
			return ""
		ln = u8(self.data, p)
		s = self.data[p+1:p+1+ln]
		return s.decode("utf-8", errors="replace")

	def _parse_sections(self):
		self.section_names = []
		if self._bounds(self.off_secn, self.len_secn) and self.len_secn % 4 == 0:
			count = self.len_secn // 4
			for i in range(count):
				off = u32(self.data, self.off_secn + i*4)
				self.section_names.append(self.get_str_from_strtab(off))

	def _parse_symbols(self):
		self.symbols = []
		if not self._bounds(self.off_sym, self.len_sym):
			return
		if self.len_sym % 32 != 0:
			logger.warning("FAS: symbols table length is not multiple of 32 bytes")
		n = self.len_sym // 32
		for i in range(n):
			base = self.off_sym + i*32
			val = u64(self.data, base+0)
			flags = u16(self.data, base+8)
			size = u8(self.data, base+10)
			vtype = struct.unpack_from("<b", self.data, base+11)[0]
			exsib = u32(self.data, base+12)
			pass_def = u16(self.data, base+16)
			pass_use = u16(self.data, base+18)
			reloc_info = u32(self.data, base+20)
			name_off = u32(self.data, base+24)
			def_line_off = u32(self.data, base+28)

			if name_off == 0:
				name = ""
			elif (name_off & 0x80000000) != 0:
				name = self.get_str_from_strtab(name_off & 0x7FFFFFFF)
			else:
				name = self.get_pascal_from_preproc(name_off)

			sym = {
				"value": val,
				"flags": flags,
				"size": size,
				"type": vtype,
				"exsib": exsib,
				"pass_def": pass_def,
				"pass_use": pass_use,
				"reloc": reloc_info,
				"name": name,
				"def_line_off": def_line_off,
			}
			self.symbols.append(sym)

	def decode_line_meta(self, line_off: int):
		if line_off == 0 or not self._bounds(self.off_src + line_off, 16):
			return None

		o = self.off_src + line_off
		f0 = u32(self.data, o + 0)
		f1 = u32(self.data, o + 4)
		f2 = u32(self.data, o + 8)
		f3 = u32(self.data, o + 12)

		generated = True if (f1 & 0x80000000) != 0 else False
		line_no = (f1 & 0x7FFFFFFF)

		if generated:
			macro = self.get_pascal_from_preproc(f0)
			return {"generated": True, "line_no": line_no, "file": None, "macro_name": macro}
		else:
			if f0 == 0:
				file_name = self.get_str_from_strtab(self.input_name_off)
			else:
				file_name = self.get_cstr_from_preproc(f0)
			return {"generated": False, "line_no": line_no, "file": file_name, "macro_name": None}

	def _parse_asm_dump_addr2line(self):
		self.addr2line = {}
		if not self._bounds(self.off_asm, self.len_asm) or self.len_asm < 4:
			return
		rows_len = self.len_asm - 4
		if rows_len % 28 != 0:
			rows_len -= (rows_len % 28)
		rows = rows_len // 28
		for i in range(rows):
			base = self.off_asm + i*28
			out_off = u32(self.data, base+0)
			line_off = u32(self.data, base+4)
			addr_lo = u64(self.data, base+8)
			exsib = u32(self.data, base+16)
			reloc = u32(self.data, base+20)
			addr_type = struct.unpack_from("<b", self.data, base+24)[0]
			code_type = u8(self.data, base+25)
			flags = u8(self.data, base+26)
			addr_hi = u8(self.data, base+27)

			if addr_type == 0:
				addr = (addr_hi << 64) | addr_lo
				lm = self.decode_line_meta(line_off)
				if lm and not lm["generated"] and lm["file"]:
					self.addr2line.setdefault(addr, (lm["file"], lm["line_no"]))

def parse_fas(path):
	with open(path, "rb") as f:
		data = f.read()
	fas = FasFile(data)

	sym2addr = {}
	addr2sym = {}

	for s in fas.symbols:
		name = s["name"]
		if not name:
			continue
		if (s["flags"] & 0x0001) == 0:
			continue

		val = int(s["value"] & 0xFFFFFFFFFFFFFFFF)
		if name not in sym2addr:
			sym2addr[name] = val
		addr2sym.setdefault(val, name)

	return sym2addr, addr2sym, fas

class RSPClient:
	def __init__(self, host, port, timeout=0.5):
		self.sock = socket.create_connection((host, port), timeout)
		self.sock.settimeout(timeout)
		try:
			self._read_packet()
		except IOError:
			pass

	def _checksum(self, data: bytes) -> int:
		return sum(data) % 256

	def _read_packet(self) -> str:
		while True:
			ch = self.sock.recv(1)
			if not ch:
				raise IOError("Disconnected")
			if ch == b'$':
				break
		data = bytearray()
		while True:
			ch = self.sock.recv(1)
			if not ch:
				raise IOError("Disconnected")
			if ch == b'#':
				break
			data += ch

		self.sock.recv(2)

		self.sock.send(b'+')
		return data.decode()

	def _send_packet(self, payload: str) -> str:
		raw = payload.encode()
		chk = self._checksum(raw)
		pkt = b"$" + raw + b"#" + f"{chk:02x}".encode()
		self.sock.send(pkt)
		ack = self.sock.recv(1)
		if ack != b'+':
			raise IOError("No ACK from stub")
		return self._read_packet()

	def get_regs(self) -> dict:
		raw = self._send_packet("g")
		names = ["EAX","ECX","EDX","EBX","ESP","EBP","ESI","EDI",
				 "EIP","EFLAGS","CS","SS","DS","ES","FS","GS"]
		regs = {}
		for i, n in enumerate(names):
			chunk = raw[i*8:(i+1)*8]
			le = "".join(chunk[j:j+2] for j in (6,4,2,0))
			regs[n] = int(le, 16)
		return regs

	def read_mem(self, addr: int, length: int) -> bytes:
		resp = self._send_packet(f"m{addr:x},{length:x}")
		if resp.startswith('E') and len(resp) == 3:
			raise IOError(f"Read error {resp}")
		return bytes(int(resp[i:i+2],16) for i in range(0,len(resp),2))

	def write_mem(self, addr: int, data: bytes):
		hexdata = ''.join(f'{b:02x}' for b in data)
		resp = self._send_packet(f"M{addr:x},{len(data):x}:{hexdata}")
		if resp != "OK":
			raise IOError(f"Write failed: {resp}")

	def step(self):
		self._send_packet("s")

	def cont(self):
		self._send_packet("c")

	def set_break(self, addr: int):
		self._send_packet(f"Z0,{addr:x},1")

	def remove_break(self, addr: int):
		self._send_packet(f"z0,{addr:x},1")

	def set_watch(self, addr: int, kind: int = 3, length: int = 1):
		self._send_packet(f"Z{kind},{addr:x},{length:x}")

	def remove_watch(self, addr: int, kind: int = 3, length: int = 1):
		self._send_packet(f"z{kind},{addr:x},{length:x}")

class Disassembler:
	def __init__(self, default_mode="x86_16"):
		self.mode = default_mode
		self.cs = Cs(CS_ARCH_X86,
					 CS_MODE_16 if default_mode=="x86_16" else CS_MODE_32)

	def update_mode(self, regs: dict):
		vm86 = bool(regs["EFLAGS"] & (1 << 17))
		new_mode = "x86_16" if vm86 else "x86_32"
		if new_mode != self.mode:
			self.mode = new_mode
			m = CS_MODE_16 if vm86 else CS_MODE_32
			self.cs = Cs(CS_ARCH_X86, m)
			logger.info(f"Switched disassembler to {self.mode}")
		return self.cs

def hexdump(addr: int, data: bytes, width: int = 16):
	for off in range(0, len(data), width):
		line = data[off:off+width]
		hexpart = ' '.join(f'{b:02x}' for b in line)
		asciipart = ''.join(chr(b) if 32 <= b < 127 else '.' for b in line)
		print(f"0x{addr+off:08x}: {hexpart:<{width*3}} {asciipart}")

class MergedFas:
	def __init__(self, fas_list):
		self.addr2line = {}
		for fas in fas_list:
			for addr, src in fas.addr2line.items():
				self.addr2line.setdefault(addr, src)

class ADbgCLI(cmd.Cmd):
	intro = (
		"adbg_cli — simple assembly debugger\n"
		"Type `help` or `?` to list commands.\n"
	)
	prompt = "(adbg) "

	def __init__(self, rsp: RSPClient, dasm: Disassembler,
				 sym2addr: dict, addr2sym: dict, fas: FasFile, default_reg_width: int = 32):
		super().__init__()
		self.rsp = rsp
		self.dasm = dasm
		self.sym2addr = sym2addr
		self.addr2sym = addr2sym
		self.fas = fas

		self.breakpoints = {}
		self.next_bp_id = 1

		self.watchpoints = {}
		self.next_wp_id = 1

		self.reg_width = default_reg_width

	def resolve(self, tok: str) -> int:
		tok = tok.strip().lstrip('*')

		m = re.match(r'^(.*?)([+-])(0x[0-9a-fA-F]+|\d+)$', tok)
		if m:
			base = self.resolve(m.group(1))
			off = int(m.group(3), 0)
			return base + off if m.group(2) == '+' else base - off

		if tok in self.sym2addr:
			return self.sym2addr[tok]

		if tok.startswith('.'):
			matches = [n for n in self.sym2addr if n.endswith(tok)]
			if len(matches) == 1:
				return self.sym2addr[matches[0]]
			if len(matches) > 1:
				raise ValueError(f"Ambiguous local {tok}; candidates: "
								+ ", ".join(matches[:8]) + (" ..." if len(matches) > 8 else ""))
			raise ValueError(f"Unknown local label: {tok}")

		if '.' in tok:
			base, local = tok.split('.', 1)
			for b in (base, '_' + base, base.lstrip('_')):
				cand = f"{b}.{local}"
				if cand in self.sym2addr:
					return self.sym2addr[cand]

		tail = '.' + tok
		matches = [n for n in self.sym2addr if n.endswith(tail)]
		if len(matches) == 1:
			return self.sym2addr[matches[0]]
		if len(matches) > 1:
			raise ValueError(f"Ambiguous local '{tok}'; try one of: "
							+ ", ".join(matches[:8]) + (" ..." if len(matches) > 8 else ""))

		if tok.lower().startswith('0x'):
			return int(tok, 16)
		if tok.isdigit():
			return int(tok)

		raise ValueError(f"Unknown symbol/address: {tok}")


	_gp32 = ["EAX","ECX","EDX","EBX","ESP","EBP","ESI","EDI"]
	_segs = ["CS","SS","DS","ES","FS","GS"]

	def _get_reg(self, regs: dict, name: str) -> int:
		n = name.upper()
		if n in regs:
			return regs[n]

		if n == "IP":
			return regs["EIP"] & 0xFFFF
		if n == "FLAGS":
			return regs["EFLAGS"] & 0xFFFF

		base_map = {
			"AX":"EAX","CX":"ECX","DX":"EDX","BX":"EBX",
			"SP":"ESP","BP":"EBP","SI":"ESI","DI":"EDI"
		}
		if n in base_map:
			return regs[base_map[n]] & 0xFFFF

		lohi = {
			"AL":"EAX","AH":"EAX",
			"CL":"ECX","CH":"ECX",
			"DL":"EDX","DH":"EDX",
			"BL":"EBX","BH":"EBX",
		}
		if n in lohi:
			v = regs[lohi[n]]
			if n[1] == 'L':
				return v & 0xFF
			else:
				return (v >> 8) & 0xFF

		raise KeyError(f"Unknown register '{name}'")

	def print_regs(self, width: int = None):
		regs = self.rsp.get_regs()
		width = width or self.reg_width

		if width == 32:
			names = self._gp32 + ["EIP","EFLAGS"] + self._segs
			for i in range(0,len(names),2):
				a = names[i]
				b = names[i+1] if i+1 < len(names) else None
				line = f"{a:6}=0x{regs[a]:08x}"
				if b:
					valb = regs[b] & (0xFFFFFFFF if b not in self._segs else 0xFFFF)
					if b in self._segs:
						line += f"   {b:6}=0x{valb:04x}"
					else:
						line += f"   {b:6}=0x{valb:08x}"
				print(line)
		elif width == 16:
			names = ["AX","CX","DX","BX","SP","BP","SI","DI","IP","FLAGS"] + self._segs
			vals = {n: self._get_reg(regs, n) for n in names}
			for i in range(0,len(names),2):
				a = names[i]
				b = names[i+1] if i+1 < len(names) else None
				line = f"{a:6}=0x{vals[a]&0xFFFF:04x}"
				if b:
					line += f"   {b:6}=0x{vals[b]&0xFFFF:04x}"
				print(line)
		elif width == 8:
			names = ["AL","CL","DL","BL","AH","CH","DH","BH"]
			for i in range(0,len(names),2):
				a = names[i]
				b = names[i+1]
				va = self._get_reg(regs, a)
				vb = self._get_reg(regs, b)
				print(f"{a:6}=0x{va&0xFF:02x}   {b:6}=0x{vb&0xFF:02x}")
			spl = regs["ESP"] & 0xFF
			sph = (regs["ESP"] >> 8) & 0xFF
			print(f"{'SPL':6}=0x{spl:02x}   {'SPH':6}=0x{sph:02x}")
		else:
			print("Unsupported register width; use 8, 16, or 32.")

	def _nearest_symbol(self, addr: int):
		best = None
		best_addr = None
		for name, a in self.sym2addr.items():
			if a <= addr and (best_addr is None or a > best_addr):
				best, best_addr = name, a
		if best is None:
			return None
		return best, best_addr, addr - best_addr

	def print_disasm(self, count=5, addr=None):
		regs = self.rsp.get_regs()
		if addr is None:
			addr = regs["EIP"]
		code = self.rsp.read_mem(addr, count*16)
		md = self.dasm.update_mode(regs)
		for ins in md.disasm(code, addr):
			mark = ""
			if ins.address in self.breakpoints.values():
				mark = "*"
			elif any(ins.address == w[0] for w in self.watchpoints.values()):
				mark = "w"

			sym = self.addr2sym.get(ins.address)
			if not sym:
				near = self._nearest_symbol(ins.address)
				if near and near[2] == 0:
					sym = near[0]
			if sym:
				print(f"{sym}:")

			src = self.fas.addr2line.get(ins.address)
			if src:
				print(f"  ; {src[0]}:{src[1]}")

			print(f"  0x{ins.address:08x}: {ins.mnemonic} {ins.op_str}{mark}")

	def do_step(self, arg):
		try:
			self.rsp.step()
			self.print_disasm(1)
		except Exception as e:
			print(f"Step error: {e}")
	do_s = do_step

	def do_cont(self, arg):
		try:
			self.rsp.cont()
			self.print_disasm(1)
		except Exception as e:
			print(f"Continue error: {e}")
	do_c = do_cont

	def do_regs(self, arg):
		a = arg.strip()
		if a in ("8","16","32","-8","-16","-32"):
			self.reg_width = int(a.lstrip('-'))
		self.print_regs()

	def help_regs(self):
		print("regs [8|16|32]   - show registers; optional width switches view and becomes default")

	def do_reg(self, arg):
		parts = arg.split()
		if not parts:
			print("Usage: reg <name> [8|16|32]")
			return
		name = parts[0]
		width = int(parts[1]) if len(parts) > 1 else self.reg_width
		try:
			regs = self.rsp.get_regs()
			val = self._get_reg(regs, name)
			if width == 8:
				print(f"{name.upper():>6} = 0x{val & 0xFF:02x}")
			elif width == 16:
				print(f"{name.upper():>6} = 0x{val & 0xFFFF:04x}")
			else:
				if name.upper() in regs:
					print(f"{name.upper():>6} = 0x{val & 0xFFFFFFFF:08x}")
				else:
					mask = 0xFF if len(name)==2 and name[1].lower() in ('h','l') else 0xFFFF
					fmt = "02x" if mask==0xFF else "04x"
					print(f"{name.upper():>6} = 0x{val & mask:{fmt}}")
		except Exception as e:
			print(e)

	def do_stack(self, arg):
		n = int(arg,0) if arg else 16
		regs = self.rsp.get_regs()
		esp = regs["ESP"]
		try:
			data = self.rsp.read_mem(esp, n*4)
		except Exception as e:
			print(f"Stack read error: {e}")
			return
		for i in range(n):
			off = esp + i*4
			val = int.from_bytes(data[i*4:(i+1)*4],"little")
			print(f"0x{off:08x}: 0x{val:08x}")

	def do_disasm(self, arg):
		parts = arg.split()
		addr = None
		cnt = 5
		if parts:
			if (parts[0].lower().startswith("0x")
				or parts[0] in self.sym2addr
				or re.match(r'.+[+-](0x[0-9a-fA-F]+|\d+)$', parts[0])):
				try:
					addr = self.resolve(parts[0])
				except ValueError as e:
					print(e)
					return
				if len(parts)>1:
					cnt = int(parts[1],0)
			else:
				try:
					cnt = int(parts[0],0)
				except ValueError:
					print(f"Invalid argument: {parts[0]}")
					return
		self.print_disasm(cnt, addr)

	def do_break(self, arg):
		if not arg:
			print("Usage: break <addr|symbol>")
			return
		try:
			addr = self.resolve(arg.strip())
		except ValueError as e:
			print(e); return
		try:
			self.rsp.set_break(addr)
		except Exception as e:
			print(f"Breakpoint error: {e}")
			return
		bid = self.next_bp_id; self.next_bp_id += 1
		self.breakpoints[bid] = addr
		print(f"Breakpoint {bid} @0x{addr:08x}")
	do_b = do_break

	def do_delete(self, arg):
		if not arg.isdigit():
			print("Usage: delete <breakpoint-id>")
			return
		bid = int(arg)
		if bid not in self.breakpoints:
			print(f"No such breakpoint {bid}")
			return
		addr = self.breakpoints.pop(bid)
		self.rsp.remove_break(addr)
		print(f"Deleted breakpoint {bid}")

	def do_watch(self, arg):
		parts = arg.split()
		if not parts:
			print("Usage: watch [r|w|a] <addr|symbol> [length]")
			return
		kind_map = {"w":1, "r":2, "a":3}
		kind = 3
		length = 1
		if parts[0].lower() in kind_map and len(parts)>=2:
			kind = kind_map[parts[0].lower()]
			symtok = parts[1]
			if len(parts)>=3:
				length = int(parts[2],0)
		else:
			symtok = parts[0]
			if len(parts)>=2:
				length = int(parts[1],0)
		try:
			addr = self.resolve(symtok)
		except ValueError as e:
			print(e); return
		try:
			self.rsp.set_watch(addr, kind, length)
		except Exception as e:
			print(f"Watchpoint error: {e}")
			return
		wid = self.next_wp_id; self.next_wp_id += 1
		self.watchpoints[wid] = (addr, kind, length)
		kn = {1:"write",2:"read",3:"access"}[kind]
		print(f"Watchpoint {wid} ({kn}) @0x{addr:08x} length={length}")

	def do_unwatch(self, arg):
		if not arg.isdigit():
			print("Usage: unwatch <watchpoint-id>")
			return
		wid = int(arg)
		if wid not in self.watchpoints:
			print(f"No such watchpoint {wid}")
			return
		addr, kind, length = self.watchpoints.pop(wid)
		self.rsp.remove_watch(addr, kind, length)
		print(f"Deleted watchpoint {wid}")

	def do_info(self, arg):
		sub = arg.strip().lower()
		if sub in ("regs","registers"):
			self.print_regs()
		elif sub in ("bp","breakpoints"):
			for bid, a in sorted(self.breakpoints.items()):
				sym = self.addr2sym.get(a, "")
				print(f"{bid}: 0x{a:08x} {sym}")
		elif sub in ("watch","watchpoints","watches"):
			for wid, (a, kind, length) in sorted(self.watchpoints.items()):
				sym = self.addr2sym.get(a,"")
				kn = {1:"write",2:"read",3:"access"}[kind]
				print(f"{wid}: 0x{a:08x} {sym} ({kn}, len={length})")
		elif sub in ("lines","src","source"):
			shown = 0
			for addr, (f,lno) in sorted(self.fas.addr2line.items())[:50]:
				print(f"0x{addr:08x} -> {f}:{lno}")
				shown += 1
			if shown == 0:
				print("No addr->source mappings available (likely no absolute $ addresses).")
		else:
			print("Usage: info regs|bp|watch|lines")

	def do_symbols(self, arg):
		q = arg.strip()
		if q.startswith('~'):
			pat = re.compile(q[1:])
			names = [s for s in self.sym2addr if pat.search(s)]
		elif q:
			names = [s for s in self.sym2addr if s.startswith(q) or s.endswith('.'+q)]
		else:
			names = sorted(self.sym2addr)
		for s in sorted(names):
			print(f"{s:40} 0x{self.sym2addr[s]:08x}")

	def do_peek(self, arg):
		try:
			parts = shlex.split(arg)
			if not parts:
				print("Usage: peek <addr|sym> [length] [size]")
				return
			addr = self.resolve(parts[0])
			length = int(parts[1], 0) if len(parts) >= 2 else 64
			size = int(parts[2], 0) if len(parts) >= 3 else 1
			data = self.rsp.read_mem(addr, length)
			if size == 1:
				hexdump(addr, data)
			else:
				if size not in (2,4,8):
					print("Size must be 1,2,4, or 8"); return
				for off in range(0, len(data), size*4):
					chunk = data[off:off+size*4]
					vals = []
					for i in range(0, len(chunk), size):
						v = int.from_bytes(chunk[i:i+size], 'little', signed=False)
						vals.append(f"0x{v:0{size*2}x}")
					print(f"0x{addr+off:08x}: " + " ".join(vals))
		except Exception as e:
			print(f"Peek error: {e}")

	def do_poke(self, arg):
		try:
			parts = shlex.split(arg)
			if len(parts) < 2:
				print("Usage: poke <addr|sym> <hexbytes|string>")
				return
			addr = self.resolve(parts[0])
			payload = parts[1]
			if re.fullmatch(r'[0-9a-fA-F]+', payload) and len(payload) % 2 == 0:
				data = bytes(int(payload[i:i+2], 16) for i in range(0, len(payload), 2))
			else:
				data = payload.encode('utf-8', errors='surrogatepass')
			self.rsp.write_mem(addr, data)
			print(f"Wrote {len(data)} bytes at 0x{addr:08x}")
		except Exception as e:
			print(f"Poke error: {e}")

	def _typed_poke(self, arg, size: int):
		try:
			parts = shlex.split(arg)
			if len(parts) < 2:
				print(f"Usage: poke{ {1:'b',2:'w',4:'l',8:'q'}[size] } <addr|sym> <value> [count]")
				return
			addr = self.resolve(parts[0])
			value = int(parts[1], 0)
			count = int(parts[2], 0) if len(parts) >= 3 else 1
			data = value.to_bytes(size, 'little', signed=False) * count
			self.rsp.write_mem(addr, data)
			print(f"Wrote {count} x {size}-byte value at 0x{addr:08x}")
		except Exception as e:
			print(f"Poke error: {e}")

	def do_pokeb(self, arg): self._typed_poke(arg, 1)
	def do_pokew(self, arg): self._typed_poke(arg, 2)
	def do_pokel(self, arg): self._typed_poke(arg, 4)
	def do_pokeq(self, arg): self._typed_poke(arg, 8)

	def do_peekf(self, arg):
		try:
			import struct as pystruct
			parts = shlex.split(arg)
			if len(parts) < 2:
				print("Usage: peekf <addr|sym> <struct-fmt> [count]")
				return
			addr = self.resolve(parts[0])
			fmt  = parts[1]
			if not fmt or fmt[0] not in "@=<>!":
				fmt = "<" + fmt
			count = int(parts[2],0) if len(parts) >= 3 else 1
			sz = pystruct.calcsize(fmt)
			data = self.rsp.read_mem(addr, sz*count)
			for i in range(count):
				tup = pystruct.unpack_from(fmt, data, i*sz)
				print(f"0x{addr+i*sz:08x}: {tup if len(tup)>1 else tup[0]}")
		except Exception as e:
			print(f"peekf error: {e}")

	def do_pokef(self, arg):
		try:
			import struct as pystruct
			parts = shlex.split(arg)
			if len(parts) < 3:
				print("Usage: pokef <addr|sym> <struct-fmt> <v1> [v2 ...]")
				return
			addr = self.resolve(parts[0])
			fmt  = parts[1]
			if not fmt or fmt[0] not in "@=<>!":
				fmt = "<" + fmt
			vals = []
			for v in parts[2:]:
				try:
					vals.append(int(v,0))
				except ValueError:
					vals.append(float(v))
			data = pystruct.pack(fmt, *vals)
			self.rsp.write_mem(addr, data)
			print(f"Wrote struct ({fmt}) of {len(data)} bytes at 0x{addr:08x}")
		except Exception as e:
			print(f"pokef error: {e}")

	def do_q(self, arg): return True
	def do_quit(self, arg): return True
	def do_exit(self, arg): return True
	def do_EOF(self, arg):
		print()
		return True

def main() -> int:
	parser = argparse.ArgumentParser(description="adbg_cli — simple assembly debugger")
	parser.add_argument("--host", default="127.0.0.1", help="RSP host")
	parser.add_argument("--port", type=int, default=1234, help="RSP port")
	parser.add_argument("--fas-file", default="build/spark.fas",
						help=".fas symbolic info file (fasm -s); "
							 "use comma to load multiple files")
	parser.add_argument("--timeout", type=float, default=0.5, help="socket timeout (s)")
	parser.add_argument("--reg-width", choices=["8","16","32"], default="32",
						help="default register view width for `regs`/`reg`")
	args = parser.parse_args()

	paths = [p.strip() for p in args.fas_file.split(',') if p.strip()]
	if not paths:
		print("No .fas files specified")
		return 1

	merged_sym2addr = {}
	merged_addr2sym = {}
	fas_list = []
	loaded_any = False
	for p in paths:
		try:
			s2a, a2s, fas = parse_fas(p)
			loaded_any = True
			for name, addr in s2a.items():
				if name not in merged_sym2addr:
					merged_sym2addr[name] = addr
				elif merged_sym2addr[name] != addr:
					logger.warning("Symbol '%s' address conflict: 0x%x vs 0x%x (keeping first)",
								   name, merged_sym2addr[name], addr)
			for addr, name in a2s.items():
				merged_addr2sym.setdefault(addr, name)
			fas_list.append(fas)
			logger.info("Loaded FAS: %s (symbols: %d, lines: %d)",
						p, len(s2a), len(fas.addr2line))
		except FileNotFoundError:
			logger.error(".fas file not found: %s", p)
		except Exception as e:
			logger.error("Failed to parse .fas (%s): %s", p, e)

	if not loaded_any:
		print("Failed to load any .fas files.")
		return 1

	fas_merged = MergedFas(fas_list)

	try:
		rsp = RSPClient(args.host, args.port, timeout=args.timeout)
	except Exception as e:
		print(f"Failed to connect to {args.host}:{args.port}: {e}")
		return 1

	dasm = Disassembler()
	cli = ADbgCLI(rsp, dasm, merged_sym2addr, merged_addr2sym, fas_merged,
				  default_reg_width=int(args.reg_width))

	signal.signal(signal.SIGINT, lambda s,f: cli.do_quit(None))
	cli.cmdloop()

if __name__ == "__main__":
	raise SystemExit(main())
