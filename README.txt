# Synthesizable SPI Master Core & Self-Checking Verification Environment

 ** This repository contains a production-grade, fully synthesizable SPI Master (Mode 0) controller implemented in Verilog RTL
 ** This also contains an test bench which is fully autonomous

##Hardware Architecture & Design Choices : 
 ** Single-Clock Domain Design:  Every internal register (`r_state`, `r_tx_reg`, `r_rx_reg`, `r_clk_cnt`, `r_bit_cnt`) is clocked by the global system clock `i_clk`
 ** Clock-Enable Strobe Generation: The hardware SPI clock (`o_sclk`) is treated strictly as an output wire for external slave devices. Internal transitions are managed using clock-enable ticks (`w_clk_tick`, `w_rising_edge_tick`, `w_falling_edge_tick`) to entirely eliminate clock skew and gated-clock hazards.

##module paramters:
    * p_clk_divider (default = 4): System clock division factor (freq_sclk = freq_clk / p_clk_divider)
												 Must be an even integer >= 2 

##module ports:
   * i_clk : (input , 1 bit) Fast system clock
   * i_rst_n : (input , 1 bit) Asynchronous active low reset
   * i_tx_data :(input , 8 bits) parallel byte which is to be transmitted by master
   * o_rx_data: (output ,8 bits) parallel byte recieved back from slave
   * i_start: (input , 1 bit) strobe command from cpu to begin transaction
   * o_ready : (output , 1 bit) signal when syatem is in IDLE state
   * o_cs_n :(output ,1bit) active low chip select
   * o_mosi : (output, 1 bit) Master Out Slave In serial data line
   * i_miso : (input, 1 bit) Master In Slave Out serial data line
   * o_sclk : (output, 1 bit) Serial Clock output pin


## Verification Strategy
    The framework includes a high-fidelity, autonomous testbench (`tb_spi_master.v`) that completely removes the need for manual waveform analysis.

## Simulation & Execution Logs
	When executed in an IEEE-compliant simulator (such as AMD Vivado XSim, ModelSim, or Icarus Verilog), the environment sweeps through multi-byte transactions (`8'hA5` and `8'hF0`) and outputs the following autonomous validation report to the console

[SIM INFO] Starting Automated Verification Engine...
[PASSED] Test 1: Master successfully received 8'h3C from Slave.
[PASSED] Test 2: Master successfully received 8'h3C from Slave.

==================================================
             FINAL VERIFICATION REPORT            
==================================================
STATUS: SUCCESS
SUMMARY: All transactions matched flawlessly.
==================================================