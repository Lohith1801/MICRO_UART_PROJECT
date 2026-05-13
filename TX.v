module TX #(parameter WORD =8)(
    input baud_clk,xmitH,sys_rst_l,
    input [WORD -1 :0]xmit_dataH,
    output reg uart_REC_dataH,xmit_active,xmit_doneH
    );
   
    reg [31:0]count;
    always@(posedge baud_clk)begin 
      if(xmitH == 1) 
            count = 1;
      else if(count > 0)
        	count = count +1;
        else 
            count = 0;    
    end        
    integer i;
    always@(posedge baud_clk or posedge sys_rst_l) begin
        if(sys_rst_l) begin
            count = 0;
            uart_REC_dataH <=0;
        end    
        else begin
            
          if(count < 16) begin
                    uart_REC_dataH <=0;
                    i = WORD-1;
                end
                    
          else if(count >=16 && count < 16*WORD+16) begin
                    if((count %16) == 0)  begin
                          uart_REC_dataH <= xmit_dataH[i];
                          i= i-1;
                    end
                    else  uart_REC_dataH <= uart_REC_dataH;
                    
                end
                
          else if(count >=16*WORD)
                        uart_REC_dataH <= 1;
         end   
      if(count >=1 && count <160) begin
        	xmit_active <=1;
        	xmit_doneH <= 0;
      end
      else if(count >= 160) begin
          	xmit_active <= 0;
        	xmit_doneH <= 1;
      end
      else begin
        xmit_active <=0;
        xmit_doneH <= 0;
      end
          
     end                                                
endmodule
