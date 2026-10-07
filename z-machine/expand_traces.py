import argparse
import os
import re
from typing import Dict, List, Optional


def load_disassembly(filename: str) -> Dict[str, str]:
    disasm: Dict[str, str] = {}
    if not filename or not os.path.exists(filename):
        return disasm

    pattern = re.compile(r"^\s*([0-9a-fA-F]+):\s*(.*)$")
    with open(filename, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            match = pattern.match(line)
            if not match:
                continue
            addr = match.group(1).upper()
            instr = match.group(2).strip()
            disasm[addr] = instr
    return disasm


def normalize_arg(arg: str) -> str:
    clean = arg.strip().replace("0x", "").replace("0X", "")
    if not clean:
        return ""
    return clean.upper()[-4:].zfill(4)


def extract_trace_info(filename: str, is_rars: bool) -> List[dict]:
    trace_info: List[dict] = []

    rars_pattern = re.compile(r"0x0*([0-9a-fA-F]+):0x0*([0-9a-fA-F]+)\s*\[(.*?)\]")
    generic_pattern = re.compile(r"([0-9a-fA-F]+):([0-9a-fA-F]+)\s*\[(.*?)\]")

    with open(filename, "r", encoding="utf-8", errors="replace") as f:
        for raw_line in f:
            line = raw_line.strip()
            if not line:
                continue

            if is_rars:
                match = rars_pattern.search(line)
            else:
                candidate = line.split(">")[-1].strip() if ">" in line else line
                match = generic_pattern.search(candidate)

            if not match:
                continue

            pc = match.group(1).upper()
            opcode = match.group(2).upper()[-2:].zfill(2)
            args_str = match.group(3)
            args = [normalize_arg(a) for a in args_str.split(",") if normalize_arg(a)]

            trace_info.append(
                {
                    "pc": pc,
                    "opcode": opcode,
                    "args": args,
                    "raw": line,
                }
            )

    return trace_info


def format_expanded_rows(trace: List[dict], disasm: Dict[str, str]) -> List[str]:
    rows: List[str] = []
    rows.append("idx | pc | opcode | args | disasm")
    rows.append("----+----+--------+------+-------")

    for idx, entry in enumerate(trace, start=1):
        pc = entry["pc"]
        opcode = entry["opcode"]
        args_text = ", ".join(entry["args"])
        instr = disasm.get(pc, "???")
        rows.append(f"{idx:05d} | {pc} | {opcode} | [{args_text}] | {instr}")

    return rows


def write_expanded_file(
    source_trace: str,
    out_path: str,
    trace: List[dict],
    disasm: Dict[str, str],
    disasm_file: Optional[str],
) -> None:
    rows = format_expanded_rows(trace, disasm)

    with open(out_path, "w", encoding="utf-8") as f:
        f.write(f"source_trace={source_trace}\n")
        f.write(f"disassembly={disasm_file if disasm_file else '<none>'}\n")
        f.write(f"entries={len(trace)}\n\n")
        for row in rows:
            f.write(row)
            f.write("\n")


def default_output_name(trace_path: str) -> str:
    base = os.path.basename(trace_path)
    return os.path.join(os.path.dirname(trace_path), f"{base}.expanded.txt")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Expand full traces into one normalized file per input trace."
    )
    parser.add_argument("zorkmid_trace", help="Path to zorkmid-format trace")
    parser.add_argument("rars_trace", help="Path to rars-format trace")
    parser.add_argument(
        "--disasm",
        default="z-disassemble-trace-addresses.txt",
        help="Disassembly file for instruction text (optional)",
    )
    parser.add_argument(
        "--out-zorkmid",
        default=None,
        help="Output path for expanded zorkmid trace",
    )
    parser.add_argument(
        "--out-rars",
        default=None,
        help="Output path for expanded rars trace",
    )
    args = parser.parse_args()

    disasm = load_disassembly(args.disasm)

    zorkmid = extract_trace_info(args.zorkmid_trace, is_rars=False)
    rars = extract_trace_info(args.rars_trace, is_rars=True)

    out_z = args.out_zorkmid or default_output_name(args.zorkmid_trace)
    out_r = args.out_rars or default_output_name(args.rars_trace)

    write_expanded_file(args.zorkmid_trace, out_z, zorkmid, disasm, args.disasm)
    write_expanded_file(args.rars_trace, out_r, rars, disasm, args.disasm)

    print(f"Wrote {len(zorkmid)} entries -> {out_z}")
    print(f"Wrote {len(rars)} entries -> {out_r}")


if __name__ == "__main__":
    main()
