module sync(
input baud_clk, sys_rst_l, uart_REC_dataH,
output reg sync_uart_REC_data_H
);
reg temp1, temp2;
always @(posedge baud_clk or posedge sys_rst_l) begin
        if(sys_rst_l) begin
            sync_uart_REC_data_H <= 0;
            temp1 <=0;
          	temp2 <=0;
        end
        else begin
            temp1 <= uart_REC_dataH;
            temp2 <= temp1;
            sync_uart_REC_data_H <= temp2;
        end
        end    
endmodule

