`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    16:07:20 02/22/2021 
// Design Name: 
// Module Name:    lcd_disp 
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
module display(clk,rst,color,hsync,vsync,de,red, green, blue,x,y);
	// VGA signal explanation and timing values for specific modes:
	// http://www-mtl.mit.edu/Courses/6.111/labkit/vga.shtml
	`include "param.h"
	
	input clk;
	input rst;
	
	input [(r_width+g_width+b_width)-1:0]color;
	
	output hsync, vsync;
	output de;
	output [x_width-1:0] x;
	output [y_width-1:0] y;
	
	output [r_width-1:0] red;
	output [g_width-1:0] green;
	output [b_width-1:0] blue;
	
	reg [h_width-1:0] h_count;
	reg [v_width-1:0] v_count;
	
	always @(posedge clk)
	begin
		if(rst) begin 
			h_count <= 0;
			v_count <= 0;
		end 
		else if (h_count < H_ACTIVE + H_FRONT + H_PULSE + H_BACK - 1)
			// Increment horizontal count for each tick of the pixel clock
			h_count <= h_count + 1'b1;
		else
		begin
			// At the end of the line, reset horizontal count and increment vertical
			h_count <= 0;
			if (v_count < V_ACTIVE + V_FRONT + V_PULSE + V_BACK - 1)
				v_count <= v_count + 1'b1;
			else
				// At the end of the frame, reset vertical count
				v_count <= 0;
		end
	end
	
	// Generate horizontal and vertical sync pulses at the appropriate time
	assign hsync = (h_count > H_ACTIVE + H_FRONT && h_count < H_ACTIVE + H_FRONT + H_PULSE)?1'b1:1'b0;
	assign vsync = (v_count > V_ACTIVE + V_FRONT && v_count < V_ACTIVE + V_FRONT + V_PULSE)?1'b1:1'b0;
	
	// Output x and y coordinates
	assign x = h_count < H_ACTIVE ? h_count[x_width-1:0] : 1'b0;
	assign y = v_count < V_ACTIVE ? v_count : 1'b0;

	//display en
	assign de = (!rst && v_count < V_ACTIVE && h_count < H_ACTIVE)?1'b1:1'b0;
	//---------------------------------------------------------------- 
	     
	// Generate separate RGB signals from different parts of color byte
	// Output black during horizontal and vertical blanking intervals
	assign red 	 = de ? color[(r_width+g_width+b_width)-1:(g_width+b_width)] : 1'b0; 
	assign green = de ? color[(g_width+b_width)-1:b_width]                   : 1'b0; 
	assign blue  = de ? color[b_width-1:0]                                   : 1'b0;  
	
/* 	//synthesis translate off
		//write file
	integer red_file,green_file,blue_file;

	initial begin 
		red_file = $fopen("../log/Red_value.txt");
		green_file = $fopen("../log/Green_value.txt");
		blue_file = $fopen("../log/Blue_value.txt");
	end 
	
	reg [20:0]write_addr=0;
	reg [2:0]fram = 0;
	wire req;
	
	wire [7:0]R = red*8;
	wire [7:0]G = green*4;
	wire [7:0]B = blue*8;
	
	assign req = de;
   
	always@(posedge clk)
	  if(rst) begin 
	     write_addr <= 0;
	  end 	
	  else if(write_addr == (H_ACTIVE*V_ACTIVE)) begin 
	     if(fram==0) begin 
			$fclose(red_file);
			$fclose(green_file);
			$fclose(blue_file);
			$finish;
		 end 
		  fram <= fram + 1;
		  write_addr <= 0;
	  end 
	  else if(req) begin
	     write_addr <= write_addr + 1 ;
	     if(fram == 0) begin
				//$display("x %d y %d",x,y);
				$fwrite(red_file,"%h\n",R);
				$fwrite(green_file,"%h\n",G);
				$fwrite(blue_file,"%h\n",B);
		  end 	
	  end
	//synthesis translate on */
	
endmodule
