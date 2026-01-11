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
