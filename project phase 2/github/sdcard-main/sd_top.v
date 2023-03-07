`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    18:05:52 06/23/2021 
// Design Name: 
// Module Name:    sd_top 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module sd_top_sd(
			input clk_25,  // 100MHZ
			input iRSTn,
					
			 output sd_clk,
			inout  sd_cmd,
			inout  [3:0] sd_dat, 
			
//			 input  miso,
//			 output mosi,
//			 output csn,
//			 output sclk, 
			
			input sd_en_wr,
			input [7:0]Pic_ID,
			input sd_bin_set_wr,
			input sd_bin_en_wr,
			input [7:0]bin_name_wr,
			output sdcard_idle,		
			output sd_data_valid,
			output [29:0]sd_addr,
			output [31:0]sd_data,
			output sdcard_present,
			output sd_flash_en,
			output [7:0]total_sdimage_count,
			output filename_count_end
    );



// Debugg signals
	wire byte_enable_o;   // byte ready enable
	wire [9:0]byte_address_o;
	wire [7:0]sdcard_data;
	wire file_reading;  // file read enable
	wire reading_o;   // byte read enable
	wire read_done_o;  // byte read done enable
	wire [3:0]step_o;
	wire [3:0]state_o;
	wire [3:0]file_state_o;
	wire [7:0]file_name_o;
	wire [8:0]sector_buf_rd_addr_o;

	wire [8:0]byte_address;
	wire [7:0]sdcard_datatofat;
	wire byte_enable;
	wire rd_enable;
	wire sdcard_init_done;
	wire sdcard_rd_enable;
	wire [31:0]sdcard_sector_address;
	wire reading;
	wire read_done;
	wire [31:0]file_data_addr;
	wire [31:0]file_size;
	wire [7:0]file_name;
	wire file_reach_end;

	////////////////////////////////////////////
//	assign sdcard_data = sdcard_datatofat;
	assign byte_enable_o = byte_enable;
	////////////////////////////////////////

	wire [31:0]sector_count = (file_size/512)+1;
	wire bin_data_en;
	
	sdcard_fat32_read_sd sd_fat32_sd(

								.iCLK(clk_25),
								.iRSTn(iRSTn),
								.sd_en(sd_en_wr),
								.sd_bin_en(sd_bin_en_wr),
								.bin_name(bin_name_wr),
								.sdcard_idle(sdcard_idle),
								.file_sel(Pic_ID),
								.total_sector_num(sector_count),
								.addr_i(byte_address),
								.data_i(sdcard_datatofat),
								.init_done(sdcard_init_done),
								.byte_available(byte_enable_o),
								.sector_rd_start(sdcard_rd_enable),
								.sector_rd_addr(sdcard_sector_address),
								.reading (reading),
								.read_done (read_done),
								.sector_buf_rd_addr(),//sector_buf_rd_addr_o
								.filename_count_o(total_sdimage_count),
								.file_reading(file_reading),
								.filename_count_end(filename_count_end),//file_reach_end
								.file_size(file_size),
								.file_read_size(file_data_addr),
								.multi_sector_en(multi_sector_en)
								
							);

	/*sd_controller_sd sd_spi_sd(
					.clk(clk_25),
					.reset(iRSTn),
					.cs(csn), 
					.mosi(mosi), 
					.miso(miso), 
					.sclk(sclk), 
					.i_blk_num(sector_count),	// file_size/512
					.rd(sdcard_rd_enable),  //
					.dout(sdcard_datatofat),  // 
					.byte_available(byte_enable), 
					.byte_counter(byte_address),
					.wr(1'b0),  
					.din(8'h0), 
					.ready_for_next_byte(), 
					.ready(sdcard_init_done), 
					.address(sdcard_sector_address),    
					.status(),
					.recv_data(),
					.reading (),//reading
					.read_done (read_done),
					.multi_sector_en(multi_sector_en),
					.sdcard_present(sdcard_present)
					
	);*/




	sdmode_controller sdc(
								  .i_clk(clk_25),
								  .i_rst(iRSTn),
								  .o_ready(sdcard_init_done),//
								// SD_READ
								  .i_ren(sdcard_rd_enable),     // 
								  .o_data(),  // 
								  .o_data_en(),
							  // SD_WRITE
								  .i_wen(),
								  .i_data(),
								  .o_data_ready(),

								  .i_blk_num(sector_count),//
								  .i_adr(sdcard_sector_address),//32'd32768  

								  .o_state(),

								  .sd_clk(sd_clk),
								  .sd_cmd(sd_cmd),
								  .sd_dat(sd_dat),
								  
								  .sd_data(sdcard_datatofat),
								  .sd_byte_addr(byte_address[8:0]),
								  .sd_data_en(byte_enable),
								  .read_done(read_done),
								  .multi_sector_en(multi_sector_en),
								  .sdcard_present(sdcard_present),
								  .sd_flash_en(sd_flash_en)
							 );
		
							
	reg [1:0]	count = 2'b00;
	reg 		ramdata_valid = 1'b0;
	reg [7:0]	ram_data;
	reg [15:0]	x_addr;
	reg [15:0]	y_addr;
	reg [29:0]	wr_addr;
	reg [7:0]  wr_data;
	wire  		wr_valid;

	always@(posedge clk_25) begin
		if(iRSTn)	begin
			ramdata_valid <= 1'b0;
			ram_data <= 16'b0 ;
		//	count <= 2'b00;
		end
		else if(file_data_addr <= 53 && file_reading && byte_enable)begin
			count <= 2'b00;
		end
		else if(file_reading && byte_enable && (~sd_bin_set_wr)) begin
			if(count == 2'b00) begin
				ramdata_valid <= 1'b0;
				ram_data[1:0] <= sdcard_datatofat[7:6];
				count <= 2'b01;
			end
			else if(count == 2'b01) begin
				ram_data[4:2] <= sdcard_datatofat[7:5];
				ramdata_valid <= 1'b0;
				count <= 2'b10;
			end
			else if( count == 2'b10) begin
				ram_data[7:5] <= sdcard_datatofat[7:5];
				ramdata_valid <= 1'b1;
				count <= 2'b00;
			end
		end
		else begin 
			ramdata_valid <= 1'b0;
		end 
	end


	always@(posedge clk_25) begin
		if(iRSTn) begin
			wr_addr <= 0 ;
		end 
		else if(ramdata_valid) begin
			wr_addr <= (x_addr)+((y_addr)*10'd800);
		end
	end
	
	always@(posedge clk_25) begin
		if(iRSTn) begin 
			x_addr <= 0;
			y_addr <= 0;
			wr_data <= 0;
		end
		else if(file_data_addr <= 8'd53) begin //&& reading && byte_enable //file_data_addr == 0
			x_addr <= 0;
			y_addr <= 0;
			wr_data <= 0;
		end 
		else if(ramdata_valid) begin 
			wr_data <= ram_data;
			if(x_addr < 800-1) begin 
				x_addr 	<= x_addr + 1'b1 ;
			end 
			else if(y_addr < 480-1) begin 
				x_addr <= 0;
				y_addr <= y_addr + 1'b1;
			end 
			else begin 
				x_addr <= 0;
				y_addr <= 0;
			end 
		end
	end 
	
	reg [7:0] 	sd_bin_wr_data;
	reg [14:0]	sd_bin_wr_addr;
	reg 	 	sd_bin_wr_en;
	
	always@(posedge clk_25) begin 
		if(iRSTn) begin 
			sd_bin_wr_data <= 0;
			sd_bin_wr_addr <= 0;
			sd_bin_wr_en   <= 0;
		end
		else if(sd_bin_set_wr) begin  
			if(file_data_addr == 0 && file_reading && byte_enable)begin
				sd_bin_wr_en   <= 1;
				sd_bin_wr_addr <= 0;
				sd_bin_wr_data <= sdcard_datatofat;
			end
			else if(file_reading && byte_enable && (sd_bin_set_wr)) begin
				sd_bin_wr_en   <= 1;
				sd_bin_wr_addr <= sd_bin_wr_addr+1'b1;
				sd_bin_wr_data <= sdcard_datatofat;
			end 
			else 
				sd_bin_wr_en   <= 0;
		end 
		else 
			sd_bin_wr_en   <= 0;
	end 

	assign sd_data_valid  = (sd_bin_set_wr) ? sd_bin_wr_en   : ramdata_valid; //wr_valid&ramdata_valid;
	assign sd_addr 		  = (sd_bin_set_wr) ? sd_bin_wr_addr : wr_addr;		// (file_data_addr/3); //(img_read_addr/3);// + swap_addr;
	assign sd_data 		  = (sd_bin_set_wr) ? sd_bin_wr_data : {24'h0,wr_data}; 	//  (x_addr == 32)? 32'hffff_ffff : ram_data;

endmodule
