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
## Quick start (typical reviewer flow)
1) **Regenerate the HLS core RTL/IP** from `HLS/` (Section 3).  
2) **Build the Vivado design** using the RTL shell in `RTL/` (Section 4).  
3) Program the Nexys4 DDR and run:  
   - `Matlab/coprocessorTesting.m` (Section 8)

## 1. Repository structure

├── HLS/                       # High-Level Synthesis source & verification
│   ├── core.cpp               # Main hardware accelerator C++ source
│   ├── core.hpp               # C++ header definitions
│   ├── testbench.cpp          # C-simulation testbench
│   ├── golde_gen.py           # Python script to generate reference data
│   ├── golden_inputs.csv      # Input vectors for verification
│   └── golden_ref.csv         # Expected output data for verification
│
├── Matlab/                    # Host-side verification & communication scripts
│   ├── coprocessorTesting.m   # Main testing script
│   ├── write2dev.m            # Function to write data to the FPGA
│   └── command2dev.m          # Function to send control commands
│
├── RTL/                       # SystemVerilog/Verilog source files & constraints
│   ├── coprocessor_top.sv     # Top-level module
│   ├── control_out.sv         
│   ├── rx_control.sv          
│   ├── display_interface.sv   
│   ├── wide_mem.sv            
│   ├── data_sync.v            
│   ├── pulse_generator.sv     
│   ├── uart_basic.v           
│   ├── uart_basic_tick_gen.v  
│   ├── uart_rx.v              
│   ├── uart_tx.v              
│   ├── UART_master_const.xdc  # Constraints (Pinout/Timing)
│   ├── ila_0/                 # Integrated Logic Analyzer IP
│   └── clk_wiz_0/             # Clocking Wizard IP
├── LICENSE                    # License information
└── README.md                  # Project documentation

Tested with:
- Board: Nexys4 DDR (Artix-7 XC7A100T)
- UART baud: 115200
- System clock: 100 MHz (clock wizard)

Tools:
- Vitis Unified IDE 2025.1
- Vivado 2025.1
- matlab R2025b

---

## 2) UART command protocol (Assignment usability requirement)

The system keeps the same “MATLAB-script-driven” philosophy as Assignment 2: vectors are loaded over UART, then a compute command triggers the operation, and the result is returned over UART.

### Write vectors
- Command: `W` then bank select `A` or `B`
- Payload: **1024 elements**, each sent as **2 bytes little-endian**:
  - `LO = val[7:0]`
  - `HI = val[9:8]` packed into `HI[1:0]` (upper bits ignored)
- Total payload: `1024 * 2 = 2048 bytes` after `W` and bank byte.

### Compute
- Command: `C` then opcode:
  - `D` = dot product
  - `E` = Euclidean distance

### Return format (PC side)
- Device returns **6 bytes** (48-bit) **little-endian**, two’s complement.
- Value is interpreted as fixed-point **Q32.16** (scaled by `2^-16`).
- Euclidean distance returns a positive Q32.16 value; dot product returns integer-valued Q32.16 (fractional bits are zero).

This protocol is implemented and validated by the MATLAB scripts in `Matlab/`.

---

## 3) HLS core: final pragma configuration (and justification)

Pragmas are applied in `HLS/core.cpp` in the top-level `proc_core` and the per-operation kernels.

### Final unroll configuration
- **Euclidean unroll factor:** `U_euc = 128`
- **Dot-product unroll factor:** `U_dot = 64`

**Justification**
- Euclidean uses one multiplier per lane (square), so DSP usage grows with `U_euc`. `U_euc = 256` exceeds the board DSP budget (240 DSP slices).
- With `U_euc = 128`, dot-product unrolling is constrained by remaining DSP headroom. `U_dot = 64` was the best-performing feasible option in the tested set.

### Interface + mapping pragmas

- `#pragma HLS ARRAY_PARTITION variable=A cyclic factor=1024 dim=1`  
- `#pragma HLS ARRAY_PARTITION variable=B cyclic factor=1024 dim=1`  
  Full partitioning creates **1024 banks per vector**, enabling lane-parallel reads without memory-port stalls. This enables the chosen unroll factors at the core boundary. The downside is a wide interface (`A_0...A_1023`, `B_0...B_1023`), handled in RTL using `wide_mem` serial-write/parallel-read blocks.

- `#pragma HLS BIND_OP variable=sq op=mul impl=dsp`  
  Forces Euclidean squaring multiplications onto **DSP48** (instead of fabric multipliers), reducing LUT pressure and improving timing/throughput stability under high parallelism.

- `#pragma HLS INTERFACE ap_ctrl_hs port=return`  
  Standard HLS handshake (`ap_start/ap_done/...`), used to define the latency boundary and ILA measurement points.

- `#pragma HLS INTERFACE ap_none port=result`  
- `#pragma HLS INTERFACE ap_none port=opcode`  
- `#pragma HLS INTERFACE ap_none port=A`  
- `#pragma HLS INTERFACE ap_none port=B`  
  Keeps the boundary as direct wires (no AXI/stream protocol), so the RTL shell can capture outputs immediately when `ap_done` asserts (excluding UART overhead as required by the assignment).

---

## 4) Evidence: dot-product DSE (small table)

The following dot-product configurations were tested with Euclidean fixed at `U_euc = 128`:

| (N, U_euc, U_dot) | dot latency (ns) | dot cycles @100MHz | dot DSP | top proc_core DSP |
|---|---:|---:|---:|---:|
| (1024, 128, 1)  | 10310 | 1031 | 1  | 129 |
| (1024, 128, 16) | 710   | 71   | 16 | 144 |
| (1024, 128, 64) | 240   | 24   | 64 | 192 |

(Values taken from the Vitis HLS module/loop report for `dot_kernel_*` and `proc_core`.)

---

## 5) Regenerating the HLS RTL/IP (required for review)

Reviewers will regenerate the processing core RTL from the HLS sources in `HLS/`.
Only the top-level HLS files are needed: `core.cpp`, `core.hpp`.

### Vitis HLS steps
1. Open **Vitis HLS** → create a new **HLS Component**.
2. Set:
   - **Top function:** `proc_core`
   - **Part:** `xc7a100tcsg324-1`
3. Add sources:
   - `HLS/core.cpp`, `HLS/core.hpp`
4. Add testbench (optional but recommended):
   - `HLS/testbench.cpp`, `HLS/golden_inputs.csv`, `HLS/golden_ref.csv`
5. Run:
   - C simulation (optional)
   - C synthesis
   - Package (default settings)

---

## 6) Vivado implementation (RTL shell)

The RTL shell in `RTL/` integrates:
- UART RX/TX interface
- RX command FSM (loads vectors and starts the core)
- wide memories (serial write / parallel read)
- output FSM (captures result and serializes 6 bytes)
- display interface (fixed-point visualization)

### How to rebuild locally (Vivado)
1. Create a new Vivado project for **xc7a100tcsg324-1** (Nexys4 DDR).
2. Add all RTL sources from `RTL/`.
3. Add constraints: `RTL/UART_master_const.xdc`.
4. Add the exported HLS IP/RTL generated in Section 5:
   - If packaged as IP: **IP Catalog → Add Repository** and point to the exported IP folder.
5. Ensure a 100 MHz core clock (Clock Wizard `clk_wiz_0`).
6. Run: synthesis → implementation → generate bitstream.

> Note: The HLS-exported module ports must match the instance used in `RTL/coprocessor_top.sv`,
> especially the scalar-per-element ports `A_0...A_1023` and `B_0...B_1023` plus `opcode/result/ap_*`.

### ILA note
An ILA instance is included in the repository (`RTL/ila_0/`) but is left commented in the top module by default.

---

## 7) Operating frequency report (timing closure)

Target system clock: **100 MHz** (10.0 ns period).

- Vitis HLS timing estimate for the core:
  - Target: 10.00 ns
  - Estimated: 7.247 ns
  - Uncertainty: 2.70 ns

- Vivado post-implementation timing @100 MHz:
  - **WNS = +0.001 ns**
  - **WHS = +0.013 ns**
  - **0 failing endpoints**
  - Example worst path: `ctrl_inst/mem_wdata_reg → mem_A/mem_reg`

This demonstrates timing closure at the required operating frequency.

---

## 8) Latency and throughput metrics (how obtained)

### Latency definition
Processing-core latency only, measured from:
- `ap_start` asserted (operation triggered) to
- `ap_done` asserted (result ready to be transmitted)

Assumptions:
- Input data already loaded in memory
- UART transfer overhead excluded

### Hardware measurement method
Latency was measured with ILA using the sample indices of `ap_start` and `ap_done`:
- cycles = `done_index - start_index`

### Results @ 100 MHz
| Operation | Vitis report (ns) | Expected cycles | ILA measurement (start→done) |
|---|---:|---:|---:|
| Euclidean | 420 | 42  | 42 (`554 - 512`) |
| Dot       | 240 | 24  | 24 (`536 - 512`) |

### Throughput (core transaction throughput, excluding UART)
Throughput is computed as:

`Throughput = f_core / cycles_per_transaction`

At `f_core = 100 MHz`:
- Dot throughput: `100e6 / 24 ≈ 4.17 M results/s`
- Euclidean throughput: `100e6 / 42 ≈ 2.38 M results/s`

---

## 9) Resource usage (final)

Final integrated system (post-implementation):
- LUT: **24918**
- FF: **49611**
- DSP: **192**
- BRAM: **0**

Note: if Vivado treats the HLS core as a black box at some stages, top-level post-synth may not
attribute all internal resources. Post-implementation accounts for the integrated netlist.

---

## 10) MATLAB usability + golden reference validation

The system remains usable with a MATLAB workflow similar to Assignment 2:
- generates random vectors
- writes vectors A and B
- runs `eucDist` and `dotProd`
- compares against MATLAB golden reference

Run:
- `Matlab/coprocessorTesting.m`

Helper functions:
- `Matlab/write2dev.m`
- `Matlab/command2dev.m`

The script also demonstrates that results are observable both on the PC (UART return) and on the board display (fixed-point view), satisfying the usability requirement.

---

## 11) Vivado build time (observed)

On the PC(i5-9600K CPU @ 3.70GHz 32Gb ram), the Vivado flow (synthesis → implementation → bitstream):
-synth_design: Time (s): cpu = 00:03:28 ; elapsed = 00:03:45 . Memory (MB): peak = 2416.230 ; gain = 1892.363
<img width="1669" height="613" alt="image" src="https://github.com/user-attachments/assets/3d600f9d-e49d-4bbb-9ff5-7d3e15af430d" />

-Per-step runtimes (implementation + bitstream)

link_design: elapsed 00:00:28 (cpu 00:00:27)
<img width="791" height="86" alt="image" src="https://github.com/user-attachments/assets/da54d858-c9f0-4c63-a4f1-ec9f532584c4" />

opt_design: elapsed 00:00:15 (cpu 00:00:18)
<img width="1164" height="58" alt="image" src="https://github.com/user-attachments/assets/b26b6c5b-ed69-483e-b1b9-246d6384c453" />

place_design: elapsed 00:02:08 (cpu 00:03:02)
<img width="842" height="48" alt="image" src="https://github.com/user-attachments/assets/fc2e2436-5992-4517-904e-a3c91df1f01d" />

phys_opt_design: elapsed 00:00:07 (cpu 00:00:13)
<img width="807" height="48" alt="image" src="https://github.com/user-attachments/assets/0686fc5e-739c-4da0-8326-8cd0f0def3bb" />

route_design: elapsed 00:02:36 (cpu 00:03:46)
<img width="1180" height="78" alt="image" src="https://github.com/user-attachments/assets/d83b1bb6-99b6-45bd-9263-5cc09af3e6c2" />

write_bitstream: elapsed 00:00:32 (cpu 00:00:55)
<img width="828" height="60" alt="image" src="https://github.com/user-attachments/assets/5229d883-c1b7-4f11-bb2b-edd98680364d" />

Using the elapsed times Vivado prints for those commands:
-opt_design 00:00:15
-place_design 00:02:08
-phys_opt_design 00:00:07
-route_design 00:02:36
Sum = 00:05:06 total elapsed.
---

## Contact
Daisy Berríos — dberrios@usm.cl
