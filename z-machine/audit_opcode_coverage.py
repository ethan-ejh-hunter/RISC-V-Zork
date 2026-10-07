import argparse
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple


WORD_ENTRY_RE = re.compile(r"^\s*\.word\s+([A-Za-z_][A-Za-z0-9_]*)")
COMMENT_MNEMONIC_RE = re.compile(r"#.*?,\s*([A-Za-z0-9_']+)\s*$")
LABEL_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*):\s*$")
DISASM_RE = re.compile(r"^\s*[0-9A-Fa-f]+:\s*([A-Za-z_][A-Za-z0-9_]*)")


@dataclass
class TableEntry:
    opcode_hex: str
    mnemonic: str
    handler: str
    line_no: int


TABLE_BASE_OPCODE = {
    "num_0_op_opcode_table": 0xB0,
    "num_1_op_opcode_table": 0x80,
    "num_2_op_opcode_table": 0x00,
    "var_form_opcode_table": 0xE0,
}


MNEMONIC_ALIASES = {
    "return_true": "rtrue",
    "return_false": "rfalse",
    "ret_value": "ret",
    "return": "ret",
    "newline": "new_line",
    "sread": "read",
    "call": "call_vs",
    "jeq": "je",
    "testattr": "test_attr",
    "setattr": "set_attr",
    "clearattr": "clear_attr",
}


TABLE_INDEX_DEFAULTS = {
    "num_0_op_opcode_table": [
        "rtrue",
        "rfalse",
        "print",
        "print_ret",
        "nop",
        "save",
        "restore",
        "restart",
        "ret_popped",
        "pop",
        "quit",
        "new_line",
        "show_status",
        "verify",
        "nop",
        "nop",
    ],
    "num_1_op_opcode_table": [
        "jz",
        "get_sibling",
        "get_child",
        "get_parent",
        "get_prop_len",
        "inc",
        "dec",
        "print_addr",
        "undefined",
        "remove_obj",
        "print_obj",
        "ret",
        "jump",
        "print_paddr",
        "load",
        "undefined",
    ],
    "num_2_op_opcode_table": [
        "undefined",
        "je",
        "jl",
        "jg",
        "dec_chk",
        "inc_chk",
        "jin",
        "test",
        "or",
        "and",
        "test_attr",
        "set_attr",
        "clear_attr",
        "store",
        "insert_obj",
        "loadw",
        "loadb",
        "get_prop",
        "get_prop_addr",
        "get_next_prop",
        "add",
        "sub",
        "mul",
        "div",
        "mod",
    ],
    "var_form_opcode_table": [
        "call_vs",
        "storew",
        "storeb",
        "put_prop",
        "read",
        "print_char",
        "print_num",
        "random",
        "push",
        "pull",
        "split_window",
        "set_window",
    ],
}


def normalize_mnemonic(name: str) -> str:
    clean = name.strip().lower().replace("'", "")
    return MNEMONIC_ALIASES.get(clean, clean)


def infer_mnemonic_from_handler(handler: str) -> str:
    candidates = [
        "op_0OP_",
        "op_1OP_",
        "op_2OP_",
        "op_VAR_",
        "op_",
    ]
    for prefix in candidates:
        if handler.startswith(prefix):
            return normalize_mnemonic(handler[len(prefix) :])
    return normalize_mnemonic(handler)


def parse_table_entries(opcodes_text: List[str]) -> List[TableEntry]:
    entries: List[TableEntry] = []
    current_table: Optional[str] = None
    current_index = 0

    for idx, line in enumerate(opcodes_text, start=1):
        stripped = line.strip()

        if stripped.endswith(":") and stripped[:-1] in TABLE_BASE_OPCODE:
            current_table = stripped[:-1]
            current_index = 0
            continue

        if stripped in TABLE_BASE_OPCODE:
            current_table = stripped
            current_index = 0
            continue

        if current_table is None:
            continue

        word_match = WORD_ENTRY_RE.match(line)
        if not word_match:
            # if we leave the table region, stop capturing until next table label
            if stripped and not stripped.startswith("#") and not stripped.startswith(".word"):
                if LABEL_RE.match(stripped):
                    current_table = None
            continue

        table_index = current_index
        handler = word_match.group(1)
        opcode = TABLE_BASE_OPCODE[current_table] + current_index
        current_index += 1

        comment_match = COMMENT_MNEMONIC_RE.search(line)
        table_defaults = TABLE_INDEX_DEFAULTS.get(current_table, [])
        default_name = table_defaults[table_index] if table_index < len(table_defaults) else None

        if default_name:
            mnemonic = normalize_mnemonic(default_name)
        elif comment_match:
            mnemonic = normalize_mnemonic(comment_match.group(1))
        else:
            mnemonic = infer_mnemonic_from_handler(handler)

        entries.append(
            TableEntry(
                opcode_hex=f"{opcode:02X}",
                mnemonic=mnemonic,
                handler=handler,
                line_no=idx,
            )
        )
    return entries


def parse_handler_blocks(opcodes_text: List[str]) -> Dict[str, List[str]]:
    labels: List[Tuple[str, int]] = []
    for idx, line in enumerate(opcodes_text):
        m = LABEL_RE.match(line.strip())
        if m:
            labels.append((m.group(1), idx))

    blocks: Dict[str, List[str]] = {}
    for i, (label, start_idx) in enumerate(labels):
        end_idx = labels[i + 1][1] if i + 1 < len(labels) else len(opcodes_text)
        blocks[label] = opcodes_text[start_idx:end_idx]
    return blocks


def parse_disasm_mnemonics(disasm_text: List[str]) -> Set[str]:
    mnemonics: Set[str] = set()
    for line in disasm_text:
        m = DISASM_RE.match(line)
        if m:
            mnemonics.add(normalize_mnemonic(m.group(1)))
    return mnemonics


def is_stub_handler(handler: str, block: Optional[List[str]]) -> bool:
    if handler == "op_UNK_PANIC":
        return True
    if block is None:
        return False

    code_lines = [ln.strip() for ln in block[1:] if ln.strip() and not ln.strip().startswith("#")]
    if not code_lines:
        return True

    if any("ebreak" in ln for ln in code_lines):
        return True

    meaningful = [
        ln
        for ln in code_lines
        if not ln.startswith("addi sp")
        and not ln.startswith("sw ra")
        and not ln.startswith("lw ra")
        and not ln.startswith("ret")
    ]

    if not meaningful:
        return True

    if all(ln.startswith("j op_UNK_PANIC") for ln in meaningful):
        return True

    return False


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Audit opcode coverage: implemented vs stub/missing based on opcodes.s and disassembly output."
    )
    parser.add_argument(
        "--opcodes",
        default="opcodes.s",
        help="Path to opcodes.s",
    )
    parser.add_argument(
        "--disasm",
        default="z-disassemble-trace-addresses.txt",
        help="Path to disassembly text",
    )
    parser.add_argument(
        "--out",
        default="opcode_coverage_report.txt",
        help="Path to write report",
    )
    args = parser.parse_args()

    opcodes_path = Path(args.opcodes)
    disasm_path = Path(args.disasm)
    out_path = Path(args.out)

    opcodes_text = opcodes_path.read_text(encoding="utf-8", errors="replace").splitlines()
    disasm_text = disasm_path.read_text(encoding="utf-8", errors="replace").splitlines()

    table_entries = parse_table_entries(opcodes_text)
    handler_blocks = parse_handler_blocks(opcodes_text)
    used_mnemonics = parse_disasm_mnemonics(disasm_text)

    by_mnemonic: Dict[str, List[TableEntry]] = {}
    for entry in table_entries:
        by_mnemonic.setdefault(entry.mnemonic, []).append(entry)

    implemented: List[str] = []
    stubbed: List[str] = []
    missing_handler: List[str] = []
    not_in_tables: List[str] = []

    for mnemonic in sorted(used_mnemonics):
        entries = by_mnemonic.get(mnemonic)
        if not entries:
            not_in_tables.append(mnemonic)
            continue

        # Consider mnemonic implemented if any mapped handler exists and is not stub.
        has_real = False
        has_stub = False
        has_missing = False

        for entry in entries:
            block = handler_blocks.get(entry.handler)
            if block is None and entry.handler != "op_UNK_PANIC":
                has_missing = True
                continue
            if is_stub_handler(entry.handler, block):
                has_stub = True
            else:
                has_real = True

        if has_real:
            implemented.append(mnemonic)
        elif has_missing:
            missing_handler.append(mnemonic)
        elif has_stub:
            stubbed.append(mnemonic)
        else:
            missing_handler.append(mnemonic)

    all_stub_entries = [
        e
        for e in table_entries
        if e.mnemonic not in {"undefined", "unused", "unassigned", "unimplemented"}
        and is_stub_handler(e.handler, handler_blocks.get(e.handler))
    ]

    lines: List[str] = []
    lines.append(f"opcodes_file={opcodes_path}")
    lines.append(f"disasm_file={disasm_path}")
    lines.append(f"used_mnemonics={len(used_mnemonics)}")
    lines.append("")

    lines.append(f"Used & implemented ({len(implemented)}):")
    lines.extend([f"  - {m}" for m in sorted(implemented)])
    lines.append("")

    lines.append(f"Used but stubbed ({len(stubbed)}):")
    lines.extend([f"  - {m}" for m in sorted(stubbed)])
    lines.append("")

    lines.append(f"Used but missing handler label ({len(missing_handler)}):")
    lines.extend([f"  - {m}" for m in sorted(set(missing_handler))])
    lines.append("")

    lines.append(f"Used in disassembly but not present in opcode tables ({len(not_in_tables)}):")
    lines.extend([f"  - {m}" for m in sorted(not_in_tables)])
    lines.append("")

    lines.append("All stub table entries (including unused):")
    for entry in all_stub_entries:
        lines.append(
            f"  - opcode 0x{entry.opcode_hex:>2} mnemonic={entry.mnemonic} handler={entry.handler} (line {entry.line_no})"
        )

    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote report to {out_path}")


if __name__ == "__main__":
    main()
