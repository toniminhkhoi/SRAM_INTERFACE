`timescale 1ns/1ps
module tb_picorv32_top;

  // Clock & reset
  reg clk;
  reg resetn;

  // Top module outputs
  wire uart_tx_pin;
  wire [7:0] leds;

  // --- Clock generation ---
  initial clk = 0;
  always #5 clk = ~clk; // 100 MHz clock (10 ns period)

  // --- Reset ---
  initial begin
    resetn = 0;
    #50;          // hold reset 50 ns
    resetn = 1;
  end

  // --- Instantiate top module ---
  picorv32_top dut (
    .clk(clk),
    .resetn_in(resetn),
    .uart_tx_pin(uart_tx_pin),
    .leds(leds)
  );

  // --- Monitor simulation ---
  initial begin
    $dumpfile("tb_picorv32_top.vcd");
    $dumpvars(0, tb_picorv32_top);

    // Run simulation for some time
    #1000000; // adjust as needed
    $display("Simulation finished");
    $finish;
  end

  // Optional: monitor LEDs and UART
  always @(posedge clk) begin
    if (!resetn) begin
      // nothing
    end else begin
      if (leds != 8'b0) begin
        $display("Time %t: LED output = %h", $time, leds);
      end
      // uart_tx_pin could be monitored if needed
    end
  end

endmodule
