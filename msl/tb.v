`timescale 1ns / 1ps

module uart_test;

parameter width = 8;
parameter freq  = 50000000;
parameter baudr = 9600;

//global signals	
reg sys_clk;
reg sys_rst;

//	
reg xmit_h;
reg [width-1:0] xmit_data_h;
reg uart_rec_data_h;
wire uart_clk;
wire uart_xmit_data_h;

wire xmit_done_h;

wire [width-1:0] rec_data_h;

wire rec_ready;

wire rec_busy;

wire xmit_active;

uart #(
    .freq(freq),
    .baudr(baudr),
    .width(width)
) DUT (
    .sys_clk(sys_clk),
    .sys_rst(sys_rst),
    .xmit_h(xmit_h),
    .xmit_data_h(xmit_data_h),
    .uart_rec_data_h(uart_rec_data_h),
    .uart_clk(uart_clk),
    .uart_xmit_data_h(uart_xmit_data_h),
    .xmit_done_h(xmit_done_h),
    .rec_data_h(rec_data_h),
    .rec_ready(rec_ready),
    .rec_busy(rec_busy),
    .xmit_active(xmit_active)
);



endmodule
