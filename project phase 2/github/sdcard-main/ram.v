//--------------------------------------------------------------------------------------------------
// Design    : bitstream_p
            
//-------------------------------------------------------------------------------------------------


// // 
module ram
(
clk,
wr_n, 
addr, 
data_in, 
data_out
);
parameter addr_bits = 9;
parameter data_bits = 8;
input     clk;
input     wr_n;
input     [addr_bits-1:0]  addr;
input     [data_bits-1:0]  data_in;
output    [data_bits-1:0]  data_out;

reg       [data_bits-1:0]  ram[0:(1 << addr_bits) -1];
reg       [data_bits-1:0]  data_out;

//read
always @ ( posedge clk )
begin
    data_out <= ram[addr];
end 

//write
always @ (posedge clk)
begin
    if (wr_n)
        ram[addr-1] <= data_in;
end

endmodule
