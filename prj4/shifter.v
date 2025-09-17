`timescale 10 ns / 1 ns

`define DATA_WIDTH 32

module shifter (
	input  [`DATA_WIDTH - 1:0] A,   //need shift
	input  [              4:0] B,   //shift length
 	input  [              1:0] Shiftop, // conduct instruction 00:left 11:math right 10:logic right 
	output [`DATA_WIDTH - 1:0] Result
);
	// TODO: Please add your logic code here
        wire [31:0] r1;
	assign r1 = $signed(A) >>> B;
	assign Result = ~Shiftop[1] ? (A<<B) : 
	                Shiftop[0] ? r1 : (A>>B);              
	       
endmodule

