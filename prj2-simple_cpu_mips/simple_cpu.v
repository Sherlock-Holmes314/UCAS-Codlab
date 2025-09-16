`timescale 10ns / 1ns

module simple_cpu(
	input             clk,
	input             rst,           //高电平复位

	output reg [31:0]     PC,               //count number
	input  [31:0]     Instruction,      //from memory to conduction

	output [31:0]     Address,      // the address of load
	output            MemWrite,     //wen,effective in high     op5&op3
	output [31:0]     Write_data,    
	output [ 3:0]     Write_strb,    //bit effective（写入位为1）

	input  [31:0]     Read_data,     //from mem
	output            MemRead        //ren   op5&~op3
);

	// THESE THREE SIGNALS ARE USED IN OUR TESTBENCH
	// PLEASE DO NOT MODIFY SIGNAL NAMES
	// AND PLEASE USE THEM TO CONNECT PORTS
	// OF YOUR INSTANTIATION OF THE REGISTER FILE MODULE
	//指令数据                  
	wire			RF_wen;
	wire [4:0]		RF_waddr;
	wire [31:0]		RF_wdata;
	wire [5:0]              opcode;
	wire [4:0]              rs;
	wire [4:0]              rt;
	wire [4:0]              rd;
	wire [4:0]              shamt;
	wire [5:0]              func;
	wire [15:0]             immediate;
	wire [25:0]             distance;   
	wire [31:0]             next;
	wire [31:0]             target; 

	assign next = PC + 4;
	assign opcode = Instruction[31:26];
	assign rs = Instruction[25:21];
	assign rt = Instruction[20:16];
	assign rd = Instruction[15:11];
	assign shamt = Instruction[10:6];
	assign func = Instruction[5:0];
	assign immediate = Instruction[15:0];
	assign distance = Instruction[25:0];

        //R-type数据
	wire         wen_R;
	wire [31:0]  wdata_R;
	wire [31:0]  A_alu_R;
	wire [31:0]  B_alu_R;
	wire [ 2:0]  ALUop_R;

	//I-type数据
	wire [31:0]  wdata_IC;
	wire [31:0]  A_alu_I;
	wire [31:0]  B_alu_I;
	wire [ 2:0]  ALUop_I;

	//J
	wire [31:0]  wdata_J;
	wire [31:0] target_J;

	//load
	wire [31:0]  A_alu_LS;
	wire [31:0]  B_alu_LS;
	wire [ 2:0]  ALUop_LS;
        wire [31:0]     Read_data_1;
	wire [31:0]     Read_data_2;
	wire [2:0]      rsign;
	wire [31:0]     wdata_L;
	wire [7:0]      read_b;
	wire [15:0]     read_h;

	//store
	wire [ 3:0]     wtrb1;
	wire [ 3:0]     wtrb2;
	wire [31:0]     Write_data_1; 
	wire [31:0]     Write_data_2; 
	wire [2:0]      wsign2;
	wire [3:0]      wsign1;
	wire [31:0]     write_b;
	wire [31:0]     write_h;

	//branch
	wire [31:0]  A_alu_b;
	wire [31:0]  B_alu_b;
	wire [ 2:0]  ALUop_b;
	wire [31:0] target_b;

	//regimm
	wire [31:0] target_RE;
	wire [31:0]  A_alu_RE;
	wire [31:0]  B_alu_RE;
	wire [ 2:0]  ALUop_RE;

	//主alu 数据
	wire [31:0]  A_alu;
	wire [31:0]  B_alu;
	wire [ 2:0]  ALUop;
	wire         Overflow;
	wire         CarryOut;
	wire         Zero;
	wire [31:0]  Result_alu;

	assign A_alu = ({32{~(opcode[5]|opcode[4]|opcode[3]|opcode[2]|opcode[1]|opcode[0])}} & A_alu_R )
	             | ({32{~opcode[5] & ~opcode[4] & opcode[3]}} & A_alu_I)
		     | ({32{~(opcode[5]|opcode[4]|opcode[3]|opcode[2]|opcode[1]|~opcode[0])}} & A_alu_RE)
		     | ({32{opcode[5]}} & A_alu_LS)
		     | ({32{~opcode[5] & ~opcode[4] & ~opcode[3] & opcode[2]}} & A_alu_b);
	assign B_alu =({32{~(opcode[5]|opcode[4]|opcode[3]|opcode[2]|opcode[1]|opcode[0])}} & B_alu_R )
	             | ({32{~opcode[5] & ~opcode[4] & opcode[3]}} & B_alu_I)
		     | ({32{~(opcode[5]|opcode[4]|opcode[3]|opcode[2]|opcode[1]|~opcode[0])}} & B_alu_RE)
		     | ({32{opcode[5]}} & B_alu_LS)
		     | ({32{~opcode[5] & ~opcode[4] & ~opcode[3] & opcode[2]}} & B_alu_b);
	assign ALUop =({3{~(opcode[5]|opcode[4]|opcode[3]|opcode[2]|opcode[1]|opcode[0])}} & ALUop_R )
	             | ({3{~opcode[5] & ~opcode[4] & opcode[3]}} & ALUop_I)
		     | ({3{~(opcode[5]|opcode[4]|opcode[3]|opcode[2]|opcode[1]|~opcode[0])}} & ALUop_RE)
		     | ({3{opcode[5]}} & ALUop_LS)
		     | ({3{~opcode[5] & ~opcode[4] & ~opcode[3] & opcode[2]}} & ALUop_b);

	//rf数据
	wire [4:0]  waddr;
	wire [4:0]  raddr1;
	wire [4:0]  raddr2;
	wire        wen;
	wire [31:0] wdata;
	wire [31:0] rdata1;
	wire [31:0] rdata2;

	assign RF_wen = wen;
	assign RF_waddr = waddr;
	assign RF_wdata = wdata;

	assign wen = (opcode==6'b0) ? wen_R : 
	             (opcode==6'b000001) ? 0 :
		     (opcode==6'b000010) ? 0 :
		     (opcode[5:2]==4'b0001)? 0 : 
		     ({opcode[5],opcode[3]}==2'b11) ? 0 : 1;
	assign waddr = (opcode==6'b0) ? rd : 
	               (opcode==6'b000011) ? 5'b11111 : rt;
	assign wdata = ({32{~(opcode[5]|opcode[4]|opcode[3]|opcode[2]|opcode[1]|opcode[0])}} & wdata_R )
	             | ({32{~opcode[5] & ~opcode[4] & opcode[3]}} & wdata_IC)
		     | ({32{~(opcode[5]|opcode[4]|opcode[3]|opcode[2]|~opcode[1]|~opcode[0])}} & wdata_J )
		     | ({32{opcode[5] & ~opcode[3]}} & wdata_L);
        assign raddr1 = rs; 
	assign raddr2 = rt;

	//shifter数据. 只有R-type用
	wire [31:0] A_shifter;
	wire [ 4:0] B_shifter;   
 	wire [ 1:0] Shiftop; 
	wire [31:0] Result_shifter;

//R-type opcode=6'b0
	assign wen_R = (func[5]==1'b1 || func[5:3]== 3'b0) ? 1 :
	               ({func[5:3],func[1]} == 4'b0010 ) ? ((func[0] == 1'b1) ? 1 : 0 ) :
	               ((rdata2==32'b0) && (func[0]==0))  ? 1 :
		       ((rdata2!=32'b0) && (func[0]!=0))  ? 1 : 0;
	
	//assign wdata_R = (func[5]==1'b1) ? Result_alu :
	//                 (func[5:3]==3'b000) ? Result_shifter :
	//		 ({func[5:3],func[1]}==4'b0010) ? (PC + 8) : rdata1;
	assign wdata_R = ({32{func[5]}} & Result_alu)
	               | ({32{~(func[5] | func[4] | func[3])}} & Result_shifter)
		       | ({32{~(func[5] | func[4] | ~func[3] | func[1])}} & (PC + 8))
		       | ({32{~(func[5] | func[4] | ~func[3] | ~func[1])}} & rdata1);
	
	//calculate func[5]=1'b1   addu,subu,and,or,xor,nor,slt,sltu
	
	assign ALUop_R = ({3{~func[3] & ~func[2]}} & {func[1],2'b10})
	               | ({3{~func[3] & func[2]}} & {func[1],1'b0,func[0]})
		       | ({3{func[3] & ~func[2]}} & {~func[0],2'b11});
	assign A_alu_R = rdata1;
	assign B_alu_R = rdata2;           //
	
	//shift func[5:3]=3'b000   sll,sra,srl,sllv,srav,srlv
	assign Shiftop = func[1:0];
	assign A_shifter = rdata2;
	assign B_shifter = func[2] ? rdata1[4:0] : shamt;       //

	//jump {func[5:3],func[1]}=4'b0010   

	//跳转步写在PC里

	//mov {func[5:3],func[1]}=4'b0011   movz,movn      

//I-type 
        //calculate opcode=3'b001
        assign ALUop_I = ({3{~opcode[2] & ~opcode[1]}} & {opcode[1],2'b10})
	               | ({3{opcode[2]}} & {opcode[1],1'b0,opcode[0]})
		       | ({3{~opcode[2] & opcode[1]}} & {~opcode[0],2'b11});
	assign A_alu_I = rdata1;
	assign B_alu_I = (opcode[2:0]==3'b001 || opcode[2:0]==3'b010) ? 
	                 {{16{immediate[15]}},immediate} : {16'b0,immediate};
	assign wdata_IC = (opcode[3]&opcode[2]&opcode[1]&opcode[0])?
	                 {immediate,16'b0} : Result_alu;

//load & write opcode[5]=1
       //load
        assign Address = Result_alu & {{30{1'b1}},2'b0};
	assign MemRead = opcode[5] & (~opcode[3]);
	assign A_alu_LS = rdata1;
	assign B_alu_LS = {{16{immediate[15]}},immediate};
	assign ALUop_LS = 010; //
	//solid address   op10!=10
	assign Read_data_1 = ({32{~opcode[1] & ~opcode[0] & opcode[2]}} & {24'b0,read_b})
	                   | ({32{~opcode[1] & ~opcode[0] & ~opcode[2]}} & {{24{read_b[7]}},read_b})
			   | ({32{~opcode[1] & opcode[0] & opcode[2]}} & {16'b0,read_h[15:0]})
			   | ({32{~opcode[1] & opcode[0] & ~opcode[2]}} & {{16{read_h[15]}},read_h[15:0]})
			   | ({32{opcode[1] & opcode[0]}} & Read_data);
	assign read_b = ({8{~Result_alu[1] & ~Result_alu[0]}} & Read_data[7:0])
	              | ({8{~Result_alu[1] & Result_alu[0]}} & Read_data[15:8])
		      | ({8{Result_alu[1] & ~Result_alu[0]}} & Read_data[23:16])
		      | ({8{Result_alu[1] & Result_alu[0]}} & Read_data[31:24]);
	//assign read_h = (Result_alu[1:0]==2'b00) ? Read_data[15:0] : Read_data[31:16];
	assign read_h = ({16{~Result_alu[1] & ~Result_alu[0]}} & Read_data[15:0])
	              | ({16{Result_alu[1] & ~Result_alu[0]}} & Read_data[31:16]);
	//changed address  op10=10
	assign rsign = {opcode[2],Result_alu[1:0]};
	assign Read_data_2 = ({32{~rsign[2] & ~rsign[1] & ~rsign[0]}} & {Read_data[7:0],rdata2[23:0]})
	                   | ({32{~rsign[2] & ~rsign[1] & rsign[0]}} & {Read_data[15:0],rdata2[15:0]})
			   | ({32{~rsign[2] & rsign[1] & ~rsign[0]}} & {Read_data[23:0],rdata2[7:0]})
			   | (({32{~rsign[2] & rsign[1] & rsign[0]}} | {32{rsign[2] & ~rsign[1] & ~rsign[0]}}) & Read_data)
			   | ({32{rsign[2] & ~rsign[1] & rsign[0]}} & {rdata2[31:24],Read_data[31:8]})
			   | ({32{rsign[2] & rsign[1] & ~rsign[0]}} & {rdata2[31:16],Read_data[31:16]})
			   | ({32{rsign[2] & rsign[1] & rsign[0]}} & {rdata2[31:8],Read_data[31:24]});
	assign wdata_L = (opcode[1:0]==2'b10) ? Read_data_2 : Read_data_1;

        //write opcode[5]=1   Write_strb
	assign MemWrite = opcode[5] & opcode[3];
	assign wsign1 = {Result_alu[1:0],opcode[1:0]};
	assign wtrb1 = ({4{~wsign1[3] & ~wsign1[2] & ~wsign1[1] & ~wsign1[0]}} & 4'b0001)
	             | ({4{~wsign1[3] & wsign1[2] & ~wsign1[1] & ~wsign1[0]}} & 4'b0010)
		     | ({4{wsign1[3] & ~wsign1[2] & ~wsign1[1] & ~wsign1[0]}} & 4'b0100)
		     | ({4{wsign1[3] & wsign1[2] & ~wsign1[1] & ~wsign1[0]}} & 4'b1000)
		     | ({4{~wsign1[3] & ~wsign1[2] & ~wsign1[1] & wsign1[0]}} & 4'b0011)
		     | ({4{wsign1[3] & ~wsign1[2] & ~wsign1[1] & wsign1[0]}} & 4'b1100)
		     | ({4{~wsign1[3] & ~wsign1[2] & wsign1[1] & wsign1[0]}} & 4'b1111);
	assign Write_data_1 = (opcode[1:0]==2'b00) ? write_b:
	                      (opcode[1:0]==2'b01) ? write_h : rdata2;
	assign write_b = (wsign1==4'b0000) ? {24'b0,rdata2[7:0]} :
	               (wsign1==4'b0100) ? {16'b0,rdata2[7:0],8'b0} :
		       (wsign1==4'b1000) ? {8'b0,rdata2[7:0],16'b0} : {rdata2[7:0],24'b0};
	assign write_h = (wsign1==4'b0001) ? {16'b0,rdata2[15:0]} : {rdata2[15:0],16'b0};
	assign wsign2 = {opcode[2],Result_alu[1:0]};
	assign Write_data_2 = ({32{~wsign2[2] & ~wsign2[1] & ~wsign2[0]}} & {24'b0,rdata2[31:24]})
	                    | ({32{~wsign2[2] & ~wsign2[1] & wsign2[0]}} & {16'b0,rdata2[31:16]})
			    | ({32{~wsign2[2] & wsign2[1] & ~wsign2[0]}} & {8'b0,rdata2[31:8]})
			    | (({32{~wsign2[2] & wsign2[1] & wsign2[0]}} | {32{wsign2[2] & ~wsign2[1] & ~wsign2[0]}}) & rdata2)
			    | ({32{wsign2[2] & ~wsign2[1] & wsign2[0]}} & {rdata2[23:0],8'b0})
			    | ({32{wsign2[2] & wsign2[1] & ~wsign2[0]}} & {rdata2[15:0],15'b0})
			    | ({32{wsign2[2] & wsign2[1] & wsign2[0]}} & {rdata2[7:0],24'b0});
	assign wtrb2 = ({4{~wsign2[2] & ~wsign2[1] & ~wsign2[0]}} & 4'b0001)
	             | ({4{~wsign2[2] & ~wsign2[1] & wsign2[0]}} & 4'b0011)
		     | ({4{~wsign2[2] & wsign2[1] & ~wsign2[0]}} & 4'b0111)
		     | (({4{~wsign2[2] & wsign2[1] & wsign2[0]}} | {32{wsign2[2] & ~wsign2[1] & ~wsign2[0]}}) & 4'b1111)
		     | ({4{wsign2[2] & ~wsign2[1] & wsign2[0]}} & 4'b1110)
		     | ({4{wsign2[2] & wsign2[1] & ~wsign2[0]}} & 4'b1100)
		     | ({4{wsign2[2] & wsign2[1] & wsign2[0]}} & 4'b1000);
	assign Write_strb = (opcode[1:0]==2'b10) ? wtrb2 : wtrb1;
	assign Write_data = (opcode[1:0]==2'b10) ? Write_data_2: Write_data_1;

//branch     opcode[5:2]=4'b0001
	assign target_b = {{16{immediate[15]}},immediate}<<2;
	//assign raddr1_RE = rs;
	//assign raddr2_b = rt;
	assign ALUop_b = (opcode[1:0]==2'b00 || opcode[1:0]==2'b01) ? 3'b110 : 3'b111 ;//SLT 
	assign A_alu_b = rdata1;
	assign B_alu_b = (opcode[1:0]==2'b00 || opcode[1:0]==2'b01) ? rdata2 : 32'b0;

//REGIMM  opcode=000001  要用alu吗
        assign target_RE = {{16{immediate[15]}},immediate}<<2;
	//assign raddr1_RE = rs;
	assign ALUop_RE = 111 ;//SLT 
	assign A_alu_RE = rdata1;
	assign B_alu_RE = 0; //   result <:1   >=: 0

//J    opcode[5:1]=5'b00001
        assign target_J = {next[31:28],distance,2'b0}; 
	//assign waddr_J = 5'b1;
	assign wdata_J = PC + 8;

//PC
        assign target = (opcode[5:1] == 5'b00001) ? target_J :
	               (opcode == 6'b0 && {func[5:3],func[1]} == 4'b0010) ? rdata1 :
		       (opcode==6'b000001 && ((rt[0]==0 && Result_alu==1) || (rt[0]==1 && Result_alu==0)) ) ? (target_RE + next) :
		       (opcode[5:2]==4'b0001 && 
		        ((opcode[1:0]==2'b00 && Zero==1) || (opcode[1:0]==2'b01 && Zero==0)  || (opcode[1:0]==2'b10 && (Result_alu==1 || rdata1==32'b0)) || (opcode[1:0]==2'b11 && (Result_alu==0 || rdata1!=32'b0)))) ? (target_b + next) :
		       next;
	always@(posedge clk)begin
		if(rst == 1)begin  //high is effective!
                        PC <= 0;
		end 
		else begin
			PC <= target;
		end
	end

	//alu实例化
	alu R_alu(
		.A        (A_alu),
		.B        (B_alu),
		.ALUop    (ALUop),
		.Overflow (Overflow),
		.CarryOut (CarryOut),
		.Zero     (Zero),
		.Result   (Result_alu)
	);

	//rf实例化
	reg_file R_reg_file(
		.waddr    (waddr),
		.raddr1   (raddr1),
		.raddr2   (raddr2),
		.wen      (wen),
		.wdata    (wdata),
		.rdata1   (rdata1),
		.rdata2   (rdata2),
		.clk      (clk)
	);

	//shifter实例化
	shifter R_shifter(
		.A        (A_shifter),
		.B        (B_shifter),
		.Shiftop  (Shiftop),
		.Result   (Result_shifter)
	);
endmodule
