
`timescale 1ns / 1ps

module sd_controller_sd(
    output reg cs, // Connect to SD_DAT[3].
    output mosi, // Connect to SD_CMD.
    input miso, // Connect to SD_DAT[0].
    output sclk, // Connect to SD_SCK.
                // For SPI mode, SD_DAT[2] and SD_DAT[1] should be held HIGH. 
                // SD_RESET should be held LOW.
	 input [31:0]i_blk_num, 
    input rd,   // Read-enable. When [ready] is HIGH, asseting [rd] will 
              // begin a 512-byte READ operation at [address]. 
                // [byte_available] will transition HIGH as a new byte has been
                // read from the SD card. The byte is presented on [dout].
    output reg [7:0]dout, // Data output for READ operation.
    output reg byte_available, // A new byte has been presented on [dout].
	 output reg [8:0]byte_counter,

    input wr,   // Write-enable. When [ready] is HIGH, asserting [wr] will
                // begin a 512-byte WRITE operation at [address].
                // [ready_for_next_byte] will transition HIGH to request that
                // the next byte to be written should be presentaed on [din].
    input [7:0] din, // Data input for WRITE operation.
    output reg ready_for_next_byte, // A new byte should be presented on [din].

    input reset, // Resets controller on assertion.
    output ready, // HIGH if the SD card is ready for a read or write operation.
    input [31:0] address,   // Memory address for read/write operation. This MUST 
                            // be a multiple of 512 bytes, due to SD sectoring.
    input clk,  // 25 MHz clock.
    output [4:0] status, // For debug purposes: Current state of controller.
	 output reg [7:0] recv_data, // debug
	 output reg reading,
	 output reg read_done,
	 input multi_sector_en,
	 output reg sdcard_present
);

    parameter RST = 5'd0;
    parameter INIT = 5'd1;
    parameter CMD0 = 5'd2;
	 parameter CMD1 = 5'd21;
    parameter CMD8 = 5'd3;
    parameter CMD55 = 5'd4;
    parameter CMD41 = 5'd5;
    parameter POLL_CMD = 5'd6;
	 parameter CMD12 = 5'd21;
    
    parameter IDLE = 5'd7;
    parameter READ_BLOCK = 5'd8;
    parameter READ_BLOCK_WAIT = 5'd9;
    parameter READ_BLOCK_DATA = 5'd10;
    parameter READ_BLOCK_CRC = 5'd11;
    parameter SEND_CMD = 5'd12;
    parameter RECEIVE_BYTE_WAIT = 5'd13;
    parameter RECEIVE_BYTE = 5'd14;
    parameter WRITE_BLOCK_CMD = 5'd15;
    parameter WRITE_BLOCK_INIT = 5'd16;
    parameter WRITE_BLOCK_DATA = 5'd17;
    parameter WRITE_BLOCK_BYTE = 5'd18;
    parameter WRITE_BLOCK_WAIT = 5'd19;
	 parameter DEBUG = 5'd20;
    
    parameter WRITE_DATA_SIZE = 9'd511;//515;
    
    reg [4:0] state = RST;
    assign status = state;
    reg [4:0] return_state;
    reg sclk_sig;
    reg [55:0] cmd_out;
    //reg [7:0] recv_data;
    reg cmd_mode = 1;
    reg [7:0] data_sig = 8'hFF;
    
    //reg [9:0] byte_counter;
    reg [9:0] bit_counter;
    
    reg [26:0] boot_counter = 27'd10_000_000;
	 reg [31:0]block_counter;
	
	reg [31:0]i_adr;
	//reg [15:0]sec_index;
	//reg rd_enable;
	 
	 //////clock divider to generate clk_25mhz /////////
//	 reg [1:0]clk_count = 2'b00;
//	 wire clk_25;
//	 ////////////////////////
//	 //cmd 17 = {51,Address,FF}  Single block read
//	// cmd18 = {52,Address,FF}   Multiple block read
//	// cmd12 = {4c,00000000,FF}  stop read/wrie transmission
//	 always@(posedge clk)
//	 begin
//     clk_count <= clk_count + 1;
//	 end
//	assign clk_25 = clk_count[1]; 
	//////////////////////////////////////////// 
   
	always @(posedge clk) 
	 begin
        if(reset == 1) 
		  begin
            state <= RST;
            sclk_sig <= 1'b0;
            boot_counter <= 27'd10_000_000; //100_000_000
				sdcard_present <= 1'b0;
        end
        else 
		  begin
            case(state)
                RST: begin
                    if(boot_counter == 0) 
						  begin
                        sclk_sig <= 0;
                        cmd_out <= {56{1'b1}};
                        byte_counter <= 0;
                        byte_available <= 0;
								block_counter <= 0;
                        ready_for_next_byte <= 0;
                        cmd_mode <= 1;
                        bit_counter <= 160;
                        cs <= 1;
                        state <= INIT;
								read_done <= 1'b0;
								reading <= 1'b0;
								//i_adr <= 32'd152704+2048; // 640x480 = 32'd39488,41344; 800x600 = 152704
								//rd_enable <= 0;
                    end
                    else 
						  begin
                        boot_counter <= boot_counter - 1'b1;
                    end
                end
                INIT: begin
                    if(bit_counter == 0) begin
                        cs <= 0;
                        state <= CMD0;
                    end
                    else begin
                        bit_counter <= bit_counter - 1'b1;
                        sclk_sig <= ~sclk_sig;
                    end
                end
                CMD0: begin 
                    cmd_out <= 56'hFF_40_00_00_00_00_95;
                    bit_counter <= 55;
                    return_state <= CMD8;
                    state <= SEND_CMD;
                end
//					 CMD1: begin
//						  cmd_out <= 56'hFF_41_00_00_00_00_F9;
//						  bit_counter <= 55;
//						  return_state <= POLL_CMD;
//						  state <= SEND_CMD;
//					 end
                CMD8: begin
                    cmd_out <= 56'hFF_48_00_00_01_AA_87;
                    bit_counter <= 55;
                    return_state <= CMD55;
                    state <= SEND_CMD;
                end
                CMD55: begin
                    cmd_out <= 56'hFF_77_00_00_00_00_65;
                    bit_counter <= 55;
                    return_state <= CMD41;
                    state <= SEND_CMD;
                end
                CMD41: begin
                    cmd_out <= 56'hFF_69_40_00_00_00_01;
                    bit_counter <= 55;
                    return_state <= POLL_CMD;
                    state <= SEND_CMD;
                end
                POLL_CMD: begin
                    if(recv_data[0] == 0) 
						  begin
                        state <= IDLE;
								
                    end
                    else begin
                        state <= CMD55;
								//state <= CMD55;
                    end
                end
                IDLE: begin
								sdcard_present <= 1'b1;
                    if(rd == 1) // 
						  begin
                        state <= READ_BLOCK;
								read_done <= 1'b0;
								//sec_index <= 0;
                    end
                    else if(wr == 1) begin
                        state <= WRITE_BLOCK_CMD;
                    end
                    else begin
                        state <= IDLE;
                    end
                end
					// address calculation
					// 1. open Sdcard in winhex via physical volume
					// 2. start sector address has 2048
					// 3. open partition -> locate the filename(TEST.264) which shows the sector addres (here 8512)
					// 4. now sector block address = 2048 + 8512 = 10560
                READ_BLOCK: begin
					 
					 block_counter <= multi_sector_en ? i_blk_num:0; //(file_reading==0) ? 0: 
                cmd_out <= (multi_sector_en==0) ? {16'hFF_51,address,8'hFF} : {16'hFF_52,address,8'hFF};
                  //  cmd_out <= {16'hFF_51,address,8'hFF}; //  single sector read
                    bit_counter <= 55;
                    return_state <= READ_BLOCK_WAIT;
                    state <= SEND_CMD;
                end
                READ_BLOCK_WAIT: begin
                    if(sclk_sig == 1 && miso == 0) begin
                        byte_counter <= 0; // byte_counter <= 511
                        bit_counter <= 7;
								reading <= 1'b0;
							   return_state <= READ_BLOCK_DATA;
                        state <= RECEIVE_BYTE;
                    end
                    sclk_sig <= ~sclk_sig;
                end
                READ_BLOCK_DATA: begin
                    dout <= recv_data;
                    byte_available <= 1;
                    if (byte_counter == 511) begin  //byte_counter == 0
                        bit_counter <= 7;
								reading <= 1'b0;
                        return_state <= READ_BLOCK_CRC;
                        state <= RECEIVE_BYTE;
                    end
                    else begin
                        byte_counter <= byte_counter + 1'b1;  //byte_counter <= byte_counter + 1;
                        return_state <= READ_BLOCK_DATA;
								read_done <= 1'b0;
								reading <= 1'b1;
                        bit_counter <= 7;
                        state <= RECEIVE_BYTE;
                    end
                end
                READ_BLOCK_CRC: begin
                    bit_counter <= 7;
						  block_counter <= multi_sector_en ? block_counter - 1:0;
                    return_state <=  (block_counter == 0) ? CMD12 : READ_BLOCK_WAIT; //(block_counter == 0) ? IDLE :
                   // return_state <= IDLE;
						  read_done <= 1'b1;
						  reading <= 0;
                    state <= RECEIVE_BYTE;
								
                end
					 CMD12: begin
                    cmd_out <= 56'hFF_4C_00_00_00_00_FF;
                    bit_counter <= 55;
                    return_state <= IDLE;
                    state <= SEND_CMD;
						  read_done <= 1;
                end
                SEND_CMD: begin
                    if (sclk_sig == 1) begin
                        if (bit_counter == 0) begin
                            state <= RECEIVE_BYTE_WAIT;
                        end
                        else begin
                            bit_counter <= bit_counter - 1'b1;
                            cmd_out <= {cmd_out[54:0], 1'b1};
                        end
                    end
                    sclk_sig <= ~sclk_sig;
                end
                RECEIVE_BYTE_WAIT: begin
                    if (sclk_sig == 1) begin
                        if (miso == 0) begin
                            recv_data <= 0;
                            bit_counter <= 6;
                            state <= RECEIVE_BYTE;
                        end
                    end
                    sclk_sig <= ~sclk_sig;
                end
                RECEIVE_BYTE: begin
                    byte_available <= 0;
						  
                    if (sclk_sig == 1) begin
                        recv_data <= {recv_data[6:0], miso};
                        if (bit_counter == 0) begin
                            state <= return_state;
                        end
                        else begin
                            bit_counter <= bit_counter - 1'b1;
                        end
                    end
                    sclk_sig <= ~sclk_sig;
                end
					 DEBUG: begin
						
					 end
					 WRITE_BLOCK_CMD: begin
                    cmd_out <= {16'hFF_58, address, 8'hFF};
                    bit_counter <= 55;
                    return_state <= WRITE_BLOCK_INIT;
                    state <= SEND_CMD;
		            ready_for_next_byte <= 1;
                end
                WRITE_BLOCK_INIT: begin
                    cmd_mode <= 0;
                    byte_counter <= WRITE_DATA_SIZE; 
                    state <= WRITE_BLOCK_DATA;
                    ready_for_next_byte <= 0;
                end
                WRITE_BLOCK_DATA: begin
                    if (byte_counter == 0) begin
                        state <= RECEIVE_BYTE_WAIT;
                        return_state <= WRITE_BLOCK_WAIT;
                    end
                    else begin
                        if ((byte_counter == 2) || (byte_counter == 1)) begin
                            data_sig <= 8'hFF;
                        end
                        else if (byte_counter == WRITE_DATA_SIZE) begin
                            data_sig <= 8'hFE;
                        end
                        else begin
                            data_sig <= din;
                            ready_for_next_byte <= 1;
                        end
                        bit_counter <= 7;
                        state <= WRITE_BLOCK_BYTE;
                        byte_counter <= byte_counter - 1'b1;
                    end
                end
                WRITE_BLOCK_BYTE: begin
                    if (sclk_sig == 1) begin
                        if (bit_counter == 0) begin
                            state <= WRITE_BLOCK_DATA;
                            ready_for_next_byte <= 0;
                        end
                        else begin
                            data_sig <= {data_sig[6:0], 1'b1};
                            bit_counter <= bit_counter - 1'b1;
                        end
                    end
                    sclk_sig <= ~sclk_sig;
                end
                WRITE_BLOCK_WAIT: begin
                    if (sclk_sig == 1) begin
                        if (miso == 1) begin
                            state <= IDLE;
                            cmd_mode <= 1;
                        end
                    end
                    sclk_sig <= ~sclk_sig;
                end
            endcase
        end
    end

    assign sclk = sclk_sig;
    assign mosi = cmd_mode ? cmd_out[55] : data_sig[7];
    assign ready = (state == IDLE);
	// assign read_mbr = (state == return_state);
	 
endmodule
