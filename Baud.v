module Baud #(
    parameter CLC_FREQ = 50000000,
    parameter BAUD = 9600
)(
    input sys_rst_l,
    input sys_clk,
    output reg baud_clk
);

    reg [31:0] count;

    localparam BAUD_FREQ = CLC_FREQ / (16 * BAUD);

    always @(posedge sys_clk or posedge sys_rst_l) begin

        if(sys_rst_l) begin
            baud_clk <= 0;
            count <= 0;
        end

        else begin

            if(count == (BAUD_FREQ/2)-1) begin
                baud_clk <= ~baud_clk;
                count <= 0;
            end

            else begin
                count <= count + 1;
            end

        end

    end

endmodule
