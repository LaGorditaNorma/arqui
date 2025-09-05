`timescale 1ns/1ps
`include "io_interface.v"
`include "uart_rx_module.v"
`include "uart_tx_module.v"
module tb_io_interface;
    // Clock: 50 MHz -> 20 ns period
    reg clk = 0;
    always #10 clk = ~clk;

    reg rst_n = 0;
    reg [7:0] switches = 8'h00;
    wire [7:0] leds;
    reg        uart_rx = 1'b1; // UART idle is high
    wire       uart_tx;

    // Instancia del DUT
    io_interface dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .switches (switches),
        .leds     (leds),
        .uart_rx  (uart_rx),
        .uart_tx  (uart_tx)
    );

    // VCD dump
    initial begin
        $dumpfile("io_interface.vcd");
        $dumpvars(0, tb_io_interface);
    end

    // Estímulos
    initial begin
        // Reset
        rst_n = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;

        // Cambiar switches (deberían reflejarse en los LEDs)
        switches = 8'b1010_1100;
        repeat (10) @(posedge clk);
        switches = 8'b0101_0011;
        repeat (10) @(posedge clk);

        // Simular recepción UART de un byte (ejemplo: 0x55)
        uart_rx_byte(8'h55);

        repeat (20) @(posedge clk);

        $finish;
    end

    // Tarea para simular la recepción UART
    task uart_rx_byte(input [7:0] data);
        integer i;
        begin
            // Start bit
            uart_rx = 1'b0;
            repeat (16) @(posedge clk); // CLKS_PER_BIT = 16

            // Data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = data[i];
                repeat (16) @(posedge clk);
            end

            // Stop bit
            uart_rx = 1'b1;
            repeat (16) @(posedge clk);
        end
    endtask

endmodule
