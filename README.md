# -Diseño_Avanzado_de_Sistemas_Digitales_Semestre_2025_2_Tarea-4
This repository contains the deliverable for IPD432 Assignment 4: a vector coprocessor built around a **Vitis HLS-generated processing core** and an RTL shell integrated in **Vivado** for the **Nexys4 DDR (Artix-7 XC7A100T)**.

The system computes, for `N = 1024` and 10-bit unsigned elements:
- **Dot Product**:  `sum(A[i] * B[i])`
- **Euclidean Distance**: `sqrt(sum((A[i] - B[i])^2))`

Communication with the host PC is via **UART**. Results are shown both:
1) on the **PC** (UART return value), and  
2) on the **7-seg display** (fixed-point visualization, robust to bit width).

> **Important:** This repo does **not** include Vivado project files or `.bit` files. Everything is reproducible locally from sources + the documented build steps.

---

## 1. Repository structure
HLS/
  core.cpp
  core.hpp
  testbench.cpp
  golde_gen.py
  golden_inputs.csv
  golden_ref.csv

Matlab/
  coprocessorTesting.m
  write2dev.m
  command2dev.m

RTL/
  control_out.sv
  coprocessor_top.sv
  display_interface.sv
  rx_control.sv
  wide_mem.sv
  UART_master_const.xdc
  ila_0/
    ila_0.xci
  clk_wiz_0/
    clk_wiz_0.xci
    
LICENSE
README.md

Tested with:
- Board: Nexys4 DDR (Artix-7 XC7A100T)
- UART baud: 115200
- System clock: 100 MHz (clock wizard)

Tools:
- Vitis Unified IDE 2025.1
- Vivado 2025.1

---

## 1) HLS core: final pragma configuration

-`#pragma HLS UNROLL`
- **Euclidean unroll factor:** `U_euc = 128`
- **Dot-product unroll factor:** `U_dot = 64`

### Justification
- Euclidean uses one multiplier per lane (square), so DSP usage grows with `U_euc`.
  `U_euc = 256` exceeds the board DSP budget (240 DSP slices).
- With `U_euc = 128`, dot-product unrolling is constrained by remaining DSP headroom.
  `U_dot = 64` was the best-performing feasible option in the tested set.

- `#pragma HLS ARRAY_PARTITION variable=A cyclic factor=1024 dim=1`  
- `#pragma HLS ARRAY_PARTITION variable=B cyclic factor=1024 dim=1`  
  **Justification:** full partitioning (`factor=1024` for `N=1024`) creates **1024 independent banks** per vector, enabling lane-parallel reads without memory-port stalls. This is the key enabler for unrolling the inner loop (e.g., `U_euc=128`, `U_dot=64`) while maintaining the expected initiation/iteration schedule. The downside is an “interface explosion” (ports `A_0...A_1023`, `B_0...B_1023`), which is handled in RTL using serial-write/parallel-read `wide_mem` blocks.
  
  - `#pragma HLS BIND_OP variable=sq op=mul impl=dsp`  
  **Justification:** forces the squaring multiplication used in Euclidean distance to map onto **DSP48** resources rather than fabric multipliers. This reduces LUT pressure and improves timing/throughput consistency at high unroll factors. Without this constraint, HLS may implement some multiplies in fabric depending on scheduling and resource heuristics, which can increase critical path and degrade QoR under aggressive parallelism.

- `#pragma HLS INTERFACE ap_ctrl_hs port=return`  
  **Justification:** uses the standard HLS handshake control interface (`ap_start`, `ap_done`, `ap_idle`, `ap_ready`) so the RTL shell can cleanly define the **latency boundary** required by the assignment. In hardware, ILA measures latency from `ap_start` to `ap_done`, matching the HLS schedule semantics.

- `#pragma HLS INTERFACE ap_none port=result`  
  **Justification:** exposes `result` as a plain wire (no AXI/stream protocol). This keeps the core boundary minimal and allows the RTL shell to capture the output immediately when `ap_done` asserts, excluding UART overhead as required.

- `#pragma HLS INTERFACE ap_none port=opcode`  
  **Justification:** opcode is a static input during a transaction, so a simple wire is sufficient. This avoids introducing additional handshake overhead and keeps control fully in the RTL shell (UART command decoding → opcode selection → `ap_start`).

- `#pragma HLS INTERFACE ap_none port=A`  
- `#pragma HLS INTERFACE ap_none port=B`  
  **Justification:** exposes the input vectors as direct ports (no BRAM interface). This matches the architectural intent of a “fully partitioned” memory model and removes any ambiguity about memory port counts/latency at the core boundary. The RTL shell therefore provides the vectors as parallel buses via `wide_mem`.

  
### Evidence: dot-product DSE (small table)
The following dot-product configurations were tested with Euclidean fixed at `U_euc=128`:

| (N, U_euc, U_dot) | dot latency (ns) | dot cycles @100MHz | dot DSP | top proc_core DSP |
|---|---:|---:|---:|---:|
| (1024, 128, 1)  | 10310 ns | 1031 | 1  | 129 |
| (1024, 128, 16) | 710 ns   | 71   | 16 | 144 |
| (1024, 128, 64) | 240 ns   | 24   | 64 | 192 |

(Values taken from Vitis HLS module/loop report for `dot_kernel_*` and `proc_core`.)

## 2) Regenerating the HLS RTL (required for review)

The reviewers will regenerate the processing core RTL from the HLS sources in `HLS/`.
Only the top-level HLS files are required (already included): `core.cpp`, `core.hpp`.

### Recommended workflow
1. Open Vitis HLS, create a project using:   
   - File->New Component->HLS, give a Component name and location
   - Configuration File:Empty
   - Top function: proc_core
   - Part:xc7a100tcsg324-1
   - Add sources: `HLS/core.cpp`, `HLS/core.hpp`
   - Add testbench: `HLS/testbench.cpp`,`golden_inputs.csv`,`golden_ref.csv`
3. Apply pragmas corresponding to the final configuration:
   - full partitioning on `A` and `B`
   - `U_euc=128` for Euclidean kernel
   - `U_dot=64` for dot kernel
4. Run:
   - C simulation (optional)
   - C synthesis
   - Package(default settings)
   - 
## 3) Vivado implementation

The RTL shell in `RTL/` integrates:
- UART RX/TX interface
- RX command FSM (loads vectors and starts core)
- wide memories (serial write / parallel read)
- output FSM (captures result and serializes 6 bytes)
- display interface
### How to rebuild locally
From Vivado:
1. Create a new project for xc7a100tcsg324-1 (Nexys4 DDR).
2. Add all RTL sources from `RTL/`.
3. Add the constraints file `RTL/UART_master_const.xdc` .
4. Add the exported HLS IP/RTL generated in the previous step.
5. Generate clock wizard for **100 MHz** core clock (or use the included IP/template if provided).
6. Run synthesis + implementation + generate bitstream.
to import the ip select ip catalog, right click in the folders and select add repository(the folder can be copied from vitis output, under impl folder) ones imported added to the project

Ila instance was added to th repository but left commented in the top module

> The exported RTL/IP must match the instance used in `RTL/` (same ports and parameters),
> especially the **scalar-per-element ports** produced by full partitioning
> (e.g., `A_0 ... A_1023`, `B_0 ... B_1023`) and the `opcode/result/ap_*` control interface.
---

## 4) Operating frequency report (timing closure)

The implemented system targets 100 MHz (10.0 ns period).

- Vitis HLS timing estimate for the core:
  - Target: 10.00 ns
  - Estimated: 7.247 ns
  - Uncertainty: 2.70 ns

- Vivado post-implementation timing at 100 MHz:
  - WNS: `+0.001 ns`
  - WHS: +0.013 ns 
  - 0 failing endpoints
  - Worst path example: `ctrl_inst/mem_wdata_reg → mem_A/mem_reg`

(Recommended: include a screenshot of the Vivado timing summary in your repo if allowed.)

---
## 5) Latency and throughput metrics (how obtained)

### Latency definition 
Processing-core latency only, measured from:
- `ap_start` asserted (operation triggered) to - `ap_done` asserted (result ready to be sent)

Assumptions:
- Input data already loaded in memory
- UART transfer overhead excluded

### Hardware measurement method
Latency was measured with ILA using the sample indices of `ap_start` and `ap_done`:
- cycles = `done_index - start_index`

### Results @ 100 MHz
| Operation | Vitis report (ns) | Expected cycles | ILA measurement (start→done) |
|---|---:|---:|---:|
| Euclidean | 420 ns | 42  | 42 (`554 - 512`) |
| Dot       | 240 ns | 24  | 24 (`536 - 512`) |

### Throughput (core transaction throughput, excluding UART)
Throughput is computed as:

`Throughput = f_core / cycles_per_transaction`

At `f_core = 100 MHz`:
- Dot throughput: `100e6 / 24 ≈ 4.17 M results/s`
- Euclidean throughput: `100e6 / 42 ≈ 2.38 M results/s`

---

## 6) Resource usage (final)

Final integrated system (post-implementation):
- LUT: **24918**
- FF: **49611**
- DSP: **192**
- BRAM: **0**

Note: if Vivado treats the HLS core as a black box at some stages, top-level post-synth may not
attribute all internal DSP/LUT. Post-implementation accounts for the netlist.

## 7) Usability requirement: MATLAB script + golden reference

The system remains usable with a MATLAB workflow similar to Assignment 2:
- generates random vectors
- writes vectors A and B
- runs `eucDist` and `dotProd`
- compares with MATLAB golden reference

Run:
- `Matlab/coprocessorTesting.m`

Helper functions:
- `Matlab/write2dev.m`
- `Matlab/command2dev.m`
## Contact
Daisy Berríos — dberrios@usm.cl
