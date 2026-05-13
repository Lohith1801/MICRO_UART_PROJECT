`timescale 1ns / 1ps

`include "Baud.v"
`include "TX.v"
`include "RX.v"
`include "Sync.v"

module UART_LOOPBACK #(
    parameter WORD = 8,
    parameter CLK_FREQ = 50000000,
    parameter BAUD = 9600
)(
    input sys_clk,
    input sys_rst_l,
    input xmitH,
    input [WORD-1:0] xmit_dataH,

    output rec_readyH,
  	output uart_REC_dataH,
    output rec_busy,
    output [WORD-1:0] rec_dataH,

    
    output xmit_active,
    output xmit_doneH
);

    wire baud_clk,uart_REC_dataH;

    Baud #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD(BAUD)
    ) B1 (
        .sys_rst_l(sys_rst_l),
        .sys_clk(sys_clk),
        .baud_clk(baud_clk)
    );

    TX #(
        .WORD(WORD)
    ) T1 (
        .baud_clk(baud_clk),
        .sys_rst_l(sys_rst_l),
        .xmitH(xmitH),
        .xmit_dataH(xmit_dataH),

        .uart_REC_dataH(uart_REC_dataH),
        .xmit_active(xmit_active),
        .xmit_doneH(xmit_doneH)
    );

    RX #(
        .WORD(WORD)
    ) R1 (
        .rec_dataH(rec_dataH),
        .baud_clk(baud_clk),
        .sys_rst_l(sys_rst_l),

        .rec_readyH(rec_readyH),
        .rec_busy(rec_busy),
        .rec_dataH(rec_dataH)
    );

endmodule
