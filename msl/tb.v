`timescale 1ns / 1ps

module uart_test;

parameter width = 8;
parameter freq  = 50000000;
parameter baudr = 9600;

//global signals	
reg sys_clk;
reg sys_rst;

// ports	
reg xmit_h;
reg [width-1:0] xmit_data_h;
reg uart_rec_data_h;
reg uart_clk;
wire uart_xmit_data_h;
wire xmit_done_h;
wire [width-1:0] rec_data_h;
wire rec_ready;
wire rec_busy;
wire xmit_active;

//monitor outputs
reg [width-1:0]tx_monitored_data;
reg [width-1:0]rx_monitored_data;


//expected data
reg [width-1:0] tx_expected_data;
reg [width-1:0] rx_expected_data;
reg [width-1:0] data_out;
//pass and fail count
integer pass_count, fail_count;

// sys_clk generation
initial begin
    sys_clk = 0;
    forever #10 sys_clk = ~sys_clk;
end

//DUT
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
    .uart_xmit_data_h(uart_xmit_data_h),
    .xmit_done_h(xmit_done_h),
    .rec_data_h(rec_data_h),
    .rec_ready(rec_ready),
    .rec_busy(rec_busy),
    .xmit_active(xmit_active)
);


localparam endcount = (freq/(baudr*16*2));
reg [$clog2(endcount):0] count;


//uart_clk generation logic
initial begin
    uart_clk = 0;
    count = 0;
end
always @(posedge sys_clk or negedge sys_rst) begin

    if(!sys_rst) begin

        uart_clk <= 0;

        count <= 0;

    end

    else if(count == endcount-1) begin

        uart_clk <= ~uart_clk;

        count <= 0;
    end
    else begin
        count <= count + 1;
    end
end

// DUT RESET TASK
task reset_dut;
begin
    sys_rst = 0;
    repeat(5)
    @(posedge uart_clk);
    sys_rst = 1;
end

endtask 

// RX driver
task rx_driver(input [7:0] data, input start_bit_delay, stop_bit_delay);
integer i;
begin
    @(posedge uart_clk);
    uart_rec_data_h = 0;
    repeat(start_bit_delay)
    @(posedge uart_clk);
    for(i = 0; i < 8; i = i + 1) begin
        uart_rec_data_h = data[i];
        repeat(16)
        @(posedge uart_clk);
    end
    uart_rec_data_h = 1;
    repeat(stop_bit_delay)
    @(posedge uart_clk);
end
endtask     

//xmitH asserting based on Uartclk numbers
task xmitH_assert(input num_clk);
begin
    xmit_h = 1;
    repeat(num_clk) begin
        @(posedge uart_clk);
    end
    xmit_h = 0;
end  
endtask  
 
 // TX driver
task tx_driver(input [7:0] data);
begin
    @(posedge uart_clk);
    xmit_data_h = data;
    wait(xmit_done_h);
    @(posedge uart_clk);
end
endtask

//Monitor TX
task tx_monitor;
integer i;
begin
    wait(uart_xmit_data_h == 0);
    repeat(16) begin
        @(posedge uart_clk);
    end
    for(i=0;i<width;i=i+1) begin
            repeat(8) begin
                @(posedge uart_clk);
            end
            tx_monitored_data[i] = uart_xmit_data_h;
            repeat(8) begin
                @(posedge uart_clk);
            end
     end
end  
endtask

// monitor RX
task rx_monitor;
integer i;
begin
    wait(rec_ready == 1);
    rx_monitored_data = rec_data_h;
end  
endtask

// Scoreboard tasks TX
task tx_scr(input ID);
begin
    if(tx_monitored_data === tx_expected_data) begin
        pass_count = pass_count +1;
        $display("PASS = > ID - %d",ID);
    end
    
    else begin
        fail_count = fail_count +1;
        $display("PASS = > ID - %d",ID);
    end
end    
endtask

// Scoreboard tasks RX
task rx_scr(input ID);
begin
    if(rx_monitored_data === rx_expected_data) begin
        pass_count = pass_count +1;
        $display("PASS = > ID - %d",ID);
    end
    
    else begin
        fail_count = fail_count +1;
        $display("PASS = > ID - %d",ID);
    end
end    
endtask          
           
task xmitH_assertion_for_data_Transmission(input ID);
begin
    tx_expected_data = $urandom_range(0,255);
    fork
        xmitH_assert(1);
        tx_driver(tx_expected_data); 
        tx_monitor();
        tx_scr(ID);       
    join  
end        
endtask

task xmitH_assertion_between_TX_busy(input ID);
begin
    tx_expected_data = $urandom_range(0,255);
    fork
        xmitH_assert(1);
        tx_driver(tx_expected_data);
        #50 xmitH_assert(1);   
        tx_monitor();
        tx_scr(ID);       
    join    
end      
endtask

task xmit_dataH_assertion_in_between_the_transmission_process(input ID);
begin
    tx_expected_data = $urandom_range(0,255);
    fork
        xmitH_assert(1);
        tx_driver(tx_expected_data);
        #50 tx_driver($urandom_range(0,255));   
        tx_monitor();
        tx_scr(ID);       
    join     
end     
endtask

task No_assertion_xmitH(input ID);
begin
    tx_expected_data = tx_monitored_data;
    fork
        tx_driver(tx_expected_data); 
        tx_monitor();
        tx_scr(ID);       
    join     
end     
endtask

task longer_assertion_xmitH_for_2Datas(input ID);
begin
    xmitH_assert(2*(32+width*16));
    
    begin //fisrt pac
        tx_expected_data = $urandom_range(0,255);
        fork
            xmitH_assert(1);
            tx_driver(tx_expected_data); 
            tx_monitor();
            tx_scr(ID);       
        join  
    end
    
    begin //seconf pac
        tx_expected_data = $urandom_range(0,255);
        fork
            xmitH_assert(1);
            tx_driver(tx_expected_data); 
            tx_monitor();
            tx_scr(ID);       
        join  
    end
end        
endtask

task valid_start_bit_detection(input ID);
begin
    rx_expected_data = $urandom_range(0,255);
    fork
        rx_driver(tx_expected_data,16,16); 
        rx_monitor();
        rx_scr(ID);       
    join  
end        
endtask

task false_start_bit_detection(input ID);
begin
    rx_expected_data = $urandom_range(0,255);
    fork
        rx_driver(tx_expected_data,10,16); 
        rx_monitor();
        rx_scr(ID);       
    join  
end        
endtask

task valid_stop_bit_detection(input ID);
begin
    rx_expected_data = $urandom_range(0,255);
    fork
        rx_driver(tx_expected_data,16,16); 
        rx_monitor();
        rx_scr(ID);       
    join  
end        
endtask

task all_zero_data_reception(input ID);
begin
    rx_expected_data = {width{1'b0}};
    fork
        rx_driver(tx_expected_data,16,16); 
        rx_monitor();
        rx_scr(ID);       
    join  
end        
endtask

task all_one_data_reception(input ID);
begin
    rx_expected_data = {width{1'b1}};
    fork
        rx_driver(tx_expected_data,16,16); 
        rx_monitor();
        rx_scr(ID);       
    join  
end        
endtask

task sending_two_pacs_continouosly(input ID);
begin
begin// first pac
    rx_expected_data = $urandom_range(0,255);
    fork
        rx_driver(tx_expected_data,16,16); 
        rx_monitor();
        rx_scr(ID);       
    join  
end   
begin//second pax
    rx_expected_data = $urandom_range(0,255);
    fork
        rx_driver(tx_expected_data,16,16); 
        rx_monitor();
        rx_scr(ID);       
    join  
end   
end     
endtask

task end_bit_not_recieved(input ID);
begin
    rx_expected_data = {width{1'b1}};
    fork
        rx_driver(tx_expected_data,16,0); 
        rx_monitor();
        rx_scr(ID);       
    join  
end        
endtask

initial begin
    repeat(100) begin
        // reseting dut
        reset_dut();
        
        // TX test cases
        xmitH_assertion_for_data_Transmission(7);
        xmitH_assertion_between_TX_busy(8);
        xmit_dataH_assertion_in_between_the_transmission_process(9);
        No_assertion_xmitH(10);
        longer_assertion_xmitH_for_2Datas(11);
        
        // RX test cases
        valid_start_bit_detection(12);
        false_start_bit_detection(13);
        valid_stop_bit_detection(14);
        all_zero_data_reception(15);
        all_one_data_reception(16);
        sending_two_pacs_continouosly(20);
        end_bit_not_recieved(21); 
    end
	$finish;
 end       
endmodule
