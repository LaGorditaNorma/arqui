

`timescale 1ns/1ps


// -----------------------------------------------------------------------------
// I/O interface: maps switches->leds and exposes UART RX/TX
// -----------------------------------------------------------------------------
module io_interface
#(
    parameter integer CLKS_PER_BIT = 434   // para clk=50MHz y baud=115200
)
(
    input  wire        clk,        // reloj de 50 MHz
    input  wire        rst_n,      // reset activo en bajo
    input  wire [7:0]  switches,   // 8 switches
    output reg  [7:0]  leds,       // 8 LEDs
    input  wire        uart_rx,    // UART RX desde PC
    output wire        uart_tx     // UART TX hacia PC
);

    // ------------------------
    // Señales UART RX/TX
    // ------------------------
    wire [7:0] rx_data;
    wire       rx_ready;
    reg  [7:0] tx_data;
    reg        tx_start;
    wire       tx_busy;

    // ------------------------
    // Lógica LEDs: actualiza solo cuando llega dato nuevo por UART
    // ------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            leds <= 8'b00000000;
        end else if (rx_ready) begin
            leds <= switches | rx_data;
        end else begin
            leds <= switches;
        end
    end

    // ------------------------
    // Enviar switches por UART (pulso único de tx_start)
    // ------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_start <= 1'b0;
            tx_data  <= 8'h00;
        end else if (!tx_busy && !tx_start) begin
            tx_data  <= switches;
            tx_start <= 1'b1; // pulso de inicio
        end else begin
            tx_start <= 1'b0; // baja después de un ciclo
        end
    end

    // ------------------------
    // Instancia del UART RX
    // ------------------------
    uart_rx_module #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) U_RX (
        .clk(clk),
        .rst_n(rst_n),
        .rx(uart_rx),
        .data(rx_data),
        .ready(rx_ready)
    );

    // ------------------------
    // Instancia del UART TX
    // ------------------------
    uart_tx_module #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) U_TX (
        .clk(clk),
        .rst_n(rst_n),
        .start(tx_start),
        .data(tx_data),
        .tx(uart_tx),
        .busy(tx_busy)
    );

endmodule