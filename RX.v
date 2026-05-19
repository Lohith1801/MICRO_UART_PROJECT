`timescale 1ns / 1ps

`include "sync.v"

module RX #(parameter WORD = 8)(
    input uart_REC_dataH,
    input baud_clk,
    input sys_rst_l,

    output wire rec_readyH,
    output wire rec_busy,

    output reg [WORD-1:0] rec_dataH
);

wire sync_uart_REC_data_H;

sync s1(
    .baud_clk(baud_clk),
    .sys_rst_l(sys_rst_l),
    .uart_REC_dataH(uart_REC_dataH),
    .sync_uart_REC_data_H(sync_uart_REC_data_H)
);

reg [4:0] count;
reg [3:0] i;
  reg [WORD-1:0]stored_out;
reg [31:0] cnt;

localparam start_bit = 0,
           stop_bit  = 1,
           data_bit  = 2;

reg [1:0] cur, nxt;



  always @(posedge baud_clk or negedge sys_rst_l) begin

  if(!sys_rst_l) begin

        rec_dataH <= 0;
		stored_out <=0;
        cur <= stop_bit;

        count <= 0;
        cnt <= 0;

        i <= 0;

    end

    else begin

        cur <= nxt;

        cnt <= cnt + 1;

        case(cur)

            stop_bit: begin
				rec_dataH <= stored_out;
                count <= 0;
                i <= 0;

            end



            start_bit: begin

                if(count == 15)
                    count <= 0;
                else
                    count <= count + 1;
              	stored_out <= 0;

            end



            data_bit: begin

                if(count == 15) begin

                    count <= 0;

                    if(i < WORD)
                        i <= i + 1;

                end

                else begin
                    count <= count + 1;
                end



                if(count == 7)
                    stored_out[i] <= sync_uart_REC_data_H;

            end

        endcase

    end

end



always @(*) begin

    nxt = cur;

    case(cur)

        stop_bit: begin
		  	
          nxt = (sync_uart_REC_data_H == 0)&&(rec_readyH == 1) ?
                   start_bit : stop_bit;

        end



        start_bit: begin
          if(sync_uart_REC_data_H == 0) begin
            nxt = (count == 15) ?data_bit : start_bit;
          end
          else begin
            count = 0;
            nxt = stop_bit;
          end

        end



        data_bit: begin

          nxt = ((count == 15) && (i == WORD))&&(sync_uart_REC_data_H == 1) ?
                   stop_bit : data_bit;

        end
        default: nxt = stop_bit;

    endcase

end



assign rec_readyH =
  ((cur == stop_bit) && (i == 0))&&(sys_rst_l ==1);

assign rec_busy =
  ((cur == start_bit) || (cur == data_bit))&&(sys_rst_l ==1);

endmodule
