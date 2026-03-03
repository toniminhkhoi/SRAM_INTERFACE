# SRAM Interface with RISC-V (PicoRV32) on FPGA

A small FPGA-based SoC that integrates a lightweight **RISC-V core (PicoRV32, RV32I)** with a custom **SRAM controller (BRAM-backed)** and **MMIO peripherals (UART + LEDs)**.  
Demo: PC streams a binary file to the FPGA over UART → firmware stores it into SRAM → firmware reads back and sends the same bytes back to PC (byte-perfect loopback).

> Target: Digital Design / FPGA / RTL learning project (Verilog + HW/SW co-design)

---

## Features

- **PicoRV32 (RV32I)** CPU with a simple `mem_valid / mem_ready` handshake interface
- **Custom SRAM controller** mapping a data-memory region into FPGA **Block RAM (BRAM)**
  - Handles BRAM synchronous read latency using a **2-stage pipeline**
  - Supports byte/half-word/word writes via byte enables (`mem_wstrb`)
- **MMIO peripherals**
  - **LED register** (8-bit) for status/debug
  - **UART TX/RX** for PC communication (**115200, 8N1**)
  - Uses `mem_ready` to stall CPU for flow-control (no busy-wait polling needed in firmware)
- **End-to-end loopback test** for tens of KB (e.g., ~96 KB) without data loss

---

## System Overview
        +-------------------+
        |     PicoRV32      |
        |  (RISC-V RV32I)   |
        +---------+---------+
                  | mem_valid/mem_ready
                  v
        +-------------------+
        |   MMIO / Decoder  |
        | picorv32_mmio_bus |
        +----+------+---+---+
             |      |   |
  SRAM (BRAM)|      |   | LED reg
             |      |   |
             v      v   v
    +-----------+ +----+----+
    | SRAM Ctrl  | | UART TX |
    | 2-stage    | +---------+
    | pipeline   | | UART RX |
    +-----------+ +---------+
    
---

## Memory Map

### Data memory
- **Instruction memory**: `0x0000_0000` (IMEM, initialized from `.mem`)
- **SRAM data region**: `0x0001_0000` (BRAM-backed SRAM window)

### MMIO
| Peripheral | Address | Access | Description |
|---|---:|---|---|
| LED | `0x1000_0000` | Write | 8-bit LED status register |
| UART TX | `0x1000_0004` | Write | write 1 byte to start TX |
| UART RX | `0x1000_0008` | Read | read 1 byte from RX buffer |

### LED status codes (firmware)
- `0x55` : startup
- `0xCC` : receive complete
- `0xAA` : transmit complete

---

## Repo Layout (suggested)

> Your actual repo may differ — adjust paths below if needed.
