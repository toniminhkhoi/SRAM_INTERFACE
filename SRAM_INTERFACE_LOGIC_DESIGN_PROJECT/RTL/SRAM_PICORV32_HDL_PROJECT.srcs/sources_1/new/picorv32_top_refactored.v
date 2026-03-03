`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/05/2026 03:50:03 AM
// Design Name: 
// Module Name: picorv32_top_refactored
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// ============================================================================
// Top-level wrapper (Level 0)
// - Keeps picorv32 core untouched
// - Moves address decode / glue logic into picorv32_mmio_bus (Level 1)
// ============================================================================

module picorv32_top_refactored (
    input  wire clk,
    input  wire resetn_in,
    output wire uart_tx_pin,
    input  wire uart_rx_pin,
    output wire [7:0] leds
);

    localparam integer SRAM_ADDR_W = 16;
    localparam integer CLK_FREQ    = 125_000_000;
    localparam integer BAUD        = 115200;

    // Core <-> bus wires
    wire        mem_valid;
    wire        mem_instr;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    wire        mem_ready;
    wire [31:0] mem_rdata;

    // Optional (unused) core outputs
    wire trap_w;
    wire mem_la_read_w, mem_la_write_w;
    wire [31:0] mem_la_addr_w, mem_la_wdata_w;
    wire [3:0]  mem_la_wstrb_w;
    wire pcpi_valid_w;
    wire [31:0] pcpi_insn_w, pcpi_rs1_w, pcpi_rs2_w, pcpi_rd_w;
    wire [31:0] eoi_w;
    wire trace_valid_w;
    wire [35:0] trace_data_w;

    // PicoRV32 core (Level 1)
 
    picorv32 u_pico (
        .clk           (clk),
        .resetn        (resetn_in),
        .trap          (trap_w),

        .mem_valid     (mem_valid),
        .mem_instr     (mem_instr),
        .mem_ready     (mem_ready),
        .mem_addr      (mem_addr),
        .mem_wdata     (mem_wdata),
        .mem_wstrb     (mem_wstrb),
        .mem_rdata     (mem_rdata),

        .mem_la_read   (mem_la_read_w),
        .mem_la_write  (mem_la_write_w),
        .mem_la_addr   (mem_la_addr_w),
        .mem_la_wdata  (mem_la_wdata_w),
        .mem_la_wstrb  (mem_la_wstrb_w),

        .pcpi_valid    (pcpi_valid_w),
        .pcpi_insn     (pcpi_insn_w),
        .pcpi_rs1      (pcpi_rs1_w),
        .pcpi_rs2      (pcpi_rs2_w),
        .pcpi_wr       (1'b0),
        .pcpi_rd       (pcpi_rd_w),
        .pcpi_wait     (1'b0),
        .pcpi_ready    (1'b0),

        .irq           (32'b0),
        .eoi           (eoi_w),

        .trace_valid   (trace_valid_w),
        .trace_data    (trace_data_w)
    );

    // MMIO + SRAM bus (Level 1)
  
    picorv32_mmio_bus #(
        .SRAM_ADDR_W(SRAM_ADDR_W),
        .CLK_FREQ   (CLK_FREQ),
        .BAUD       (BAUD)
    ) u_bus (
        .clk        (clk),
        .resetn     (resetn_in),

        .mem_valid  (mem_valid),
        .mem_instr  (mem_instr),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_wstrb  (mem_wstrb),
        .mem_ready  (mem_ready),
        .mem_rdata  (mem_rdata),

        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(uart_rx_pin),
        .leds       (leds)
    );

endmodule
