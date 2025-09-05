`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// UART Receiver 8-N-1
// Recibe LSB primero. Parameterizable CLKS_PER_BIT = Fclk / Baud.
// Ejemplo: clk=50MHz, baud=115200 → ~434
// -----------------------------------------------------------------------------
module uart_rx_module
#(
    parameter integer CLKS_PER_BIT = 16  // clocks per bit
)
(
    input  wire clk,
    input  wire rst_n,       // reset asincrónico activo en bajo
    input  wire rx,          // línea serial de entrada
    output reg  [7:0] data,  // byte recibido
    output reg  ready        // pulso 1 clk cuando se recibió un byte
);

    // FSM states
    localparam [2:0]
        S_IDLE   = 3'd0,
        S_START  = 3'd1,
        S_DATA   = 3'd2,
        S_STOP   = 3'd3;

    reg [2:0]  state = S_IDLE;
    reg [3:0]  bit_idx;       // 0..7
    reg [7:0]  data_buf;
    reg [15:0] clk_cnt;       // cuenta hasta CLKS_PER_BIT
    reg        rx_sync0, rx_sync1;  // sincronizar rx con clk

    // Sincronizar rx a clk (para evitar metastabilidad)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync0 <= 1'b1;
            rx_sync1 <= 1'b1;
        end else begin
            rx_sync0 <= rx;
            rx_sync1 <= rx_sync0;
        end
    end

    wire rx_clean = rx_sync1;

    // RX FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            clk_cnt  <= 0;
            bit_idx  <= 0;
            data_buf <= 0;
            data     <= 0;
            ready    <= 0;
        end else begin
            ready <= 0;  // default (solo se pone 1 un ciclo)
            case (state)
                // Esperando start bit
                S_IDLE: begin
                    if (rx_clean == 1'b0) begin  // detecta transición a 0
                        state   <= S_START;
                        clk_cnt <= 0;
                    end
                end

                // Mitad del start bit (para centrar muestreo)
                S_START: begin
                    if (clk_cnt == (CLKS_PER_BIT/2)) begin
                        if (rx_clean == 1'b0) begin
                            clk_cnt <= 0;
                            bit_idx <= 0;
                            state   <= S_DATA;
                        end else begin
                            state <= S_IDLE; // falso start
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                // Recepción de los 8 bits
                S_DATA: begin
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        clk_cnt <= 0;
                        data_buf[bit_idx] <= rx_clean;
                        if (bit_idx == 7) begin
                            state <= S_STOP;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                // Stop bit
                S_STOP: begin
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        state   <= S_IDLE;
                        clk_cnt <= 0;
                        data    <= data_buf;
                        ready   <= 1;   // indicar byte válido
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
