module picorv32_sram #(
  parameter ADDR_WIDTH = 16,
  parameter DATA_WIDTH = 32
) (
  input  wire                   clk,
  input  wire                   resetn,
  input  wire                   mem_valid,
  input  wire                   mem_instr,
  output wire                   mem_ready,
  output reg [DATA_WIDTH-1:0]   mem_rdata,
  input  wire [31:0]            mem_addr,
  input  wire [DATA_WIDTH-1:0]  mem_wdata,
  input  wire [3:0]             mem_wstrb
);

  localparam DEPTH = (1 << ADDR_WIDTH);
  (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

  initial begin
    $readmemh("mem_init_final_2.mem", mem);
  end

  // Stage registers
  // addr_reg: registered *immediately* when request arrives (we DO NOT delay addr_reg)
  reg [ADDR_WIDTH-1:0] addr_reg;

  // delayed copy of address for use by write stage (addr_reg_d is addr_reg delayed 1 cycle)
  reg [ADDR_WIDTH-1:0] addr_reg_d;

  // data/strobe pipeline: stage1 captures input, stage2 is used for actual write
  reg [DATA_WIDTH-1:0] wdata_s1;
  reg [DATA_WIDTH-1:0] wdata_s2;

  reg [3:0]            wstrb_s1;
  reg [3:0]            wstrb_s2;

  // valid pipeline (valid_s1 captures arrival, valid_s2 used to assert ready/write)
  reg                  valid_s1;
  reg                  valid_s2;

  // write_pending pipeline (indicates this transaction includes write)
  reg                  write_pending_s1;
  reg                  write_pending_s2;

  // ready is asserted when valid_s2 is set (one extra cycle of delay for non-addr signals)
  reg                  ram_ready;

  wire [3:0] write_enable = (valid_s2 && write_pending_s2) ? wstrb_s2 : 4'b0;

  always @(posedge clk) begin
    if (!resetn) begin
      // reset all pipeline registers
      addr_reg       <= {ADDR_WIDTH{1'b0}};
      addr_reg_d     <= {ADDR_WIDTH{1'b0}};
      wdata_s1       <= {DATA_WIDTH{1'b0}};
      wdata_s2       <= {DATA_WIDTH{1'b0}};
      wstrb_s1       <= 4'b0;
      wstrb_s2       <= 4'b0;
      valid_s1       <= 1'b0;
      valid_s2       <= 1'b0;
      write_pending_s1 <= 1'b0;
      write_pending_s2 <= 1'b0;
      ram_ready      <= 1'b0;
      mem_rdata      <= {DATA_WIDTH{1'b0}};
    end else begin
      // --------------- pipeline stage update ----------------
      // addr_reg: register address immediately when a new request arrives (no extra delay)
      if (mem_valid && !valid_s1) begin
        addr_reg <= mem_addr[31:2];   // latch address now
      end
      // propagate address into delayed-address register (for write stage)
      addr_reg_d <= addr_reg;        // addr_reg_d is addr_reg delayed by 1 cycle

      // capture input into stage1 (these are delayed by one cycle before being used)
      if (mem_valid && !valid_s1) begin
        valid_s1        <= 1'b1;
        wdata_s1        <= mem_wdata;
        wstrb_s1        <= mem_wstrb;
        write_pending_s1<= |mem_wstrb;
      end else begin
        // we keep valid_s1 until it is consumed into s2
        // (no automatic clear here; it will be cleared when s2 cleared)
      end

      // shift stage1 -> stage2 (this introduces the requested 1-cycle extra delay for signals)
      valid_s2         <= valid_s1;
      wdata_s2         <= wdata_s1;
      wstrb_s2         <= wstrb_s1;
      write_pending_s2 <= write_pending_s1;

      // --------------- BRAM access ----------------
      // Read: use addr_reg (not delayed) so BRAM output appears next cycle (1-cycle latency)
      mem_rdata <= mem[addr_reg];

      // Write: use delayed address addr_reg_d and delayed write enables/data (stage2)
      if (write_enable[0]) mem[addr_reg][7:0]   <= wdata_s2[7:0];
      if (write_enable[1]) mem[addr_reg][15:8]  <= wdata_s2[15:8];
      if (write_enable[2]) mem[addr_reg][23:16] <= wdata_s2[23:16];
      if (write_enable[3]) mem[addr_reg][31:24] <= wdata_s2[31:24];

      // Optional forwarding:
      // If you want the response to return written data immediately (read-after-write),
      // you must decide which stage to forward from. Here we DO NOT forward from stage1,
      // because that could override BRAM's read result. If you want forwarding, use wdata_s2
      // and address compare with addr_reg (or addr_reg_d) depending on desired semantics.
      // For now we comment it out (safer):
      //
      // if (write_pending_s2 && (addr_reg == addr_reg_d)) begin
      //   mem_rdata <= wdata_s2;
      // end

      // --------------- ready / clearing ----------------
      // mem_ready follows valid_s2 (i.e., after the extra pipeline delay)
      
      ram_ready <= (ram_ready && !mem_valid) ? 0 : valid_s2;

      // clear pipeline when cpu has observed ready and deasserted valid
      if (ram_ready && !mem_valid) begin
        valid_s1 <= 1'b0;
        valid_s2 <= 1'b0;
        write_pending_s1 <= 1'b0;
        write_pending_s2 <= 1'b0;
        wstrb_s1 <= 4'b0;
        wstrb_s2 <= 4'b0;
      end
    end
  end

  assign mem_ready = ram_ready;

endmodule




