module uart_test;

parameter width = 8;
parameter freq  = 50000000;
parameter baudr = 9600;

//UART_CLK description
localparam integer ENDCOUNT           = freq / (baudr * 16 * 2); 
localparam integer UART_CC    = ENDCOUNT * 2;         
localparam integer BIT_PERIOD     = UART_CC * 16; 
localparam integer HALF_BIT_PERIOD    = BIT_PERIOD / 2;  

//global signals
reg sys_clk;
reg sys_rst;

// ports
reg xmit_h;
reg [width-1:0] xmit_data_h;
reg uart_rec_data_h;

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


//pass and fail count
integer pass_count, fail_count;
real pass_percentage;  

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

// DUT RESET TASK
task reset_dut;
begin
    sys_rst = 0;
    xmit_h = 0;
    xmit_data_h = 0;
    uart_rec_data_h = 1; 
    repeat(15)
    @(posedge sys_clk);
    sys_rst = 1;
end
endtask

// RX driver 
task rx_driver(input [7:0] data, input integer start_bit_ticks, input integer stop_bit_ticks);
integer i;
begin
  //add 0
    @(posedge sys_clk);
    uart_rec_data_h = 0;
  //add data
    repeat(start_bit_ticks * UART_CC) 
      @(posedge sys_clk);
    for(i = 0; i < 8; i = i + 1) begin
        uart_rec_data_h = data[i];
        repeat(16 * UART_CC) @(posedge sys_clk); 
    end
  //add 1
    uart_rec_data_h = 1;
    repeat(stop_bit_ticks * UART_CC) @(posedge sys_clk);
end
endtask

// xmitH asserting task based on UART_CC numbers
task xmitH_assert(input [21:0] num_ticks);
begin
    @(posedge sys_clk);
    xmit_h = 1;
    repeat(num_ticks * UART_CC) begin
        @(posedge sys_clk);
    end
    xmit_h = 0;
end
endtask

// TX driver
  task tx_driver(input [width-1:0] data, input integer drive_time);
begin
    @(posedge sys_clk);
    xmit_data_h = data;
  repeat(drive_time*BIT_PERIOD)
    @(posedge sys_clk);
end
endtask

//  Monitor TX 
task tx_monitor;
integer i;
begin
    //wait for 0
    wait(uart_xmit_data_h == 0);
    
    // sampling data @ 8th UART cycle
    repeat(BIT_PERIOD + HALF_BIT_PERIOD) @(posedge sys_clk);
    for(i = 0; i < width; i = i + 1) begin
        tx_monitored_data[i] = uart_xmit_data_h;
        repeat(BIT_PERIOD) @(posedge sys_clk); 
    end
end
endtask

// Monitor RX
task rx_monitor;
begin
    wait(rec_ready == 1);
    #(HALF_BIT_PERIOD);
    rx_monitored_data = rec_data_h;
end
endtask

// Scoreboard  TX
task tx_scr(input reg [6:0]ID);
begin
    if(tx_monitored_data === tx_expected_data) begin
        pass_count = pass_count + 1;
        $display("PASS => TX Test ID - %0d | Matched Data: %h", ID, tx_monitored_data);
    end else begin
        fail_count = fail_count + 1;
        $display("FAIL => TX Test ID - %0d | Expected: %h, Sampled: %h", ID, tx_expected_data, tx_monitored_data);
    end
end
endtask

// Scoreboard  RX
task rx_scr(input reg [6:0]ID);
  
begin
  
    if(rx_monitored_data === rx_expected_data) begin
        pass_count = pass_count + 1;
        $display("PASS => RX Test ID - %0d | Matched Data: %h", ID, rx_monitored_data);
    end else begin
        fail_count = fail_count + 1;
        $display("FAIL => RX Test ID - %0d | Expected: %h, Sampled: %h", ID, rx_expected_data, rx_monitored_data);
    end
end
endtask


// TEST CASES

task xmitH_assertion_for_data_Transmission(input reg [6:0]ID);
begin
    tx_expected_data = $urandom_range(0,255);
    fork
        begin
            fork
                xmitH_assert(2); 
              tx_driver(tx_expected_data,12);
            join
            wait(!xmit_active); 
        end
        tx_monitor();
    join
    tx_scr(ID);
end
endtask
  
  task rst_during_Tx_operation(input reg [6:0]ID);
begin
  tx_expected_data = {width{1'b0}};
    fork
        begin
            fork
                xmitH_assert(2); 
              tx_driver($urandom_range(0,255),12);
              #(4*BIT_PERIOD) reset_dut();
            join
            wait(!xmit_active); 
        end
        tx_monitor();
    join
    tx_scr(ID);
end
endtask

task xmitH_assertion_between_TX_busy(input reg [6:0]ID);
begin
    tx_expected_data = $urandom_range(0,255);
    fork
        begin
            fork
                xmitH_assert(1);
              tx_driver(tx_expected_data,12);
            join
            wait(!xmit_active);
        end
        begin
            #(UART_CC * 4) xmitH_assert(1);
        end
        tx_monitor();
    join
    tx_scr(ID);
end
endtask

task xmit_dataH_assertion_in_between_the_transmission_process(input reg [6:0]ID);
begin
  tx_expected_data = $urandom_range(0,255);
    fork
        begin
            fork
                xmitH_assert(1);
              tx_driver(tx_expected_data,2);
            join
            wait(!xmit_active);
        end
        begin
          #(BIT_PERIOD * 2) tx_driver($urandom_range(0,255),12);
        end
        tx_monitor();
    join
    tx_scr(ID);
end
endtask

task No_assertion_xmitH(input reg [6:0]ID);
begin
    tx_expected_data = tx_monitored_data;
    fork
        
      tx_driver($urandom_range(0,255),12);
            //wait(!xmit_active);
        
        //tx_monitor();
    join
    tx_scr(ID);
end
endtask

task longer_assertion_xmitH_for_2Datas(input reg [6:0]ID);
begin
    fork
        xmitH_assert(2 * (32 + width * 16));
        begin
            begin // First pac
                tx_expected_data = $urandom_range(0,255);
                fork
                    begin
                        fork
                            xmitH_assert(1);
                          tx_driver(tx_expected_data,12);
                        join
                        wait(!xmit_active);
                    end
                    tx_monitor();
                join
                tx_scr(ID);
            end

            begin // Second pac
                tx_expected_data = $urandom_range(0,255);
                fork
                    begin
                        fork
                            xmitH_assert(1);
                          tx_driver(tx_expected_data,12);
                        join
                        wait(!xmit_active);
                    end
                    tx_monitor();
                join
                tx_scr(ID);
            end
        end
    join
end
endtask

task valid_start_bit_detection(input reg [6:0]ID);
begin
    rx_expected_data = $urandom_range(0,255);
    rx_driver(rx_expected_data,16,16); 
   	rx_monitor();
    rx_scr(ID);
end
endtask

  task rst_during_Rx_operation(input reg [6:0]ID);
fork
begin
  rx_expected_data = {width{1'b0}};
  rx_driver($urandom_range(0,255),16,16); 
   	rx_monitor();
    rx_scr(ID);
end
  #(BIT_PERIOD*4) reset_dut();
join
endtask
  
task false_start_bit_detection(input reg [6:0]ID);
begin
    rx_expected_data = $urandom_range(0,255);
    
        rx_driver(rx_expected_data,10,16); 
        rx_monitor();
    
    rx_scr(ID);
end
endtask

task valid_stop_bit_detection(input reg [6:0]ID);
begin
    rx_expected_data = $urandom_range(0,255);
    
        rx_driver(rx_expected_data,16,16);
        rx_monitor();
    
    rx_scr(ID);
end
endtask

task all_zero_data_reception(input reg [6:0]ID);
begin
    rx_expected_data = {width{1'b0}};
    
        rx_driver(rx_expected_data,16,16);
        rx_monitor();
    
    rx_scr(ID);
end
endtask

task all_one_data_reception(input reg [6:0]ID);
begin
    rx_expected_data = {width{1'b1}};
    
        rx_driver(rx_expected_data,16,16);
        rx_monitor();
    
    rx_scr(ID);
end
endtask

task sending_two_pacs_continouosly(input reg [6:0]ID);
begin
    begin // Pac 1
        rx_expected_data = $urandom_range(0,255);
        
            rx_driver(rx_expected_data,16,16);
            rx_monitor();
        
        rx_scr(ID);
    end
    begin // Pac 2
        rx_expected_data = $urandom_range(0,255);
        
            rx_driver(rx_expected_data,16,16);
            rx_monitor();
        
        rx_scr(ID);
    end
end
endtask

task end_bit_not_recieved(input reg [6:0]ID);
begin
    rx_expected_data = {width{1'b1}};
    
        rx_driver(rx_expected_data,16,0); 
        rx_monitor();
    
    rx_scr(ID);
end
endtask
  

// Main Initial Block
initial begin
    pass_count = 0;
    fail_count = 0;
    
  repeat(1) begin // noisy input test case
    reset_dut();
    @(posedge sys_clk);
    rx_expected_data = 8'b00000000;
    uart_rec_data_h = 0;// start bit
    #(BIT_PERIOD);
    uart_rec_data_h = 0;//data_bit
    #(BIT_PERIOD - 2*UART_CC);
    uart_rec_data_h = 0;
    #(BIT_PERIOD);
    uart_rec_data_h = 0;
    #(BIT_PERIOD);
    uart_rec_data_h = 0;
    #(BIT_PERIOD);
    uart_rec_data_h = 0;
    #(BIT_PERIOD);
    uart_rec_data_h = 0;
    #(BIT_PERIOD);
    uart_rec_data_h = 0;
    #(BIT_PERIOD);
    uart_rec_data_h = 0;
    #(BIT_PERIOD);
    uart_rec_data_h = 1;
    #(BIT_PERIOD);
    
    rx_monitor();
    rx_scr(19);
  end
    
  repeat(1) begin
        reset_dut();

        //  Tx testcases
    rst_during_Tx_operation(3);
        xmitH_assertion_for_data_Transmission(7);
        xmitH_assertion_between_TX_busy(8);
         xmit_dataH_assertion_in_between_the_transmission_process(9);
         No_assertion_xmitH(10);
         longer_assertion_xmitH_for_2Datas(11);

        //Rx testcases
    rst_during_Rx_operation(4);
         valid_start_bit_detection(12);
         false_start_bit_detection(13);
         valid_stop_bit_detection(14);
      all_zero_data_reception(15);
        all_one_data_reception(16);
         sending_two_pacs_continouosly(20);
         end_bit_not_recieved(21);
    end
  
  pass_percentage = (pass_count*100) / (pass_count + fail_count);
    
    $display("\n=================================================");
    $display("               SIMULATION REPORT                 ");
    $display("=================================================");
  $display(" Total testcases:  %0d", fail_count+ pass_count);
    $display(" Total Pass: %0d", pass_count);
    $display(" Total Fail:  %0d", fail_count);
  
  $display(" PASS percentage:  %0.2f ", pass_percentage);
    $display("=================================================\n");
    $finish;
end

initial begin
    $dumpfile("uart_wave.vcd");
    $dumpvars(0, uart_test);
end

endmodule
