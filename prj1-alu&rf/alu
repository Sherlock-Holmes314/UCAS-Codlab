`timescale 10 ns / 1 ns

`define DATA_WIDTH 32

module alu(
	input  [`DATA_WIDTH - 1:0]  A,
	input  [`DATA_WIDTH - 1:0]  B,
	input  [              2:0]  ALUop,
	output                      Overflow,
	output                      CarryOut,
	output                      Zero,
	output [`DATA_WIDTH - 1:0]  Result
);
	// TODO: Please add your logic design here   000:and  001:or  010:add  110:sub  111: signed compare(a<b:1  a>=b:0)
	wire [`DATA_WIDTH - 1:0] r0;
	wire [`DATA_WIDTH - 1:0] r1;
	wire [`DATA_WIDTH - 1:0] r2;
	wire carry;
	wire r7;
	wire [`DATA_WIDTH - 1:0] b_input;

	assign r0 = A & B;
	assign r1 = A | B;
	assign b_input=(ALUop == 3'b010)? B : ~B;  //pay attention to the appendix code of a pair of opposite integer, which b -> ~b + 1
	assign {carry,r2}=A + b_input + ALUop[2];  
        assign r7 = (A[`DATA_WIDTH - 1] ^ B[`DATA_WIDTH - 1]) ? A[`DATA_WIDTH - 1] : r2[`DATA_WIDTH - 1];

	assign Result= (ALUop == 3'b000)? r0 :        // the form : 3'b000
	               (ALUop == 3'b001)? r1 :
		       (ALUop == 3'b010 || (ALUop == 3'b110))? r2 :
                       (ALUop == 3'b111)? {31'b0,r7} : 32'b0;    // don't calculate different length integer: for r7 should be 1 zijie

	assign Zero= (Result == 32'd0);

	assign Overflow =((ALUop == 3'b010)? (~(A[`DATA_WIDTH - 1]^B[`DATA_WIDTH - 1])) : (A[`DATA_WIDTH - 1]^B[`DATA_WIDTH - 1])) & (A[`DATA_WIDTH - 1]^r2[`DATA_WIDTH - 1]);
	 
	assign CarryOut =(ALUop == 3'b010)? carry : ~carry;

endmodule
