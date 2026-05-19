`timescale 1ns / 1ps

module TX #(parameter WORD = 8)(
    input baud_clk,
    input xmitH,
    input sys_rst_l,

    input  [WORD-1:0] xmit_dataH,

    output reg uart_REC_dataH,
    output reg xmit_active,
    output reg xmit_doneH
);

    reg [WORD-1:0] data;

    reg [4:0] count;
    reg [3:0] i;

    localparam start_bit = 0, data_bit  = 2, stop_bit  = 1, idle      = 3;
    reg [1:0] cur, nxt;



	always @(posedge baud_clk or negedge sys_rst_l) begin

        if(!sys_rst_l) begin
            cur   <= idle;
            count <= 0;
            i     <= 0;
            data  <= 0;
        end

        else begin
            cur <= nxt;
            case(cur)

                idle: begin
                    count <= 0;
                    i <= 0;
                    if(xmitH)
                        data <= xmit_dataH;

                end

                start_bit: begin
                    if(count == 15)
                        count <= 0;
                    else
                        count <= count + 1;
                end

                data_bit: begin
                    if(count == 15) begin
                        count <= 0;
                        if(i == WORD-1)
                            i <= 0;
                        else
                            i <= i + 1;
                    end
                    else begin
                        count <= count + 1;
                    end
                end
              
                stop_bit: begin
			        if(count == 15)
                        count <= 0;
                    else
                        count <= count + 1;
                end
              
            endcase

        end

    end



    always @(*) begin

        nxt = cur;

        uart_REC_dataH = 1'b1;

        xmit_active = 1'b0;
        xmit_doneH  = 1'b0;

        case(cur)

            idle: begin
                uart_REC_dataH = 1'b1;
                if(xmitH)
                    nxt = start_bit;
                else
                    nxt = idle;
            end

            start_bit: begin
                uart_REC_dataH = 1'b0;
                xmit_active = 1'b1;
                nxt = (count == 15) ? data_bit : start_bit;
            end

            data_bit: begin
                uart_REC_dataH = data[i];
                xmit_active = 1'b1;
                nxt = ((count == 15) && (i == WORD-1)) ?
                       stop_bit : data_bit;

            end

            stop_bit: begin
                uart_REC_dataH = 1'b1;
                xmit_active = 1'b1;
                if(count == 15) begin
                    nxt = idle;
                    xmit_doneH = 1'b1;
                end
                else begin
                    nxt = stop_bit;
                end
            end

        endcase

    end

endmodule
