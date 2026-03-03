module uart_tx #(
  parameter CLK_FREQ = 125_000_000,
  parameter BAUD     = 115200
)(
  input  wire       clk,
  input  wire       resetn,
  input  wire       tx_start,     // pulse 1 clock cycle
  input  wire [7:0] tx_data,
  output reg        tx,
  output reg        busy
);

  // số chu kỳ clock cho 1 bit UART CLK_FREQ / BAUD
  localparam integer BAUD_CNT_MAX = CLK_FREQ / BAUD;

  reg [15:0] baud_cnt;
  reg [3:0]  bit_idx;      // 0 = start bit, 1..8 = data bits, 9 = stop bit
  reg [9:0]  shift_reg;    // chứa toàn bộ frame UART: start + data + stop

  always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      tx       <= 1'b1;    // idle
      busy     <= 1'b0;
      baud_cnt <= 0;
      bit_idx  <= 0;
    end else begin
      
      if (!busy) begin
        // Khi idle, kiểm tra yêu cầu truyền
        if (tx_start) begin
          // tạo frame UART
          // start bit = 0
          // data bit LSB first
          // stop bit = 1
          shift_reg <= {1'b1, tx_data, 1'b0};
          busy      <= 1'b1;
          bit_idx   <= 0;
          baud_cnt  <= 0;
        end

        tx <= 1'b1; // idle
      end 
      else begin
        // đang truyền
        if (baud_cnt < BAUD_CNT_MAX - 1) begin
          baud_cnt <= baud_cnt + 1;
        end 
        else begin
          baud_cnt <= 0;

          // gửi bit hiện tại
          tx <= shift_reg[bit_idx];

          // chuyển sang bit tiếp theo
          bit_idx <= bit_idx + 1;

          // nếu xong stop bit -> thoát busy
          if (bit_idx == 9) begin
            busy <= 1'b0;
          end
        end
      end
    end
  end

endmodule

