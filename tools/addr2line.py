#!/usr/bin/env python3
import argparse
import os
import sys
import re
import bisect
from pathlib import Path
from typing import Dict, List, Tuple, Optional

from adbg.adbg import FasFile

Addr2LineRec = Tuple[str, int, str, bool]


def _parse_addr(tok: str) -> Optional[int]:
    tok = tok.strip()
    if not tok:
        return None
    m = re.match(r"^(0x[0-9a-fA-F]+|\d+)$", tok)
    if not m:
        return None
    try:
        return int(tok, 0)
    except ValueError:
        return None


def _basename(path: str) -> str:
    return os.path.basename(path) if path else path


def _load_fas(
    paths: List[str],
) -> Tuple[Dict[int, Addr2LineRec], Dict[int, str], Dict[str, int]]:
    addr2line_map: Dict[int, Addr2LineRec] = {}
    addr2sym: Dict[int, str] = {}
    sym2addr: Dict[str, int] = {}

    for p in paths:
        data = Path(p).read_bytes()
        fas = FasFile(data)
        for addr, rec in fas.addr2line.items():
            addr2line_map.setdefault(int(addr), rec)

        for s in getattr(fas, "symbols", []):
            name = s.get("name") or ""
            if not name:
                continue
            flags = s.get("flags", 0)
            if (flags & 0x0001) == 0:
                continue
            addr = int(s.get("value", 0)) & 0xFFFFFFFFFFFFFFFF
            if name not in sym2addr:
                sym2addr[name] = addr
            addr2sym.setdefault(addr, name)

    return addr2line_map, addr2sym, sym2addr


def _build_sorted_keys(d: Dict[int, object]) -> List[int]:
    xs = sorted(d.keys())
    return xs


def _lookup_addr(
    addr: int,
    addr2line_map: Dict[int, Addr2LineRec],
    nearest_radius: int,
    sorted_addrs: List[int],
) -> Optional[Addr2LineRec]:
    rec = addr2line_map.get(addr)
    if rec:
        return rec
    if nearest_radius <= 0 or not sorted_addrs:
        return None

    i = bisect.bisect_right(sorted_addrs, addr) - 1
    if i >= 0:
        a0 = sorted_addrs[i]
        if 0 <= addr - a0 <= nearest_radius:
            return addr2line_map.get(a0)
    return None


def format_output(
    addr: int,
    rec: Optional[Addr2LineRec],
    func: Optional[str],
    *,
    pretty: bool,
    basenames: bool,
) -> List[str]:
    if rec is None:
        file_part = "??:0"
    else:
        file_name, line_no, macro_name, generated = rec
        if basenames:
            file_name = _basename(file_name)
        if generated and macro_name:
            file_part = f"macro:{macro_name}#{line_no}"
        else:
            file_part = f"{file_name}:{line_no}" if file_name else f"??:{line_no}"

    func_txt = func or "??"
    if pretty:
        return [f"{func_txt} at {file_part}"]
    else:
        if func is None:
            return [file_part]
        else:
            return [func_txt, file_part]


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Translate addresses to function and file:line using .fas debug information."
    )
    ap.add_argument(
        "-e",
        "--fas",
        action="append",
        required=False,
        help="Path to .fas file (can be repeated).",
    )
    ap.add_argument(
        "-f",
        "--functions",
        action="store_true",
        help="Also print function names. Ignored with -p.",
    )
    ap.add_argument(
        "-p",
        "--pretty-print",
        action="store_true",
        help='Single-line "function at file:line" output.',
    )
    ap.add_argument(
        "-s",
        "--basenames",
        action="store_true",
        help="Strip directory names from paths.",
    )
    ap.add_argument(
        "--nearest",
        type=lambda s: int(s, 0),
        default=0,
        help="Allow nearest-lower mapping within this byte radius if exact address not found.",
    )
    ap.add_argument(
        "addresses",
        nargs="*",
        help="Addresses like 0x401000 or 4198400. If omitted, read one per line from stdin.",
    )
    args = ap.parse_args()

    fas_paths: List[str] = []
    if args.fas:
        fas_paths = args.fas
    else:
        default = os.path.join("build", "spark.fas")
        if os.path.isfile(default):
            fas_paths = [default]
        else:
            print(
                "error: no .fas specified and build/spark.fas not found",
                file=sys.stderr,
            )
            return 2

    try:
        addr2line_map, addr2sym_exact, sym2addr = _load_fas(fas_paths)
    except Exception as e:
        print(f"error: failed to load .fas: {e}", file=sys.stderr)
        return 1

    sorted_addrs = _build_sorted_keys(addr2line_map)
    sym_index: List[Tuple[int, str]] = sorted(
        ((addr, name) for name, addr in sym2addr.items()),
        key=lambda x: x[0],
    )
    sym_addrs = [x[0] for x in sym_index]

    if args.addresses:
        toks = args.addresses
    else:
        toks = [ln.strip() for ln in sys.stdin if ln.strip()]

    addrs: List[int] = []
    for t in toks:
        a = _parse_addr(t)
        if a is None:
            print(f"warning: skipping invalid address token '{t}'", file=sys.stderr)
            continue
        addrs.append(a)

    for idx, a in enumerate(addrs):
        rec = _lookup_addr(a, addr2line_map, args.nearest, sorted_addrs)

        func_name: Optional[str] = None
        if args.pretty_print or args.functions:
            func_name = addr2sym_exact.get(a)
            if func_name is None and sym_index:
                i = bisect.bisect_right(sym_addrs, a) - 1
                if i >= 0:
                    base_addr, name = sym_index[i]
                    radius = args.nearest if args.nearest > 0 else 0x200
                    if 0 <= a - base_addr <= radius:
                        func_name = name

        lines = format_output(
            a,
            rec,
            func_name if (args.pretty_print or args.functions) else None,
            pretty=args.pretty_print,
            basenames=args.basenames,
        )
        for ln in lines:
            print(ln)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
