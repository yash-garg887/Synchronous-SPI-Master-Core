module spi_master #(
    parameter p_clk_divider = 4 // System clock frequency divided by this value = SPI sclk frequency
)(
    // 1. CPU Interface
    input wire        i_clk ,    //system clock
    input wire        i_rst_n,   //asynchronous active low reset
    input wire  [7:0] i_tx_data, //Parallel byte to be transmitted
    output reg  [7:0] o_rx_data, //data reached from miso terminal
    input wire        i_start,   //Command pulse from CPU to begin transmission
    output reg        o_ready,   //When machine is in IDLE state then it is 1 , when TRANSFER it is 0
    
    // 2. Physical SPI Bus Interface
    output reg        o_mosi,  //Master Out Slave In serial wire
    input wire        i_miso,  //Master In Slave Out serial wire
    output reg        o_sclk,  //output clock
    output reg        o_cs_n   //active low chip select
);

    //2 states of the machine
    localparam IDLE = 1'b0;
    localparam TRANSFER = 1'b1;
    reg r_state;

    reg [7:0] r_tx_reg;		//Static storage for data which has to be transmitted via mosi line
    reg [7:0] r_rx_reg;		//data which is being recieved from miso line
    reg [3:0] r_clk_cnt;	//used to count clock cycles to divide i_clk to make o_sclk
    reg [2:0] r_bit_cnt;	//number of transferred bits through mosi till now
    
    //internal clock edge detectors
    wire w_clk_tick,
         w_rising_edge_tick,
         w_falling_edge_tick;

    //every time input clock completes internal clock's half period threshold , internal clock ticks
    assign w_clk_tick = (r_clk_cnt == (p_clk_divider/2) - 1) ;     	//all edges of o_sclk
    assign w_rising_edge_tick = (w_clk_tick && (o_sclk == 0)) ;  	//rising edges of o_sclk
    assign w_falling_edge_tick = (w_clk_tick && (o_sclk == 1));  	//falling edges of o_sclk

    
    // ========================================================================
    // MAIN FSM & CONTROLLER BLOCK
    // ========================================================================

    always@(posedge i_clk , negedge i_rst_n) begin 
        if(~i_rst_n) begin 
            r_state <= IDLE;
            r_tx_reg <= 8'b0;
            r_rx_reg <= 8'b0;
            o_mosi <= 1'b0;
            o_ready <= 1'b1;
            o_cs_n <= 1'b1;
        end

        else begin 
            case (r_state)
                IDLE : begin
                    o_cs_n <= 1'b1;
                    o_ready <= 1'b1;

                    if(i_start == 1'b1) begin
                        r_state <= TRANSFER;
                        o_cs_n <= 1'b0;
                        o_ready <= 1'b0;
                        r_tx_reg <= i_tx_data; //load the data which is to be transmitted
                        o_mosi <= i_tx_data[7]; //drive msb of data to be transmitted on MOSI line
                    end
                end

                TRANSFER : begin
                    // Terminate transaction on the 8th falling edge cycle
                    if((r_bit_cnt == 3'd7) && w_falling_edge_tick) begin
                        o_cs_n <= 1'b1;
                        o_ready <= 1'b1;
                        r_state <= IDLE;
                        o_rx_data <= r_rx_reg; //offload sampled data to output port
                    end

                    else if(w_falling_edge_tick) begin
                        o_mosi <= r_tx_reg[6-r_bit_cnt]; //transmit at falling edge
                    end
                end

                default : begin
                    r_state <= IDLE;
                end

            endcase
        end
    end

    // ========================================================================
    // HARDWARE CLOCK DIVIDER
    // ========================================================================

    always @(posedge i_clk , negedge i_rst_n) begin
        if(~i_rst_n) begin
            r_clk_cnt <= 4'b0;
            o_sclk <= 1'b0;
        end

        else if(r_state == TRANSFER) begin
            if(w_clk_tick) begin
                r_clk_cnt <= 4'b0;
                o_sclk <= ~o_sclk;
            end

            else begin 
                r_clk_cnt <= r_clk_cnt + 1'b1;
            end
        end

        else begin //IDLE state
            r_clk_cnt <= 4'b0;
            o_sclk <= 1'b0;
        end
    end

    
    //==========================================================
    //TRANSMITTED BIT COUNTER
    //==========================================================
    
    always @(posedge i_clk , negedge i_rst_n ) begin 
        if(~i_rst_n) begin 
            r_bit_cnt <= 3'b0;
        end

        else if (r_state == IDLE) begin
            r_bit_cnt <= 3'b0;
        end

        else if ((r_state == TRANSFER) && w_falling_edge_tick) begin
            r_bit_cnt <= r_bit_cnt + 1'b1;
        end
    end


    // ========================================================
    // RX SHIFT REGISTER (SAMPLE MISO)
    // ========================================================

    always @(posedge i_clk , negedge i_rst_n) begin
        if(~i_rst_n) begin 
            r_rx_reg <= 8'b0;
        end

        else if(w_rising_edge_tick) begin 			//sample at rising edge of internal clock
            r_rx_reg <= {r_rx_reg[6:0],i_miso};		// Shift left and append the incoming MISO data bit into the LSB position
        end
    end

endmodule