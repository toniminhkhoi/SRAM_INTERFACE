# SRAM Interface with RISC-V (PicoRV32) on FPGA

An FPGA-based mini SoC integrating a lightweight **RISC-V core (PicoRV32, RV32I)** with a custom **SRAM controller (BRAM-backed)** and **MMIO peripherals (UART + LEDs)**.  
Demo flow: **PC sends a binary file over UART → firmware writes into SRAM → firmware reads back and sends bytes back to PC**, while LEDs show status.

> Target role: Digital Design / FPGA / RTL Intern (Semiconductor)

---

## Highlights

- **RISC-V (PicoRV32, RV32I)** with `mem_valid / mem_ready` handshake bus
- **Custom SRAM controller** mapped to **FPGA Block RAM (BRAM)**
  - Handles **synchronous BRAM read latency** using a **2-stage pipeline**
  - Supports byte/halfword/word writes via `mem_wstrb` byte-enables
- **MMIO peripherals**
  - **LED register** for debug/status
  - **UART TX/RX** for PC communication (**115200, 8N1**)
  - Uses `mem_ready` for safe flow control (CPU stalls when UART is busy)
- **End-to-end loopback test** (tens of KB) without data loss
- Built with **Xilinx Vivado** (synthesis / implementation / bitstream)

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

### Instruction / Data
- **IMEM (instruction memory)**: `0x0000_0000` (initialized from `.mem`)
- **SRAM (data region)**: `0x0001_0000` (BRAM-backed SRAM window)

### MMIO (example)
| Peripheral | Address | Access | Description |
|---|---:|---|---|
| LED | `0x1000_0000` | Write | 8-bit LED status register |
| UART TX | `0x1000_0004` | Write | write 1 byte to start TX |
| UART RX | `0x1000_0008` | Read | read 1 byte from RX buffer |

### LED status codes (firmware)
- `0x55` : startup
- `0xCC` : receive complete
- `0xAA` : transmit complete

> If your addresses differ, update this table to match your RTL decoder.

---

## Repository Layout (Recommended)

> Adjust paths if your repo uses different names.


SRAM_INTERFACE/
rtl/ # Verilog RTL sources
picorv32_top_refactored.v
picorv32_mmio_bus.v
picorv32_sram.v
uart_rx.v
uart_tx.v
...
firmware/ # RISC-V C firmware (UART -> SRAM -> UART)
main.c
linker.ld
Makefile
scripts/ # Python utilities
make_mem.py # firmware.bin -> imem.mem
uart_loopback.py # send file -> recv file via UART (pyserial)
vivado/ # Vivado project/TCL + constraints (optional)
project.tcl
constraints.xdc
docs/ # report / diagrams (optional)
report.pdf


---

## Requirements

### Hardware
- Xilinx FPGA board with:
  - clock + reset
  - LEDs
  - UART (USB-UART)
- Toolchain:
  - **Vivado** (synthesis/implementation/bitstream)

### Software
- **RISC-V GCC toolchain** (e.g., `riscv32-unknown-elf-gcc`)
- **Python 3** + `pyserial`

Install Python dependency:
```bash
pip install pyserial
Build & Run
1) Build firmware (ELF/BIN)
cd firmware
make

Typical outputs:

firmware.elf

firmware.bin

2) Convert BIN → IMEM .mem
python3 scripts/make_mem.py firmware/firmware.bin rtl/imem.mem

Make sure your IMEM module loads the file:

using $readmemh("imem.mem", ...) (path may vary)

3) Synthesize & program FPGA (Vivado)

Option A: open Vivado project (if you have .xpr)

Open vivado/*.xpr

Check top module (e.g., picorv32_top_refactored)

Ensure constraints .xdc match your board pins (clk/reset/UART/LED)

Run Synthesis → Implementation → Generate Bitstream

Program device

Option B: use a TCL flow (if you keep project.tcl)

# In Vivado TCL console
source vivado/project.tcl
4) UART loopback demo (PC ↔ FPGA)

Find your serial port:

Windows: COMx

Linux: /dev/ttyUSB0 or /dev/ttyACM0

macOS: /dev/tty.usbserial-*

Run:

python3 scripts/uart_loopback.py --port COM5 --baud 115200 --send test.bin --recv out.bin

Verify output:

# Linux/macOS
cmp test.bin out.bin && echo "OK: identical"

# Windows (PowerShell)
fc /b test.bin out.bin

LEDs should show:

0x55 at startup

0xCC after file received & written into SRAM

0xAA after file sent back to PC

How It Works (Short)
PicoRV32 handshake (mem_valid / mem_ready)

CPU asserts mem_valid for loads/stores.

Memory/peripheral asserts mem_ready when done.

If mem_ready=0, PicoRV32 stalls automatically → safe timing + simple peripherals.

SRAM controller (BRAM-backed, 2-stage pipeline)

BRAM read is synchronous (data available next cycle), so the controller pipelines requests:

Stage S1: latch request (addr/wdata/wstrb), hold mem_ready=0

Stage S2: perform BRAM access, drive mem_rdata (for reads), pulse mem_ready=1 for one cycle

This aligns CPU reads with BRAM latency and prevents invalid read data.

UART MMIO flow control

UART TX exposes a busy state.

When TX is busy, the MMIO keeps mem_ready=0 → CPU stalls until TX is ready.

RX provides received bytes through an MMIO read (buffer/flag depending on your implementation).

Testing
Hardware demo

Program FPGA bitstream

Run UART loopback script

Confirm byte-perfect equality: out.bin == test.bin

Optional simulation (recommended)

If you have a testbench:

Verify SRAM read latency + mem_ready alignment

Verify mem_wstrb write behavior

Inspect waveforms (xsim/iverilog + GTKWave)

Notes / Limitations

No cache (all data accesses go through SRAM controller / BRAM)

UART bandwidth limited by baud rate

Flow control is blocking via mem_ready (no interrupts)

Credits

PicoRV32 core by Clifford Wolf (if included in-source or as a dependency)

Project context: HCMUT Logic Design project — “SRAM Interface with RISC-V”
