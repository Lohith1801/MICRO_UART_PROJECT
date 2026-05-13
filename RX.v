`include"Sync.v"
module RX #(parameter WORD = 8)(
    input uart_REC_dataH,
    input baud_clk,
    input sys_rst_l,
    output wire rec_readyH, rec_busy,
    output reg [WORD -1 :0]rec_dataH
);
wire sync_uart_REC_data_H;
  reg [31:0] i;
sync s1(.baud_clk(baud_clk), .sys_rst_l(sys_rst_l), .uart_REC_dataH(uart_REC_dataH),.sync_uart_REC_data_H(sync_uart_REC_data_H));
    reg [31:0]count,cnt;
    localparam start_bit =0, stop_bit=1, data_bit =2;
    reg [1:0]cur,nxt;
           
    always @(posedge baud_clk or posedge sys_rst_l) begin
        if(sys_rst_l) begin
            rec_dataH <= 0;
            cur <= stop_bit;
            count <= 0;
            cnt <=0;
            i =0;
        end
        else begin
            cur <= nxt;
            count <= count +1 ;
          cnt <= cnt + 1;
        end  
    end
    
    always @(*) begin
        case(cur)
            stop_bit : begin 
              nxt = (sync_uart_REC_data_H) ? stop_bit : start_bit;
              count =0;
              cnt = (i==0)? 0: cnt;
                       end
            start_bit : begin
              nxt = (count >=17) ? data_bit : start_bit;
                            count = (nxt== data_bit) ? 0: count; 
                            i =0;
                        end
            data_bit : begin
                            if(count == 6) begin
                                rec_dataH = {rec_dataH[WORD-2:0],sync_uart_REC_data_H};
                                i = i+1;
                            end
                            else if(count >=16) begin
                                count =0;
                            end
                            
                            nxt = (i==WORD)&&(sync_uart_REC_data_H == 1) ?  stop_bit :data_bit;
                        end
          endcase
     end
  assign rec_readyH = (sync_uart_REC_data_H == 1)&&(i==WORD);
  assign rec_busy = (nxt == start_bit) || (nxt == data_bit);                                        
      
endmodule

