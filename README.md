# RV64I Pipelined CPU

A 5-stage in-order pipelined RISC-V CPU implementing the RV64I base integer instruction set, written in SystemVerilog. Includes full hazard detection, data forwarding, and a bubble-sort demonstration program.

---

## Architecture Overview

The CPU is a classic **5-stage pipeline**: Fetch → Decode → Execute → Memory → Writeback.

```
┌────────┐   IF/ID   ┌────────┐   ID/EX   ┌─────────┐   EX/MEM   ┌──────────┐   MEM/WB   ┌────────────┐
│ Fetch  │ ────────► │ Decode │ ────────► │ Execute │ ─────────► │   Mem    │ ─────────► │ Writeback  │
└────────┘           └────────┘           └─────────┘            └──────────┘            └────────────┘
     ▲                                         │ branch/jump target                              │ rd_data
     └─────────────────────────────────────────┘                                                 │
                        branch redirect                             ┌────────────────────────────┘
                                                                    │ register write
                                                             ┌──────┴──────┐
                                                             │ Register    │
                                                             │   File      │
                                                             └─────────────┘
```

Pipeline registers (`if_id_t`, `id_ex_t`, `ex_mem_t`, `mem_wb_t`) are defined as packed structs in `risc_pkg.sv`.

---

## File Structure

| File | Description |
|---|---|
| `risc_pkg.sv` | Package: opcodes, ALU ops, writeback selectors, pipeline register structs |
| `cpu_top.sv` | Top-level: wires all pipeline stages and memories together |
| `fetch.sv` | PC register, instruction fetch, branch redirect, IF/ID register |
| `decode.sv` | Instruction decode, immediate generation, control signals, ID/EX register |
| `execute.sv` | Forwarding muxes, ALU, branch resolution, EX/MEM register |
| `mem_stage.sv` | Data memory interface, MEM/WB register |
| `alu.sv` | 64-bit ALU supporting all RV64I arithmetic and logic operations |
| `hazard_unit.sv` | Load-use stall detection, EX/MEM and MEM/WB forwarding selects |
| `register_file.sv` | 32 × 64-bit register file; x0 hardwired to 0; write-through read ports |
| `instruction_memory.sv` | 4 KB byte-addressable ROM; initialized from `machine_code.mem` |
| `data_memory.sv` | 4 KB byte-addressable RAM with byte/half/word/double read-write |
| `machine_code.mem` | Hex machine code for the bubble-sort test program |
| `tb_cpu.sv` | Testbench: runs bubble sort, checks registers x20–x27, dumps VCD |

---

## Supported Instructions

### RV64I Base

| Category | Instructions |
|---|---|
| Integer register-register | `ADD`, `SUB`, `AND`, `OR`, `XOR`, `SLL`, `SRL`, `SRA`, `SLT`, `SLTU` |
| Integer register-immediate | `ADDI`, `ANDI`, `ORI`, `XORI`, `SLLI`, `SRLI`, `SRAI`, `SLTI`, `SLTIU` |
| Upper immediate | `LUI`, `AUIPC` |
| Loads | `LB`, `LH`, `LW`, `LD`, `LBU`, `LHU`, `LWU` |
| Stores | `SB`, `SH`, `SW`, `SD` |
| Branches | `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU` |
| Jumps | `JAL`, `JALR` |

### RV64 Word Operations (W-suffix)

`ADDW`, `SUBW`, `SLLW`, `SRLW`, `SRAW`, `ADDIW`, `SLLIW`, `SRLIW`, `SRAIW` — 32-bit operations with sign-extension to 64 bits.

---

## Hazard Handling

### Load-Use Stall
When a load instruction is followed immediately by an instruction that reads the loaded register, the hazard unit inserts a **one-cycle bubble** by stalling the Fetch and Decode stages.

### Data Forwarding
The hazard unit generates two 2-bit forwarding selects (`fwd_sel_a`, `fwd_sel_b`) for both ALU source operands:

| Select | Source |
|---|---|
| `2'b00` | Register file (no hazard) |
| `2'b01` | EX/MEM pipeline register (forward from previous instruction) |
| `2'b10` | MEM/WB pipeline register (forward from two instructions back) |

### Branch Resolution
Branches and jumps are resolved at the end of the Execute stage. On a taken branch or jump, the IF/ID register is **flushed** (one cycle penalty) and the PC is redirected to the computed target.

---

## Memory Map

| Region | Base Address | Size | Description |
|---|---|---|---|
| Instruction memory | `0x0000` | 4 KB | Read-only; loaded from `machine_code.mem` |
| Data memory | `0x0000` | 4 KB | Read/write; byte-addressable |

The test program places its array at data address `0x100` (256 decimal).

---

## Testbench & Demo Program

The included `machine_code.mem` implements a **bubble sort** of 8 integers.

**Input array** (loaded into data memory at `0x100`):
```
[5, 3, 8, 1, 9, 2, 7, 4]
```

**Expected output** (stored back to memory and loaded into registers x20–x27):
```
[1, 2, 3, 4, 5, 7, 8, 9]
```

The testbench runs for up to 600 clock cycles, then prints the sorted values and displays `PASS` or `FAIL`.

---

## Simulation

### Prerequisites

- A SystemVerilog simulator such as **Icarus Verilog (iverilog)**, **ModelSim**, **Vivado xsim**, or **VCS**.
- `machine_code.mem` must be in the simulator's working directory (it is loaded by `instruction_memory.sv` via `$readmemh`).

### Running with Icarus Verilog

```bash
# Compile
iverilog -g2012 -o cpu_sim \
  risc_pkg.sv \
  alu.sv \
  register_file.sv \
  instruction_memory.sv \
  data_memory.sv \
  fetch.sv \
  decode.sv \
  execute.sv \
  mem_stage.sv \
  hazard_unit.sv \
  cpu_top.sv \
  tb_cpu.sv

# Run
vvp cpu_sim
```

Expected output:
```
=== Bubble Sort on RV64I CPU ===
Input:    [5, 3, 8, 1, 9, 2, 7, 4]
Expected: [1, 2, 3, 4, 5, 7, 8, 9]

=== Sorted Array (registers x20-x27) ===
x20 = 1 (expect 1)
x21 = 2 (expect 2)
...
x27 = 9 (expect 9)

PASS
```

### Waveform Viewing

The testbench dumps `cpu_tb.vcd`. Open it with GTKWave or any compatible viewer:

```bash
gtkwave cpu_tb.vcd
```

---

## Design Notes

- **Active-low reset** (`reset_n`): all pipeline registers clear to zero on deassertion.
- **Write-through register file**: reading a register in the same cycle it is written returns the new value, eliminating an additional forwarding path from WB to ID.
- **JALR target**: the LSB of the computed target is cleared to 0 per the RISC-V specification.
- **x0 hardwired**: the register file never writes to register 0, and reads of x0 always return 0.
- **Little-endian memory**: both instruction and data memories assemble words in little-endian byte order.
