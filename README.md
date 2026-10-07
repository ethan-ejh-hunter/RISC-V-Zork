# RISC-V Zork

A Z-machine (version 3) interpreter written from scratch in RISC-V assembly,
aimed at running Zork I on a pipelined RV32I processor I built on a Basys 3
FPGA. It started as my final project for BYU ECEN 423 (Computer Organization,
Winter 2026).

The CPU implements a subset of RV32I: no multiply/divide, and every load and
store is word-sized. So byte access to the big-endian story file, and all the
arithmetic, are built from word loads, shifts and masks.

## What's here

About 4,600 lines of hand-written assembly in `z-machine/`:

| File | What it does |
|------|--------------|
| `build.s` | Entry point; pulls in every other file in the right order |
| `main.s` | Startup: reads the story header, sets up the Z-machine stack and the fetch/decode/dispatch loop |
| `opcodes.s` | Instruction decoding (short/long/variable forms) and the opcode implementations, dispatched through jump tables |
| `opcode_utils.s` | Operand fetching, variable load/store, branch and store helpers, call frames |
| `objects.s` | Object tree: parents/siblings/children, attributes, properties, insert/remove |
| `strings.s` | ZSCII text decoding (alphabets, abbreviations), printing, line input |
| `dictionary.s` | Tokenizing input and looking words up in the story's dictionary |
| `z_memory.s` | Byte/word access to big-endian Z-machine memory on a little-endian, word-only CPU |
| `math.s` | Signed multiply, divide and modulo in software |
| `vga.s` | Text output to the FPGA's VGA character display |
| `macros.s`, `constants.s`, `tables.s` | Shared macros (I/O, debug), constants and dispatch tables |

Not implemented yet (stubbed with `ebreak`): `show_status`, `verify`,
`split_window`, `set_window`, `output_stream`, `input_stream`.

### Tooling

The Python scripts in `z-machine/` were used for debugging: comparing
instruction traces against a reference interpreter (`compare_traces.py`,
`expand_traces.py`, `parse_trace.py`), auditing opcode coverage, and dumping
objects, dictionaries and memory maps from a story file. Reference traces came
from `zorkmid/zorkmid.c`, a public-domain Z-machine interpreter and debugger.

## Running it

The story file isn't included. With a copy of `zork1.z3` in `z-machine/`,
create `z-machine/z_game.s`:

```asm
.data
.align 4
.global Z_CODE_BASE
Z_CODE_BASE:
    .incbin "zork1.z3"
```

Then expand it into `.byte` data, which RARS can assemble:

```sh
cd z-machine
python3 embed_zgame.py
java -jar ../tools/rars1_6.jar mc Default build.s
```

`tools/rars1_6.jar` is the [RARS](https://github.com/TheThirdOne/rars)
RISC-V assembler and simulator (MIT license).

On the FPGA, text goes to a VGA display and input comes from the UART at
115200 baud. Memory map: `.text` at `0x00400000`, `.data` at `0x10010000`,
I/O at `0x7f00`, VGA at `0x8000`. The hardware (CPU and course-provided I/O
system) isn't published here.
