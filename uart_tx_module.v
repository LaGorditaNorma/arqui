
`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// UART Transmitter 8-N-1
// Transmits LSB first. Parameterizable CLKS_PER_BIT = Fclk / Baud.
// Example for sim: with clk=50MHz and baud=115200 -> ~434; but for faster
// simulation you can pick a small value (default 16).
// -----------------------------------------------------------------------------
module uart_tx_module
#(
    parameter integer CLKS_PER_BIT = 16  // clocks per bit
)
(
    input  wire clk,
    input  wire rst_n,       // active-low async reset (tie high if unused)
    input  wire start,       // pulse '1' at least 1 clk to start sending "data"
    input  wire [7:0] data,  // byte to send
    output reg  tx,          // serial line (idles at '1')
    output reg  busy         // 1 while transmitting
);

    // FSM states
    localparam [2:0]
        S_IDLE  = 3'd0,
        S_START = 3'd1,
        S_DATA  = 3'd2,
        S_STOP  = 3'd3;

    reg [2:0]  state = S_IDLE;
    reg [3:0]  bit_idx;                  // 0..7
    reg [7:0]  shifter;
    reg [15:0] clk_cnt;                  // supports CLKS_PER_BIT up to 65535

    // TX idles high
    initial begin
        tx   = 1'b1;
        busy = 1'b0;
    end

    wire tick = (clk_cnt == CLKS_PER_BIT-1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= S_IDLE;
            tx      <= 1'b1;
            busy    <= 1'b0;
            bit_idx <= 4'd0;
            clk_cnt <= 16'd0;
            shifter <= 8'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    tx   <= 1'b1;
                    busy <= 1'b0;
                    clk_cnt <= 0;
                    if (start) begin
                        busy    <= 1'b1;
                        shifter <= data;
                        bit_idx <= 0;
                        state   <= S_START;
                        tx      <= 1'b0;        // start bit
                    end
                end

                S_START: begin
                    // hold start bit for one bit time
                    if (tick) begin
                        clk_cnt <= 0;
                        state   <= S_DATA;
                        tx      <= shifter[0];  // first data bit (LSB)
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                S_DATA: begin
                    if (tick) begin
                        clk_cnt <= 0;
                        bit_idx <= bit_idx + 1;
                        shifter <= {1'b0, shifter[7:1]}; // shift right
                        if (bit_idx == 4'd7) begin
                            state <= S_STOP;
                            tx    <= 1'b1;      // stop bit
                        end else begin
                            tx    <= shifter[1]; // next bit after shift
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                S_STOP: begin
                    if (tick) begin
                        clk_cnt <= 0;
                        state   <= S_IDLE;
                        busy    <= 1'b0;
                        tx      <= 1'b1;        // line back to idle
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
