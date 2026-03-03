//module uart_rx #(
//    parameter CLK_FREQ = 125_000_000,
//    parameter BAUD     = 115200
//)(
//    input  wire       clk,
//    input  wire       resetn,
//    input  wire       rx,        // UART RX line từ ngoài vào
//    output reg [7:0]  rx_data,   // byte nhận được
//    output reg        rx_ready,  // =1 khi có data hợp lệ, giữ đến khi rx_ack
//    input  wire       rx_ack     // xung 1 clk khi CPU đã đọc xong
//);

//    // số chu kỳ clock cho 1 bit UART
//    localparam integer BAUD_CNT_MAX = CLK_FREQ / BAUD;
//    localparam integer HALF_BAUD    = BAUD_CNT_MAX / 2;

//    reg [15:0] baud_cnt;
//    reg [3:0]  bit_idx;      // 0..7: data bits
//    reg [7:0]  shift_reg;
//    reg        receiving;    // đang nhận 1 frame

//    always @(posedge clk or negedge resetn) begin
//        if (!resetn) begin
//            baud_cnt  <= 16'd0;
//            bit_idx   <= 4'd0;
//            shift_reg <= 8'd0;
//            receiving <= 1'b0;
//            rx_data   <= 8'd0;
//            rx_ready  <= 1'b0;
//        end else begin
//            // clear cờ khi CPU báo đã đọc xong
//            if (rx_ack)
//                rx_ready <= 1'b0;

//            if (!receiving) begin
//                // idle: chờ start bit (rx từ 1 -> 0)
//                // không nhận frame mới nếu còn data pending
//                if (!rx && !rx_ready) begin
//                    receiving <= 1'b1;
//                    baud_cnt  <= HALF_BAUD;  // chờ nửa bit rồi sample giữa start bit
//                    bit_idx   <= 4'd0;
//                end
//            end else begin
//                // đang nhận frame
//                if (baud_cnt != 16'd0) begin
//                    baud_cnt <= baud_cnt - 16'd1;
//                end else begin
//                    // tới thời điểm sample 1 bit
//                    baud_cnt <= BAUD_CNT_MAX - 1;

//                    if (bit_idx < 4'd8) begin
//                        // sample data bit (LSB first)
//                        shift_reg[bit_idx] <= rx;
//                        bit_idx <= bit_idx + 4'd1;
//                    end else begin
//                        // bit tiếp theo là stop bit (có thể check rx==1 nếu muốn)
//                        receiving <= 1'b0;
//                        rx_data   <= shift_reg;
//                        rx_ready  <= 1'b1;   // thông báo có byte mới
//                    end
//                end
//            end
//        end
//    end

//endmodule


//module uart_rx #(
//    parameter CLK_FREQ = 125_000_000,
//    parameter BAUD     = 115200
//)(
//    input  wire       clk,
//    input  wire       resetn,
//    input  wire       rx,        // UART RX line từ ngoài vào

//    output wire [7:0] rx_data,   // byte đầu tiên trong buffer
//    output wire       rx_ready,  // =1 khi có ít nhất 1 byte trong buffer, delayed 1 clk
//    input  wire       rx_ack     // CPU báo đã đọc xong 1 byte
//);

//    // -------------------------
//    // UART sampling
//    // -------------------------
//    //CLK_FREQ / BAUD
//    localparam integer BAUD_CNT_MAX = CLK_FREQ / BAUD;
//    localparam integer HALF_BAUD    = (BAUD_CNT_MAX + BAUD_CNT_MAX - 2) / 2;

//    reg [15:0] baud_cnt;
//    reg [3:0]  bit_idx;
//    reg [7:0]  shift_reg;
//    reg        receiving;

//    // -------------------------
//    // Double buffer (2 bytes)
//    // -------------------------
//    reg [7:0] buf0, buf1;
//    reg       buf0_valid, buf1_valid;

//    // rx_ready delayed 1 clock
//    reg rx_ready_r;
//    assign rx_ready = rx_ready_r;
//    assign rx_data  = buf0;

//    // =========================
//    // MAIN LOGIC
//    // =========================
//    always @(posedge clk or negedge resetn) begin
//        if (!resetn) begin
//            baud_cnt   <= 0;
//            bit_idx    <= 0;
//            shift_reg  <= 0;
//            receiving  <= 0;

//            buf0       <= 0;
//            buf1       <= 0;
//            buf0_valid <= 0;
//            buf1_valid <= 0;

//            rx_ready_r <= 0;

//        end else begin
            
//            // ============================
//            // CPU đã đọc xong 1 byte → dịch buffer
//            // ============================
//            if (rx_ack && buf0_valid) begin
//                if (buf1_valid) begin
//                    buf0       <= buf1;
//                    buf1_valid <= 1'b0;
//                end else begin
//                    buf0_valid <= 1'b0;
//                end
//            end

//            // ============================
//            // UART RECEIVING STATE MACHINE
//            // ============================
//            if (!receiving) begin
//                // chờ start bit (rx từ 1 → 0)
//                if (!rx && !receiving) begin
//                    receiving <= 1'b1;
//                    baud_cnt  <= HALF_BAUD;
//                    bit_idx   <= 0;
//                end

//            end else begin
//                // đang nhận frame
//                if (baud_cnt != 0) begin
//                    baud_cnt <= baud_cnt - 16'd1;

//                end else begin
//                    // sample 1 bit
//                    baud_cnt <= BAUD_CNT_MAX - 1;

//                    if (bit_idx < 8) begin
//                        shift_reg[bit_idx] <= rx;
//                        bit_idx <= bit_idx + 1;

//                    end else begin
//                        // stop bit
//                        receiving <= 1'b0;

//                        // ===========================
//                        // GHI VÀO DOUBLE BUFFER
//                        // ===========================
//                        if (!buf0_valid) begin
//                            buf0       <= shift_reg;
//                            buf0_valid <= 1'b1;

//                        end else if (!buf1_valid) begin
//                            buf1       <= shift_reg;
//                            buf1_valid <= 1'b1;

//                        end else begin
//                            // buffer đầy 2 byte → overflow
//                            // Bạn có thể đặt cờ nếu muốn
//                            // hoặc ghi đè buf1
//                        end
//                    end
//                end
//            end

//            // ============================
//            // Delay 1 cycle cho rx_ready
//            // ============================
//            rx_ready_r <= buf0_valid;

//        end
//    end
//endmodule

module uart_rx #(
    parameter integer CLK_FREQ = 125_000_000,
    parameter integer BAUD     = 115200
)(
    input  wire        clk,
    input  wire        resetn,
    input  wire        rx,        // UART RX line từ ngoài vào

    output wire [7:0]  rx_data,   // byte đầu tiên trong buffer
    output wire        rx_ready,  // =1 khi có ít nhất 1 byte trong buffer, delayed 1 clk
    input  wire        rx_ack     // CPU báo đã đọc xong 1 byte
);

    // số clock cho 1 bit gần đúng (làm tròn xuống)
    localparam integer BAUD_CNT = CLK_FREQ / BAUD;

    // Số clock để chờ 1.5 bit, lưu ý trừ 1 vì ta dùng countdown (see comment)
    // ta làm (BAUD_CNT + BAUD_CNT/2) rồi -1 để chờ đúng N clocks trước khi sample
    localparam integer FIRST_CNT = BAUD_CNT + (BAUD_CNT >> 1) - 1; // = 1.5*BAUD_CNT - 1
    localparam integer PERIOD_CNT = BAUD_CNT - 1;                  // sau mỗi sample load PERIOD_CNT (đếm tới 0)

    // regs
    reg [15:0] baud_cnt;
    reg [3:0]  bit_idx;
    reg [7:0]  shift_reg;
    reg        receiving;

    // double buffer
    reg [7:0] buf0, buf1;
    reg       buf0_valid, buf1_valid;

    // rx sync and edge detect
    reg rx_sync0, rx_sync1;
    wire start_edge;

    // rx_ready delayed 1 clk
    reg rx_ready_r;
    assign rx_ready = rx_ready_r;
    assign rx_data  = buf0;

    // Edge detect on synchronized signal: previous high -> now low
    assign start_edge = (rx_sync1 == 1'b1) && (rx_sync0 == 1'b0);

    // =========================
    // MAIN LOGIC
    // =========================
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            rx_sync0    <= 1'b1;
            rx_sync1    <= 1'b1;
            baud_cnt    <= 0;
            bit_idx     <= 0;
            shift_reg   <= 0;
            receiving   <= 1'b0;

            buf0        <= 0;
            buf1        <= 0;
            buf0_valid  <= 1'b0;
            buf1_valid  <= 1'b0;

            rx_ready_r  <= 1'b0;
        end else begin
            // synchronize rx
            rx_sync0 <= rx;
            rx_sync1 <= rx_sync0;

            // CPU đã đọc xong 1 byte → dịch buffer
            if (rx_ack && buf0_valid) begin
                if (buf1_valid) begin
                    buf0       <= buf1;
                    buf1_valid <= 1'b0;
                    buf0_valid <= 1'b1;
                end else begin
                    buf0_valid <= 1'b0;
                end
            end

            // UART receiving state machine
            if (!receiving) begin
                // chờ start bit: detect falling edge trên synchronized line
                if (start_edge) begin
                    receiving <= 1'b1;
                    baud_cnt  <= FIRST_CNT;  // chờ 1.5 bit (FIRST_CNT + 1 clocks until sample)
                    bit_idx   <= 0;
                end
            end else begin
                if (baud_cnt != 0) begin
                    baud_cnt <= baud_cnt - 16'd1;
                end else begin
                    // sample time
                    // sau khi sample, set counter cho next bit: BAUD_CNT - 1 (đếm tới 0)
                    baud_cnt <= PERIOD_CNT;

                    if (bit_idx < 8) begin
                        shift_reg[bit_idx] <= rx_sync0; // sample synchronized rx
                        bit_idx <= bit_idx + 1;
                    end else begin
                        // stop bit sampled (we are at stop)
                        receiving <= 1'b0;

                        // GHI VÀO DOUBLE BUFFER
                        if (!buf0_valid) begin
                            buf0       <= shift_reg;
                            buf0_valid <= 1'b1;
                        end else if (!buf1_valid) begin
                            buf1       <= shift_reg;
                            buf1_valid <= 1'b1;
                        end else begin
                            // overflow -> bỏ qua hoặc ghi đè tùy nhu cầu
                        end
                    end
                end
            end

            // Delay 1 cycle cho rx_ready
            rx_ready_r <= buf0_valid;
        end
    end
endmodule

