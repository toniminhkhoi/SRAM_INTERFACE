`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/05/2026 03:45:44 AM
// Design Name: 
// Module Name: picorv32_mmio_bus
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
// PicoRV32 MMIO + SRAM interconnect
// - Purpose: push address-decode / mux / ready-rdata glue logic out of top-level
// - Functional intent: identical to the original logic in picorv32_top.v
// ============================================================================


module picorv32_mmio_bus #(
    parameter integer SRAM_ADDR_W = 16,
    parameter integer CLK_FREQ    = 125_000_000,
    parameter integer BAUD        = 115200
) (
    input  wire        clk,
    input  wire        resetn,

    // PicoRV32 native memory interface (simple valid/ready)
    input  wire        mem_valid,
    input  wire        mem_instr,
    input  wire [31:0] mem_addr,
    input  wire [31:0] mem_wdata,
    input  wire [3:0]  mem_wstrb,
    output wire        mem_ready,
    output wire [31:0] mem_rdata,

    // External pins
    output wire        uart_tx_pin,
    input  wire        uart_rx_pin,
    output wire [7:0]  leds
);

    // =============================
    // MMIO address map
    // =============================
    // 0x1000_0000 : LED (R/W)
    // 0x1000_0004 : UART TX (W, R=busy)
    // 0x1000_0008 : UART RX (R blocks until data, W=ack/clear)
    wire mmio_led_sel     = (mem_addr[31:4] == 28'h1000000) && (mem_addr[3:0] == 4'h0);
    wire mmio_uart_tx_sel = (mem_addr[31:4] == 28'h1000000) && (mem_addr[3:0] == 4'h4);
    wire mmio_uart_rx_sel = (mem_addr[31:4] == 28'h1000000) && (mem_addr[3:0] == 4'h8);

    // =============================
    // SRAM side
    // =============================
    wire        sram_mem_valid;
    wire        sram_mem_ready;
    wire [31:0] sram_mem_rdata;

    assign sram_mem_valid = mem_valid & ~(mmio_led_sel | mmio_uart_tx_sel | mmio_uart_rx_sel);

  
    picorv32_sram #(
        .ADDR_WIDTH(SRAM_ADDR_W),
        .DATA_WIDTH(32)
    ) u_sram (
        .clk        (clk),
        .resetn     (resetn),
        .mem_valid  (sram_mem_valid),
        .mem_instr  (mem_instr),
        .mem_ready  (sram_mem_ready),
        .mem_rdata  (sram_mem_rdata),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_wstrb  (mem_wstrb)
    );

    // =============================
    // UART TX / RX
    // =============================
    reg        uart_tx_start;
    reg [7:0]  uart_tx_byte;
    wire       uart_busy;

    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD(BAUD)
    ) u_uart_tx (
        .clk      (clk),
        .resetn   (resetn),
        .tx_start (uart_tx_start),
        .tx_data  (uart_tx_byte),
        .tx       (uart_tx_pin),
        .busy     (uart_busy)
    );

    wire [7:0] uart_rx_byte;
    wire       uart_rx_ready;
    reg        uart_rx_ack;

    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD(BAUD)
    ) u_uart_rx (
        .clk      (clk),
        .resetn   (resetn),
        .rx       (uart_rx_pin),
        .rx_data  (uart_rx_byte),
        .rx_ready (uart_rx_ready),
        .rx_ack   (uart_rx_ack)
    );

    // =============================
    // LED register
    // =============================
    reg [7:0] led_reg;
    assign leds = led_reg;

    // =============================
    // Ready / RDATA registers
    // =============================
    reg        mmio_ready_reg;
    reg [31:0] rdata_reg;

    assign mem_rdata = rdata_reg;
    assign mem_ready = sram_mem_ready | mmio_ready_reg;

    // ======================================================
    //  MMIO glue logic (moved from top-level)
    // ======================================================
    always @(posedge clk) begin
        if (!resetn) begin
            mmio_ready_reg <= 1'b0;
            rdata_reg      <= 32'b0;
            uart_tx_start  <= 1'b0;
            uart_tx_byte   <= 8'b0;
            led_reg        <= 8'b0;
            uart_rx_ack    <= 1'b0;
        end else begin
            // defaults each cycle
            mmio_ready_reg <= 1'b0;
            uart_tx_start  <= 1'b0;
            uart_rx_ack    <= 1'b0;

            // ==========================
            //       MMIO ACCESS
            // ==========================
            if (mem_valid && (mmio_led_sel || mmio_uart_tx_sel || mmio_uart_rx_sel)) begin

                // ---------- WRITE ----------
                if (mem_wstrb != 4'b0000) begin

                    // LED WRITE - instant
                    if (mmio_led_sel) begin
                        led_reg        <= mem_wdata[7:0];
                        mmio_ready_reg <= 1'b1;
                    end

                    // UART TX WRITE - wait until not busy
                    if (mmio_uart_tx_sel) begin
                        if (!uart_busy) begin
                            uart_tx_byte   <= mem_wdata[7:0];
                            uart_tx_start  <= 1'b1;
                            mmio_ready_reg <= 1'b1;
                        end else begin
                            mmio_ready_reg <= 1'b0; // stall
                        end
                    end

                    // UART RX WRITE: treat as explicit ACK/clear
                    if (mmio_uart_rx_sel) begin
                        uart_rx_ack    <= 1'b1;
                        mmio_ready_reg <= 1'b1;
                    end

                end else begin
                    // ---------- READ MMIO ----------
                    if (mmio_uart_rx_sel) begin
                        // Read UART RX: only ACK when data available
                        if (uart_rx_ready) begin
                            rdata_reg      <= {24'b0, uart_rx_byte};
                            mmio_ready_reg <= 1'b1;
                            uart_rx_ack    <= 1'b1; // clear after read
                        end else begin
                            mmio_ready_reg <= 1'b0; // stall
                        end
                    end else begin
                        // Other MMIO reads
                        mmio_ready_reg <= 1'b1;
                        if (mmio_led_sel)
                            rdata_reg <= {24'b0, led_reg};
                        else if (mmio_uart_tx_sel)
                            rdata_reg <= {31'b0, uart_busy};
                        else
                            rdata_reg <= 32'b0;
                    end
                end

            end else begin
                // ==========================
                //      NORMAL SRAM READ
                // ==========================
                rdata_reg <= sram_mem_rdata;
            end
        end
    end

endmodule
