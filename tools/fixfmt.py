#!/usr/bin/env python3
import re, sys, argparse

DEFAULT_INDENT = 4
COMMENT_SPACE = " "

REGS_RX = re.compile(
    r"\b("
    r"e?(ax|bx|cx|dx|si|di|bp|sp)"
    r"|[abcd]h|[abcd]l"
    r"|[cd]r[0-7]"
    r"|[sd]s|cs|es|fs|gs"
    r")\b", re.IGNORECASE)

DATA_DIRS = {"db","dw","dd","dq","dt","df","du","rb","rw","rd","rq"}
GEN_DIRS  = {
    "equ","include","define","incbin","org","use16","use32","align","section","segment",
    "public","extrn","extrudef","format","macro","endm","struc","endstruc",
    "virtual","end","display","repeat","rept","endrep","irp","irps","iterate",
    "local","label","match","forward","reverse","common","if","else","endif",
    "while","endw","fix","purge","restore","calminstruction","calminvoke","times"
}
FLUSH_LEFT_ALWAYS = {"org","use16","use32","end","format","define","include"}

BLOCK_OPEN  = {"virtual","repeat","rept","while"}
BLOCK_CLOSE = {"end","endw","endrep"}

LABEL_RX = re.compile(r"^\s*([.@]?[A-Za-z_.$?][\w.$@?]*:)(.*)$")
LABEL_DIRECTIVE_RX = re.compile(r"^\s*label\s+[A-Za-z_.$?][\w.$@?]*\b", re.IGNORECASE)
ASSIGN_RX = re.compile(r"^\s*([A-Za-z_.$?][\w.$@?]*)\s*(:?=)\s*(.*?)\s*$")
WS_RX = re.compile(r"[ \t]+")
INSN_LINE_RX = re.compile(r"^\s*([A-Za-z.][A-Za-z0-9.*?@]*)\b(.*)$")

def split_code_comment(line: str):
    code = []; i = 0; in_sq = in_dq = False
    while i < len(line):
        ch = line[i]
        if ch == "'" and not in_dq: in_sq = not in_sq; code.append(ch)
        elif ch == '"' and not in_sq: in_dq = not in_dq; code.append(ch)
        elif ch == ';' and not in_sq and not in_dq:
            return "".join(code).rstrip(), line[i:].rstrip("\n")
        else: code.append(ch)
        i += 1
    return "".join(code).rstrip(), ""

def normalize_comment(code: str, comment: str) -> str:
    if not comment: return ""
    c = comment.lstrip()
    if not c.startswith(';'): c = ';' + c
    return (COMMENT_SPACE + c) if code else c

def apply_outside_quotes(s: str, fn):
    out = []; i = 0; in_sq = in_dq = False; chunk = []
    def flush():
        if chunk:
            out.append(fn("".join(chunk))); chunk.clear()
    while i < len(s):
        ch = s[i]
        if ch == "'" and not in_dq:
            flush(); in_sq = not in_sq; out.append(ch)
        elif ch == '"' and not in_sq:
            flush(); in_dq = not in_dq; out.append(ch)
        else:
            if in_sq or in_dq: out.append(ch)
            else: chunk.append(ch)
        i += 1
    flush()
    return "".join(out)

def compact_mem_brackets(s: str) -> str:
    out = []; i = 0; in_sq = in_dq = False
    while i < len(s):
        ch = s[i]
        if ch == "'" and not in_dq: in_sq = not in_sq; out.append(ch); i+=1; continue
        if ch == '"' and not in_sq: in_dq = not in_dq; out.append(ch); i+=1; continue
        if ch == '[' and not (in_sq or in_dq):
            j = i+1; depth = 1; buf=[]
            while j < len(s) and depth>0:
                if s[j]=='[': depth+=1
                elif s[j]==']': depth-=1; 
                if depth==0: break
                buf.append(s[j]); j+=1
            inner = re.sub(r"\s+","", "".join(buf))
            out.append('['+inner+']'); i = j+1; continue
        out.append(ch); i+=1
    return "".join(out)

def normalize_commas_ops_safe(s: str) -> str:
    def fn(t):
        t = re.sub(r"\s*,\s*", ", ", t)
        t = re.sub(r"[ \t]+", " ", t)
        return t.strip()
    return apply_outside_quotes(s, fn)

def lowercase_regs_safe(s: str) -> str:
    def fn(t): return REGS_RX.sub(lambda m: m.group(0).lower(), t)
    return apply_outside_quotes(s, fn)

def format_data_dir(mnemonic: str, rest: str) -> str:
    if rest.strip() == "": return mnemonic
    parts=[]; cur=[]; in_sq=in_dq=False
    for ch in rest:
        if ch=="'" and not in_dq: in_sq = not in_sq
        elif ch=='"' and not in_sq: in_dq = not in_dq
        if ch==',' and not in_sq and not in_dq:
            parts.append("".join(cur).strip()); cur=[]
        else: cur.append(ch)
    if cur: parts.append("".join(cur).strip())
    return f"{mnemonic} {', '.join(parts)}"

def format_instruction(mnemonic: str, rest: str) -> str:
    low = mnemonic.lower()
    m = mnemonic if (low.endswith('*') and not any(low.startswith(x) for x in ('set','cmov'))) else low
    body = rest.strip()
    if not body: return m
    body = compact_mem_brackets(body)
    body = lowercase_regs_safe(body)
    body = normalize_commas_ops_safe(body)
    return f"{m} {body}"

def is_label_directive(code: str) -> bool:
    return bool(LABEL_DIRECTIVE_RX.match(code))

def is_comment_only(line: str) -> bool:
    return line.lstrip().startswith(';')

def is_assignment(code: str):
    m = ASSIGN_RX.match(code)
    return m.groups() if m else None

def ensure_include_space(mnemonic: str, rest: str) -> str:
    r = rest.lstrip()
    return mnemonic if not r else f"{mnemonic} {r}"

class Context:
    def __init__(self): self.block_depth=0; self.brace_depth=0
    def total_depth(self): return self.block_depth + self.brace_depth
    def scan_braces(self, s: str):
        i=0; in_sq=in_dq=False; delta=0
        while i<len(s):
            ch=s[i]
            if ch=="'" and not in_dq: in_sq=not in_sq
            elif ch=='"' and not in_sq: in_dq=not in_dq
            elif not in_sq and not in_dq:
                if ch=='{': delta+=1
                elif ch=='}': delta-=1
            i+=1
        return delta

def normalize_line(code: str, comment: str, indent: int, ctx: Context) -> str:
    if not code and comment: return comment + "\n"

    depth_now = ctx.total_depth()

    mlabel = LABEL_RX.match(code)
    if mlabel:
        label, rest = mlabel.group(1).strip(), mlabel.group(2)
        pad = " " * (indent * depth_now)
        if not rest.strip():
            line = pad + label
            return line + normalize_comment(line, comment) + "\n"
        body = rest.lstrip()
        m = INSN_LINE_RX.match(body)
        if not m:
            norm_body = WS_RX.sub(" ", body.strip())
            line = pad + (f"{label} {norm_body}" if norm_body else label)
            return line + normalize_comment(line, comment) + "\n"
        mnemonic, rest2 = m.group(1), m.group(2)
        low_mnem = mnemonic.lower()
        if low_mnem in DATA_DIRS:
            inner = format_data_dir(low_mnem, rest2)
        elif low_mnem == "include":
            inner = ensure_include_space("include", rest2)
        elif low_mnem in GEN_DIRS or low_mnem.startswith(('if','end','else','repeat','rept','irp','irps','iterate','match')):
            inner = normalize_commas_ops_safe(mnemonic + rest2)
            inner = inner if low_mnem in FLUSH_LEFT_ALWAYS else inner.lower()
        else:
            inner = format_instruction(mnemonic, rest2)
        line = pad + f"{label} {inner}"
        return line + normalize_comment(line, comment) + "\n"

    massign = is_assignment(code)
    if massign:
        name, op, expr = massign
        expr_norm = expr.strip()
        pad = " " * (indent * depth_now)
        line = f"{pad}{name} {op} {expr_norm}".rstrip()
        return line + normalize_comment(line, comment) + "\n"

    if is_label_directive(code):
        pad = " " * (indent * (depth_now + 1))
        norm = WS_RX.sub(" ", code.strip().lower())
        line = pad + norm
        return line + normalize_comment(line, comment) + "\n"

    m = INSN_LINE_RX.match(code)
    if not m:
        pad = " " * (indent * (depth_now + 1))
        norm = WS_RX.sub(" ", code.strip())
        line = pad + norm
        return line + normalize_comment(line, comment) + "\n"

    mnemonic, rest = m.group(1), m.group(2)
    low_mnem = mnemonic.lower()

    depth_for_line = depth_now
    if low_mnem in BLOCK_CLOSE or low_mnem.startswith("endif"):
        depth_for_line = max(depth_for_line - 1, 0)
    if code.strip().startswith('}'):
        depth_for_line = max(depth_for_line - 1, 0)

    pad = " " * (indent * (depth_for_line + 1))

    if low_mnem in DATA_DIRS:
        body = format_data_dir(low_mnem, rest)
        line = pad + body
    elif low_mnem in GEN_DIRS or low_mnem.startswith(('if','end','else','repeat','rept','irp','irps','iterate','match')):
        tail = normalize_commas_ops_safe(rest)
        if low_mnem == "include":
            built = ensure_include_space("include", tail)
            line = built if low_mnem in FLUSH_LEFT_ALWAYS else pad + built
        elif low_mnem == "times":
            line = pad + ("times" + (" " + tail if tail else ""))
        else:
            built = (mnemonic.lower() + (" " + tail if tail else ""))
            line = built if low_mnem in FLUSH_LEFT_ALWAYS else pad + built
    else:
        body = format_instruction(mnemonic, rest)
        line = pad + body

    line = line + normalize_comment(line, comment) + "\n"

    if low_mnem in BLOCK_OPEN or low_mnem.startswith(("if","match","irp","irps","iterate")):
        ctx.block_depth += 1
    if low_mnem in BLOCK_CLOSE or low_mnem.startswith("endif"):
        ctx.block_depth = max(ctx.block_depth - 1, 0)

    ctx.brace_depth = max(ctx.brace_depth + ctx.scan_braces(code), 0)
    return line

def main():
    p = argparse.ArgumentParser(description="Format FASM (x86) assembly")
    p.add_argument("infile", nargs="?", type=argparse.FileType("r"), default=sys.stdin)
    p.add_argument("outfile", nargs="?", type=argparse.FileType("w"), default=sys.stdout)
    p.add_argument("--indent", type=int, default=DEFAULT_INDENT)
    args = p.parse_args()
    ctx = Context()

    for raw in args.infile:
        raw = raw.rstrip("\n")
        if not raw.strip():
            args.outfile.write("\n"); continue
        if is_comment_only(raw):
            depth = ctx.total_depth()
            if depth>0:
                pad = " " * (args.indent * (depth + 1))
                args.outfile.write(pad + raw.lstrip() + "\n")
            else:
                args.outfile.write(raw + "\n")
            continue
        code, comment = split_code_comment(raw)
        args.outfile.write(normalize_line(code, comment, args.indent, ctx))

if __name__ == "__main__":
    main()
