module test;

//TX driver
 task drive_tx(input xmitH_in, input [WORD-1 : 0]xmit_dataH_in,output reg xmitH, output reg [WORD-1 : 0]xmit_dataH);
   begin
	@(negedge baud_clk);
	xmitH <= xmitH_in;
	xmit_dataH <= xmit_dataH_in;
   end
 endtask

//RX driver
 task drive_rx(input uart_REC_dataH_in, output reg uart_REC_dataH);
  begin
	@(negedge baud_clk);
	uart_REC_dataH <= uart_REC_dataH_in;
  end
 endtask



	  
