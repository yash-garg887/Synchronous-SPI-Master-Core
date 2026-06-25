`timescale 1ns/1ps

module tb_spi_master();

    //test bench signals
    reg clk;
    reg rst_n;
    reg start;
    reg miso;
    reg [7:0] tx_data;
    wire [7:0] rx_data;
    wire cs_n;
    wire ready;
    wire mosi;
    wire sclk;

    reg[7:0] r_slave_tx_buffer; //Local register for simulating response of external slave upon transmission

    integer    error_cnt;        // Tracks total simulation failures
    reg [7:0]  expected_rx_data; // Holds expected value for comparison

    spi_master uut (.i_clk(clk) ,
                    .i_rst_n(rst_n),
                    .i_tx_data(tx_data),
                    .o_rx_data(rx_data),
                    .i_start(start), 
                    .o_ready(ready) ,
                    .o_mosi(mosi),  
                    .i_miso(miso),  
                    .o_sclk(sclk),  
                    .o_cs_n(cs_n)
                );
    
    
    //generate a 50 MHz clock
    always begin
        #10 clk = ~clk;
    end

    initial begin
        miso = 0;
        r_slave_tx_buffer = 8'h3C; 	//just a arbitrary default value
		expected_rx_data = r_slave_tx_buffer;
    end

    always @(cs_n) begin
        if(~cs_n) begin 
            miso = r_slave_tx_buffer[7];
        end

        else begin 
            miso = 1'b0;
            r_slave_tx_buffer = 8'h3C;
        end
    end

    // Pushing slave_tx_buffer at negedge of sclk because rx reg samples miso at posedge sclk , 
    // so it settles effectively before sampling
    always @(negedge sclk) begin 
        if(~cs_n) begin
            r_slave_tx_buffer = {r_slave_tx_buffer[6:0],1'b0};		//left shifting by 1 bit
            miso = r_slave_tx_buffer[7];
        end
    end

    initial begin 
        clk = 0;
        rst_n = 0; //press active loe reset
        start = 0;
        tx_data = 8'h00;
        error_cnt = 0;            // Start with zero errors
        
        #100;
        rst_n = 1; //release reset pin
        #40;//let the system settle 

        if(ready) begin
            $display("[SIM INFO] Starting Automated Verification Engine...");
        end

        //Transaction 1: sending 8'hA5 to slave
        @(negedge clk); //Drive inputs on falling edge
        tx_data = 8'hA5;
        start = 1;

        @(negedge clk);
        start = 0; //turn the pulse off

        @(posedge ready); #5; //small delay to let settle evrything
        
        // AUTOMATED CHECKER 1
        if (rx_data === expected_rx_data) begin
            $display("[PASSED] Test 1: Master successfully received 8'h%H from Slave.", rx_data);
        end 
	
	else begin
            $display("[FAILED] Test 1: Data mismatch! Expected: 8'h%H, Actual: 8'h%H", expected_rx_data, rx_data);
            error_cnt = error_cnt + 1;
        end
        
        // --- Transaction 2: Send 8'hF0 (11110000) ---
        #100; // Separation gap between back-to-back transfers
        
        @(negedge clk); 
        tx_data = 8'hF0;
        start = 1;

        @(negedge clk);
        start = 0; 							//turn the pulse off

        @(posedge ready); #5;  	 //small delay to let settle evrything

        // AUTOMATED CHECKER 2
        if (rx_data === expected_rx_data) begin
            $display("[PASSED] Test 2: Master successfully received 8'h%H from Slave.", rx_data);
        end else begin
            $display("[FAILED] Test 2: Data mismatch! Expected: 8'h%H, Actual: 8'h%H", expected_rx_data, rx_data);
            error_cnt = error_cnt + 1;
        end
        
        // ====================================================================
        // FINAL SCOREBOARD REPORT
        // ====================================================================
        
	#50;
        $display("\n==================================================");
        $display("             FINAL VERIFICATION REPORT            ");
        $display("==================================================");
        if (error_cnt == 0) begin
            $display("STATUS: SUCCESS");
            $display("SUMMARY: All transactions matched flawlessly.");
        end else begin
            $display("STATUS: FAILED");
            $display("SUMMARY: Detected %d data corruption errors during execution.", error_cnt);
        end
        
        $display("==================================================\n");

        $finish;
    end

endmodule