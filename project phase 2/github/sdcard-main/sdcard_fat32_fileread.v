`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    06:48:12 02/15/2021 
// Design Name: 
// Module Name:    partition_read 
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
module sdcard_fat32_read_sd(
								input iCLK,
								input iRSTn,
								input sd_en,
								input sd_bin_en,
								output sdcard_idle,
								input [31:0]total_sector_num,
								input [7:0]file_sel,
								input [8:0]addr_i,
								input [7:0]data_i,
								input init_done,
								input byte_available,
								output reg sector_rd_start,
								output reg [31:0]sector_rd_addr,
								input reading,
								input read_done,
															
								input [7:0]bin_name,
								output reg [7:0]filename_count_o,
								output reg [8:0] sector_buf_rd_addr,
								output reg[31:0]file_size,
								output reg file_reading,
								output reg [31:0] file_read_size,
								output reg filename_count_end,
								output multi_sector_en
							);

	wire [8:0] sector_buf_addr;
	wire [7:0] sector_buf_data;
	reg [31:0] dbr_sector_addr;
	reg [7:0]  sectors_per_cluster;
	reg [15:0] reserved_sector_num;
	reg [23:0] sectors_per_fat;
	reg [22:0] fat1_sector_addr;
	reg [22:0] rootdir_sector_addr;

	reg [3:0] step;
	reg [3:0] state;
	reg [3:0] file_state;

	parameter    
	Idle = 0,    
	ReadDPT = 1, 
	ReadDBR = 2, 
	ReadFile = 3;

	parameter
	FileIdle = 0,
	FileReadRootDir = 1,
	Filenameread = 2,
	FileGetParams = 3,
	FileRead  = 4;


	reg [6:0] root_dir_filename_offset;
	reg [3:0] file_select_index;
	reg [23:0]file_cluster_index;
	reg [6:0] file_cluster_index_old;

	reg [7:0]  file_sector_index;
	reg file_reach_end;
	reg file_output;
	reg dir_en; // new signal added for directory_select
	reg file_en; // new signal added for file_select
	///////////////////////////////////////////////////////////////////////////
	reg [7:0]file_name_sel;
	reg [7:0]filename_count; // count the Number of filenames
	reg [255:0]filename_read; // store the filenames
	reg [55:0]filename_mem[255:0];
	reg  [55:0]filename_reg;
	wire [7:0]file_name;
	reg [55:0]filename_mem_wdata;
	reg [7:0]filename_mem_waddr;
	reg filename_mem_wen;
	reg [1:0]file_bin_sel;
	reg bmp_en;

	assign file_name = (filename_read[247:240] < 8'h30) || (filename_read[247:240] > 8'h39)  ? (filename_read[255:248]-8'h30) :
							  (filename_read[239:232] < 8'h30) || (filename_read[239:232] > 8'h39) ? ((filename_read[255:248]-8'h30)*10)+(filename_read[247:240]-8'h30):
							  (filename_read[231:224] < 8'h30) || (filename_read[231:224] > 8'h39) ? ((filename_read[255:248]-8'h30)*100)+((filename_read[247:240]-8'h30)*10) + (filename_read[239:232]-8'h30) : 8'd0; 
	reg img_end;
	assign multi_sector_en = (file_state == FileRead) ? 1'b1:1'b0;
	assign sdcard_idle = (state == ReadFile) ? ((file_state == FileIdle) ? 1'b1 :1'b0):1'b0;
	
		always@(posedge iCLK)
			if(iRSTn)
				filename_reg <= 0;
			else if(filename_mem_wen)
				filename_mem[filename_mem_waddr] <= filename_mem_wdata;
			else 
				filename_reg <= filename_mem[file_name_sel]; 

	/////////////////////////////////////////////////////////////////

/////////  512 byte Sector data from SDCARD saved in temp memory /////////
	assign sector_buf_addr = byte_available ? addr_i: sector_buf_rd_addr;
	ram #(9,8) partition_ram
	(
		.clk(iCLK),
		.wr_n(byte_available), 
		.addr(sector_buf_addr), 
		.data_in(data_i), 
		.data_out(sector_buf_data)
	);
//////// Partiton, MBR, RootDir, File_search : Selected sector_buf_data read by sector_buf_rd_addr from partition_ram memory //////////
	always @(*)
	begin
	case (state)
	Idle :  sector_buf_rd_addr <= 0;

	ReadDPT : begin
					case (step)
						3:sector_buf_rd_addr <= 'h000;
						4:sector_buf_rd_addr <= 'h001;
						5:sector_buf_rd_addr <= 'h002;
						7:sector_buf_rd_addr <= 'h1c6; //  Master
						8:sector_buf_rd_addr <= 'h1c7; //  Boot
						9:sector_buf_rd_addr <= 'h1c8; //  Sector
						10:sector_buf_rd_addr<= 'h1c9; //  Address
					 default:sector_buf_rd_addr <= 0;
					 endcase
				  end
	ReadDBR : begin
					case (step)
					  	2:sector_buf_rd_addr <= 'hd;     // Sector per cluster
						3:sector_buf_rd_addr <= 'he;     // Reserved Sectors[7:0]
						4:sector_buf_rd_addr <= 'hf;     // Reserved Sectors [15:8]
						5:sector_buf_rd_addr <= 'h24;    // sectors_per_fat [7:0]
						6:sector_buf_rd_addr <= 'h25;    // sectors_per_fat [15:8]
						7:sector_buf_rd_addr <= 'h26;    // sectors_per_fat [23:16]
					default : sector_buf_rd_addr <= 0;
					endcase
				end
	ReadFile : begin
						case (file_state)	
							Filenameread : begin
													case (step)
														1:sector_buf_rd_addr <= (file_select_index << 5) + root_dir_filename_offset; // Filename&directory search characters address
													
														default : sector_buf_rd_addr <= 0;
													endcase
												end					
																
							FileRead		 :	begin
													case (step)
														8:sector_buf_rd_addr <= (file_cluster_index_old[6:0] << 2) + 2'd0;
														9:sector_buf_rd_addr <= (file_cluster_index_old[6:0] << 2) + 2'd1;
														10:sector_buf_rd_addr <= (file_cluster_index_old[6:0] << 2) + 2'd2;
														default : sector_buf_rd_addr <= 0;
													endcase
												end 
							default 		 :    sector_buf_rd_addr <= 0;
						endcase
				 end
	default : sector_buf_rd_addr <= 0;
	endcase			 

	end
/////////////////////////////////////////////////////////////////////////////////////////////////////
/// Partiton, MBR, RootDir, File_search : Read 512 Sector_Data from SDCARD 
/////////////////////////////////////////////////////////////////////////////////////////////////////

	always@(posedge iCLK )
	begin
	if(iRSTn)
	begin
		sector_rd_start <= 1'b0;
		sector_rd_addr  <= 32'b0;
		state <= Idle;
		step <= 0;
		dbr_sector_addr <= 0;
		file_name_sel <= 8'b0;
		sectors_per_cluster <= 0;
		reserved_sector_num <= 0;
		sectors_per_fat <= 0;
		fat1_sector_addr <= 0;
		rootdir_sector_addr <= 0;
		file_state <= FileIdle;
		file_select_index <= 0;
		file_sector_index <= 0;
		file_cluster_index <= 0;
		file_cluster_index_old <= 0;
		file_size <= 0;
		file_read_size <= 0;
		file_reading <= 0;
		file_reach_end <= 0;
		
		// auto fileread 
		filename_count <= 0; 
		filename_count_o <= 0;
		filename_count_end   <= 1'b0;
		filename_read 	<= 0;
		dir_en 		  	<= 1'b0;
	end
	else 
	begin
		case (state)
		Idle : begin
					 if (init_done)  //&& !all_done
					 begin
							state <= ReadDPT;
							step <= 0;						
					 end
					 else
							state <= Idle;
					 end
	///////// READ Disk Partition Table entry data which is the first sector in SDCARD ///////////
	///////// Find the Master Boot Record sector address ///////////////////////////////////////////////
	ReadDPT : begin
					if (step == 0) 
					begin
							step <=1;
							sector_rd_start <= 1;
							sector_rd_addr <= 0;
					end
					else if (step == 1) 
					begin
							sector_rd_start <= 0;
							step <= 2;
					end
					else if (step == 2) 
					begin
							if (read_done) 
								step <= 3;		
					end
					else if (step == 3) 
								step <= 4;
					else if (step == 4)
					begin
							if (sector_buf_data == 'heb)
									step <= 5;
							else
									step <= 7;
					end
					else if (step == 5) 
					begin
							if (sector_buf_data == 'h58)
									step <= 6;
							else
									step <= 7;
					end
					else if (step == 6) 
					begin
							if (sector_buf_data == 'h90) //current sector is DBR
							begin 
									dbr_sector_addr <= 0;
									state <= ReadDBR;
									step <= 0;
							end
							else
									step <= 7;
					end
					else if (step == 7) 
					begin
									
									step <= 8;
					end
					else if (step == 8) 
					begin
									dbr_sector_addr[7:0] <= sector_buf_data;	
									step <= 9;
					end
					else if (step == 9) 
					begin
									dbr_sector_addr[15:8] <= sector_buf_data;
									step <= 10;
					end
					else if (step == 10) 
					begin
									dbr_sector_addr[23:16] <= sector_buf_data; //dbr_sector_addr[31:24] <= sector_buf_data;	
									state <= ReadDBR;
									step <= 0;			
					end			
				end
	///////// READ Disk/Master Boot Recorder entry data which has the sdard parameters ///////////
	///////// Find the Root directory sector address ///////////////////////////////////////////////
		
	ReadDBR : begin
					if (step == 0) 
					begin
					   if(init_done)
						begin
							step <=1;
							sector_rd_start <= 1;
							sector_rd_addr <= dbr_sector_addr;
						end
						else
						  step <= 0;
					end
					else if (step == 1) 
					begin
							sector_rd_start <= 0;
							step <= 2;
					end
					else if (step == 2) 
					begin
						if (read_done) 
							step <= 3;		
					end
					else if (step == 3) 
					begin
							sectors_per_cluster <= sector_buf_data;
							step <= 4;
					end
					else if (step == 4) 
					begin
							reserved_sector_num[7:0] <= sector_buf_data;
							step <= 5;
					end
					else if (step == 5) 
					begin
							reserved_sector_num[15:8] <= sector_buf_data;
							step <= 6;
					end
					else if (step == 6) 
					begin
							sectors_per_fat[7:0] <= sector_buf_data;
							step <= 7;
					end
					else if (step == 7)
					begin
							sectors_per_fat[15:8] <= sector_buf_data;
							step <= 8;
					end
					else if (step == 8) 
					begin
							sectors_per_fat[23:16] <= sector_buf_data[5:0];
							step <= 9;
					end
					else if (step == 9) 
					begin
							fat1_sector_addr    <= dbr_sector_addr[22:0] + reserved_sector_num; 
							step <= 10;
					end
					else if (step == 10) 
					begin
							rootdir_sector_addr <= fat1_sector_addr + (sectors_per_fat[22:0] << 1);
							step <= 0;
							state <= ReadFile;
							file_state <= FileReadRootDir;
							file_cluster_index <= 2;
							file_sector_index  <= 0;
														
					end
				end
	
   ///////// READ file_name & file_directory sector address from the root directory ///////////	
			
	ReadFile : begin
					filename_mem_wen <= 0;
					case (file_state)
						FileIdle : begin
											if(sd_en) begin //  all_done && 
												file_state <= FileRead;												
												step <= 4;
												file_name_sel <= file_sel; //+2'b10;	
												bmp_en <= 1'b1;
											end
											else if(sd_bin_en) begin 
												file_state <= FileRead;												
												step <= 4;
												file_name_sel <= bin_name;
												bmp_en <= 1'b0;
											end 
									   end
					  FileReadRootDir:begin
												if (step == 0) 
												begin
												 if(init_done)
												 begin
														if (file_cluster_index < 24'hfffff8)  // 20'hffff8 = 1048568
														begin 
															step <=1;
															sector_rd_start <= 1;
																if (sectors_per_cluster == 8)
																	sector_rd_addr <= rootdir_sector_addr + ((file_cluster_index - 2) << 3) + file_sector_index;
																else if(sectors_per_cluster == 16)
																	sector_rd_addr <= rootdir_sector_addr + ((file_cluster_index - 2) << 4) + file_sector_index;
																else if(sectors_per_cluster == 32)
																	sector_rd_addr <= rootdir_sector_addr + ((file_cluster_index - 2) << 5) + file_sector_index;
																else //(sectors_per_cluster == 64)
																	sector_rd_addr <= rootdir_sector_addr + ((file_cluster_index - 2) << 6) + file_sector_index;
														end											 											
														else 
														begin
																state <= Idle;
																file_state <= FileIdle;																																
														end 
												end
												else
												        step <= 0;
												end
												else if (step == 1) 
												begin
															sector_rd_start <= 0;
															step <= 2;
												end
												else if(step == 2)
												begin
													if(!filename_count_end ) 
													begin 
														if (read_done) 
															begin
															step <= 0;
															file_state <= Filenameread; 
															file_select_index <= 0;
															end
														end
													else 
													     step <= 3;
													end
												else if (step == 3) 
												begin
													//file_cluster_index <= filename_reg[55:32];
												  // file_size <= filename_reg[31:0];																										   
													file_state <= FileIdle;
													file_select_index <= 0;
													file_sector_index <= 0;
													//file_read_size <= 0;
												  // file_reach_end <= 0;
													step <= 0;
												end
											end
										
						/////////////////////////////////////////////////////
						// read the filename & Directory , store it in memory
						/////////////////////////////////////////////////////////
						Filenameread: begin
												if(step == 0)
												begin
													root_dir_filename_offset <= 6'd0;
													step <= 1;
												end
												else if(step == 1)
													step <= 2;
												else if(step == 2)
												begin
													if(!filename_count_end)
														begin
															if(root_dir_filename_offset < 32)
															begin
																	filename_read <= {filename_read[247:0],sector_buf_data};	
																	root_dir_filename_offset <=  root_dir_filename_offset + 1'b1;
																																	
																	step <= 1;
															end	
															else if(root_dir_filename_offset == 32)
															begin
																	root_dir_filename_offset <= 0;
																																		
																	if(filename_read[255:248] == 8'hE5) 
																	begin
																		if (file_select_index < 15) 
																			begin
																				step <= 0;
																				file_select_index <= file_select_index + 1'b1;
																			end
																			else 
																			begin 				
																				file_select_index <= 0;
																				step <= 3;
																			end
																	end
																	else if(filename_read[255:192] == "DWIN_SET")begin //Directory name should be 8 character
																		file_cluster_index <= {filename_read[39:32],filename_read[47:40]};
																		file_state <= FileReadRootDir;
																		file_sector_index <= 8'd0;
																		step <= 4'd0;
																		dir_en <= 1'b1;
																	end
																	else if(((filename_read[191:168] == "BMP")||(filename_read[191:168] == "BIN")) && dir_en) begin
																			// 2 digit ASCII to Integer : ((char1 - 8'h30)*10) + (char2 - 8'h30);
																			// 3 digit ASCII to Integer : ((char1 - 8'h30)*100) + ((char2 - 8'h30)*10)+ (char3-8'h30);
																			filename_mem_wen <= 1 ;
																			 if((file_name == 13)&&(filename_read[191:168] == "BIN")) begin 
																				filename_mem_waddr <= 0;
																				filename_mem_wdata <= {filename_read[95:88],filename_read[39:32],filename_read[47:40],filename_read[7:0],filename_read[15:8],filename_read[23:16],filename_read[31:24]};
																			
																			 end 
																			 else if((file_name == 14)&&(filename_read[191:168] == "BIN")) begin 
																				filename_mem_waddr <= 1;
																				filename_mem_wdata <= {filename_read[95:88],filename_read[39:32],filename_read[47:40],filename_read[7:0],filename_read[15:8],filename_read[23:16],filename_read[31:24]};
																			
																			 end 
																			 else begin  
																				filename_mem_waddr	<=	file_name+2 ;
																				filename_mem_wdata <= {filename_read[95:88],filename_read[39:32],filename_read[47:40],filename_read[7:0],filename_read[15:8],filename_read[23:16],filename_read[31:24]};
																			   
																			 end 
																			filename_count <= filename_count + 1'b1;
																			
																			if (file_select_index < 15) 
																			begin
																				step <= 0;
																				file_select_index <= file_select_index + 1'b1;
																			end
																			else 
																			begin 				
																				file_select_index <= 0;
																				step <= 3;
																			end
																	end
																	else if(filename_read[191:160] == 32'd0 && dir_en) begin
																		filename_count_end <= 1'b1;
																		if(filename_count < 8'd255) begin
																			filename_count_o <= filename_count;//filename_count : gives total no of bmp + bin files
																			step <= 4'd2;									//filename_mem_waddr : gives last filename number
																			file_state <= FileReadRootDir;
																			file_sector_index <= 8'd0;
																			file_select_index <= 4'd0;
																		end
																	end
																	else begin
																			 if(file_select_index < 4'd15) begin
																				 step <= 4'd0;
																				 file_select_index <= file_select_index + 4'd1;																																					
																			 end
																			 else 	begin 											
																				 file_select_index <= 4'd0;																																		
																				 step <= 4'd3;	
																			 end
																	end
															end
														end
													else
													begin
															step <= 0;
															file_state <= FileReadRootDir;
															file_sector_index <= 0;
														
													end   
												end
												else if (step == 3) 
												begin
															file_sector_index <= file_sector_index + 1'b1;
															step <=4;
												end
												else if (step == 4) 
												begin
														if (file_sector_index < sectors_per_cluster) 
														begin
																file_state <= FileReadRootDir;
																step <= 0;
														end
														else 	
														begin	
																file_sector_index <= 0;
																step <= 0;
														end
												end
										end
											
					///////// READ the contents/Datas inside of the individual file_name associated in root directory ///////////	
				FileRead : begin
									if (step == 0 )  // && file_read_req
									begin
									 if(init_done)
									 begin
										step <=1;
										sector_rd_start <= 1;
										if(bmp_en)
											file_reading <= 0;
										else
											file_reading <= 1;
											
										if (sectors_per_cluster == 8)
												sector_rd_addr <= rootdir_sector_addr + ((file_cluster_index - 2) << 3);// + file_sector_index;
										else if(sectors_per_cluster == 16)
												sector_rd_addr <= rootdir_sector_addr + ((file_cluster_index - 2) << 4);// + file_sector_index;
										else if(sectors_per_cluster == 32)
												sector_rd_addr <= rootdir_sector_addr + ((file_cluster_index - 2) << 5);// + file_sector_index;
										else
												sector_rd_addr <= rootdir_sector_addr + ((file_cluster_index - 2) << 6);// + file_sector_index;			
									 end
									 else
											step <= 0;
									end
									else if (step == 1) 
									begin
											sector_rd_start <= 0;
											step <= 2;
									end	
									else if (step == 2) 
									begin
										if (byte_available)  //wr_i
											file_read_size <= file_read_size + 1;
										
										if(bmp_en) begin
											if(file_read_size == 53) 
												file_reading <= 1;	
											else if (file_read_size == file_size) //(320*240*3)total_sector_num*512
												begin
													file_reach_end <= 1;
													step <= 3;
													
												end
										end
										else begin
												if (file_read_size == file_size) //(320*240*3)total_sector_num*512
												begin
													file_reach_end <= 1;
													step <= 3;
													
												end
										end
									end
									else if (step == 3) 
									begin
										state <= ReadFile;
										file_reading <= 0;
										file_state <= FileIdle;
										//step <= 0;
									end
									else if(step == 4)
										step <= 5;
									else if(step == 5) begin
										file_cluster_index <= filename_reg[55:32];
										file_size <= filename_reg[31:0];
										file_read_size <= 0;
										file_reach_end <= 0;
										step <= 0;
									end
								end
				    endcase // file_state
			  end
    endcase // state
	end
end



endmodule
