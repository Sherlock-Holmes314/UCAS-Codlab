`timescale 10 ns / 1 ns

`define TARRAY_DATA_WIDTH 24
`define TARRAY_ADDR_WIDTH 3

//一共1024字节，一块32字节8个字,4块一组，故一共8组，组地址3bit，段内5bit

module tag_array(
	input                             clk,
	input                             rst,
	input  [`TARRAY_ADDR_WIDTH - 1:0] waddr,
	input  [`TARRAY_ADDR_WIDTH - 1:0] raddr,
	input                             wen,
	input  [`TARRAY_DATA_WIDTH - 1:0] wdata,
	output [`TARRAY_DATA_WIDTH - 1:0] rdata,
	output                            valid
);

	reg [`TARRAY_DATA_WIDTH - 1:0] array[ (1 << `TARRAY_ADDR_WIDTH) - 1 : 0];
	reg [ (1 << `TARRAY_ADDR_WIDTH) - 1 : 0] valid_array;
	
	always @(posedge clk)
	begin
		if(wen)begin
			array[waddr] <= wdata;
		end
	end

	always @(posedge clk)
	begin   
		if(rst)begin
		        valid_array <= 8'b0;
		end
		if(wen)begin
			valid_array[waddr] <= 1'b1;
		end
	end

assign rdata = array[raddr];
assign valid = valid_array[raddr];

endmodule

