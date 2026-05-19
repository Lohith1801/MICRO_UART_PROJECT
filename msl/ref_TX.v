module ref_TX(input xmitH,nput sys_ input [WORD-1:0]xmit_dataH, output reg xmit_doneH, uart_XMIT_dataH);
  integer i;
  initial begin
        uart_XMIT_dataH  = 0;
        repeat(16) begin
                @(posedge baud_clk);
        end
        for(i=0;i<WORD; i= i+1) begin
                uart_XMIT_dataH = xmit_dataH[i];
                repeat(16) begin
                        @(posedge baud_clk);
                end
        end
        uart_XMIT_dataH  = 1;
        repeat(16) begin
                @(posedge baud_clk);
        end
  end
endmodule
