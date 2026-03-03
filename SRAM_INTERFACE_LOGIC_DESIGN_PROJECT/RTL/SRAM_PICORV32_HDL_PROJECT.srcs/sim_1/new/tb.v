`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/19/2025 06:02:50 PM
// Design Name: 
// Module Name: tb
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


module tb;
reg clk;
reg resetn_in;
wire [7:0] leds;
wire uart_tx_pin;
reg uart_rx_pin;
wire [7:0] rx_data;

assign rx_data = dut.uart_rx_byte;

picorv32_top dut (
    .clk(clk),
    .resetn_in(resetn_in),
    .leds(leds),
    .uart_tx_pin(uart_tx_pin),
    .uart_rx_pin(uart_rx_pin)
);

wire uart_tx_start = dut.uart_tx_start;
wire [7:0] uart_tx_byte = dut.uart_tx_byte;

integer fh;
initial begin
    fh = $fopen("received.raw", "wb");
    if (fh == 0) $fatal("TB: cannot open received.raw");
end

reg uart_tx_start_d;

always @(posedge clk) begin
    uart_tx_start_d <= uart_tx_start;
    if (resetn_in && uart_tx_start && !uart_tx_start_d) begin
        $fwrite(fh, "%c", uart_tx_byte);
    end
end

always @(posedge clk) begin
    if (resetn_in && leds == 8'hAA) begin
        $display("TB: Image transfer done.");
        #1000;
        $fclose(fh);
    end
end

initial begin
    clk = 0;
    forever #10 clk = ~clk;
end

initial begin 
    $display("START SIMU!");
    resetn_in = 0;
    uart_rx_pin = 1;
    #200 resetn_in = 1;
    wait (dut.mmio_uart_rx_sel == 1);
    repeat(3000) @(posedge clk);
    
uart_rx_pin = 0;
repeat(18) @(posedge clk);
uart_rx_pin = 1;

repeat(18) @(posedge clk);
uart_rx_pin = 0;

repeat(18) @(posedge clk);
uart_rx_pin = 1;

repeat(18) @(posedge clk);
uart_rx_pin = 0;

repeat(18) @(posedge clk);
uart_rx_pin = 1;

repeat(18) @(posedge clk);
uart_rx_pin = 1;

repeat(18) @(posedge clk);
uart_rx_pin = 1;

repeat(18) @(posedge clk);
uart_rx_pin = 1;

repeat(18) @(posedge clk);
uart_rx_pin = 1;

repeat(18) @(posedge clk);



//New byte
uart_rx_pin = 0;
repeat(18) @(posedge clk);
uart_rx_pin = 0;

repeat(18) @(posedge clk);
uart_rx_pin = 0;

repeat(18) @(posedge clk);
uart_rx_pin = 1;

repeat(18) @(posedge clk);
uart_rx_pin = 0;

repeat(18) @(posedge clk);
uart_rx_pin = 1;

repeat(18) @(posedge clk);
uart_rx_pin = 1;

repeat(18) @(posedge clk);
uart_rx_pin = 1;

repeat(18) @(posedge clk);
uart_rx_pin = 0;

repeat(18) @(posedge clk);
uart_rx_pin = 1;

repeat(18) @(posedge clk);

    
    #50000000;
    $display("END SIMU!");
    #10
    $finish;
end

always @(posedge clk) begin

    $display("CLK!");
    if(dut.core_mem_valid) begin
        $display("MEM_ACESS time=%0t addr=0x%08x wstrb=%b wdata=0x%08x rdata=0x%08x ready=%b mmio_led_sel=%b mmio_uart_tx_sel=%b",
        $time, dut.core_mem_addr, dut.core_mem_wstrb, dut.core_mem_wdata, dut.core_mem_rdata, dut.core_mem_ready_in, dut.mmio_led_sel, dut.mmio_uart_tx_sel);
    end
end


endmodule
