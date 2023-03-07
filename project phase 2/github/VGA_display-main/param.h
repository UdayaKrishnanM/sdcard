`include "defines.v"
//------------ vga parameter ---------------//
`ifdef vga_640x480
	// 640x480 @ 60Hz, 25MHz pixel clock
	parameter H_ACTIVE  = 640;
	parameter H_FRONT   = 16;
	parameter H_PULSE   = 96;
	parameter H_BACK    = 48;
	parameter V_ACTIVE  = 480;
	parameter V_FRONT   = 11;
	parameter V_PULSE   = 2;
	parameter V_BACK    = 31;
`elsif vga_800x600
	parameter H_ACTIVE = 800;
	parameter H_FRONT  = 40;
	parameter H_PULSE  = 128;
	parameter H_BACK   = 88;
	parameter V_ACTIVE = 600;
	parameter V_FRONT  = 1;
	parameter V_PULSE  = 4;
	parameter V_BACK   = 23;
	
`elsif vga_800x480
	parameter H_ACTIVE = 800;
	parameter H_FRONT  = 40;
	parameter H_PULSE  = 128;
	parameter H_BACK   = 88;
	parameter V_ACTIVE = 480;
	parameter V_FRONT  = 1;
	parameter V_PULSE  = 3;
	parameter V_BACK   = 21;
`elsif vga_1280x720
	parameter H_ACTIVE = 1280;
	parameter H_FRONT  = 110;
	parameter H_PULSE  = 40;
	parameter H_BACK   = 220;
	parameter V_ACTIVE = 720;
	parameter V_FRONT  = 5;
	parameter V_PULSE  = 5;
	parameter V_BACK   = 20;

`elsif vga_1280x1024
	parameter H_ACTIVE = 1280;
	parameter H_FRONT  = 48;
	parameter H_PULSE  = 112;
	parameter H_BACK   = 248;
	parameter V_ACTIVE = 1024;
	parameter V_FRONT  = 1;
	parameter V_PULSE  = 3;
	parameter V_BACK   = 38;
`elsif vga_1920x1080
	parameter H_ACTIVE = 1920;
	parameter H_FRONT  = 88;
	parameter H_PULSE  = 44;
	parameter H_BACK   = 148;
	parameter V_ACTIVE = 1080;
	parameter V_FRONT  = 4;
	parameter V_PULSE  = 5;
	parameter V_BACK   = 36;
	
`elsif simulation
	parameter H_ACTIVE = 100;
	parameter H_FRONT  = 6;
	parameter H_PULSE  = 2;
	parameter H_BACK   = 2;
	parameter V_ACTIVE = 50;
	parameter V_FRONT  = 1;
	parameter V_PULSE  = 3;
	parameter V_BACK   = 7;
	
`endif
`ifdef vga_332
	parameter r_width = 3;
	parameter g_width = 3;
	parameter b_width = 2;
`elsif vga_565
	parameter r_width = 5;
	parameter g_width = 6;
	parameter b_width = 5;
`elsif vga_888
	parameter r_width = 8;
	parameter g_width = 8;
	parameter b_width = 8;
`endif
	
parameter x_width = $clog2(H_ACTIVE);
	parameter y_width = $clog2(V_ACTIVE);
	parameter h_width = $clog2(H_ACTIVE+H_FRONT+H_PULSE+H_BACK);
	parameter v_width = $clog2(V_ACTIVE+V_FRONT+V_PULSE+V_BACK);