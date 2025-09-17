`timescale 10ns / 1ns

`define CACHE_SET	8
`define CACHE_WAY	4
`define TAG_LEN		24
`define LINE_LEN	256


//8.5hour
module icache_top (
	input	      clk,
	input	      rst,
	
	//CPU interface
	/** CPU instruction fetch request to Cache: valid signal */
	input         from_cpu_inst_req_valid,
	/** CPU instruction fetch request to Cache: address (4 byte alignment) */
	input  [31:0] from_cpu_inst_req_addr,
	/** Acknowledgement from Cache: ready to receive CPU instruction fetch request */
	output        to_cpu_inst_req_ready,
	
	/** Cache responses to CPU: valid signal */
	output        to_cpu_cache_rsp_valid,
	/** Cache responses to CPU: 32-bit Instruction value */
	output [31:0] to_cpu_cache_rsp_data,
	/** Acknowledgement from CPU: Ready to receive Instruction */
	input	      from_cpu_cache_rsp_ready,

	//Memory interface (32 byte aligned address)
	/** Cache sending memory read request: valid signal */
	output        to_mem_rd_req_valid,
	/** Cache sending memory read request: address (32 byte alignment) */
	output [31:0] to_mem_rd_req_addr,
	/** Acknowledgement from memory: ready to receive memory read request */
	input         from_mem_rd_req_ready,

	/** Memory return read data: valid signal of one data beat */
	input         from_mem_rd_rsp_valid,
	/** Memory return read data: 32-bit one data beat */
	input  [31:0] from_mem_rd_rsp_data,
	/** Memory return read data: if current data beat is the last in this burst data transmission */
	input         from_mem_rd_rsp_last,
	/** Acknowledgement from cache: ready to receive current data beat */
	output        to_mem_rd_rsp_ready
);

//TODO: Please add your I-Cache code here
// 地址划分
    wire [2:0] index;           // 组索引
    wire [23:0] tag;            // 标签
    wire [4:0] offset;          // bit偏移量
    wire ReadHit;
    wire [255:0] ReadData;
    reg ReadHit_reg;
    wire [255:0] data_unhit;
    wire [255:0] data_hit;
    
    wire [255:0] wdata_data;
    wire [23:0]  wdata_tag;
    wire [255:0] rdata_data1;
    wire [23:0]  rdata_tag1;
    reg          wen1;
    wire         valid1;
    wire [255:0] rdata_data2;
    wire [23:0]  rdata_tag2;
    reg          wen2;
    wire         valid2;
    wire [255:0] rdata_data3;
    wire [23:0]  rdata_tag3;
    reg          wen3;
    wire         valid3;
    wire [255:0] rdata_data4;
    wire [23:0]  rdata_tag4;
    reg          wen4;
    wire         valid4;

    // 地址解析
    reg [31:0]Address;
        always @(posedge clk)
        begin
            if(rst)
                Address <= 32'b0;
            else if(from_cpu_inst_req_valid & to_cpu_inst_req_ready)
                Address <= from_cpu_inst_req_addr;
            else
                Address <= Address;
        end
    assign index = Address[7:5];
    assign tag = Address[31:8];
    assign offset = Address[4:0];
    
    // 状态机定义
    localparam WAIT     = 8'b00000001;   //01
    localparam TAG_RD   = 8'b00000010;   //02
    localparam EVICT    = 8'b00000100;   //04
    localparam MEM_RD   = 8'b00001000;   //08
    localparam RECV     = 8'b00010000;   //10
    localparam REFILL   = 8'b00100000;   //20
    localparam RESP     = 8'b01000000;   //40
    localparam CACHE_RD = 8'b10000000;   //80
    

    reg [7:0] current_state;
    reg [7:0] next_state;
    //状态机第一段
    always@(posedge clk)begin
        if(rst == 1'b1)
            current_state <= WAIT;
        else
            current_state <= next_state;
    end

    // 状态机第二段
    always@(*)begin
        case(current_state)
            WAIT:begin
                if(from_cpu_inst_req_valid & to_cpu_inst_req_ready)  //置为同步信号
                    next_state = TAG_RD;
                else
                    next_state = WAIT;
            end
            TAG_RD:begin
                if(ReadHit)
                    next_state = CACHE_RD;
                else
                    next_state = EVICT;
            end
            EVICT:  next_state = MEM_RD;
            MEM_RD:begin
                if(from_mem_rd_req_ready)
                    next_state = RECV;
                else
                    next_state = MEM_RD;
            end
            RECV:begin
                if(from_mem_rd_rsp_valid & from_mem_rd_rsp_last)
                    next_state = REFILL;
                else
                    next_state = RECV;
            end
            REFILL: next_state = RESP;
            RESP:begin
                if(from_cpu_cache_rsp_ready)
                    next_state = WAIT;
                else
                    next_state = RESP;
            end
            CACHE_RD:next_state = RESP;
            default:next_state = WAIT;
        endcase
    end

    //状态机第三段
    assign to_cpu_inst_req_ready = current_state[0] & (~rst); //rst条件有必要吗--拉低
    assign to_cpu_cache_rsp_valid = current_state[6];
    assign to_mem_rd_req_valid = current_state[3];
    assign to_mem_rd_rsp_ready = current_state[4];
    assign to_mem_rd_req_addr = {Address[31:5],5'b0};
    assign to_cpu_cache_rsp_data = {32{to_cpu_cache_rsp_valid}} & (
                                   ({32{~offset[4] & ~offset[3] & ~offset[2]}} & ReadData[31:0])    | 
                                   ({32{~offset[4] & ~offset[3] &  offset[2]}} & ReadData[63:32])   |
                                   ({32{~offset[4] &  offset[3] & ~offset[2]}} & ReadData[95:64])   |
                                   ({32{~offset[4] &  offset[3] &  offset[2]}} & ReadData[127:96])  |
                                   ({32{ offset[4] & ~offset[3] & ~offset[2]}} & ReadData[159:128]) |
                                   ({32{ offset[4] & ~offset[3] &  offset[2]}} & ReadData[191:160]) |
                                   ({32{ offset[4] &  offset[3] & ~offset[2]}} & ReadData[223:192]) |
                                   ({32{ offset[4] &  offset[3] &  offset[2]}} & ReadData[255:224]) ) ;
    assign ReadData = ({256{ReadHit_reg}} & data_hit) | ({256{~ReadHit_reg}} & data_unhit); 

    //命中
    wire [3:0] choser;
    assign choser[0] = ((valid1 == 1'b1) && (rdata_tag1 == tag)) ? 1'b1 : 1'b0;
    assign choser[1] = ((valid2 == 1'b1) && (rdata_tag2 == tag)) ? 1'b1 : 1'b0;
    assign choser[2] = ((valid3 == 1'b1) && (rdata_tag3 == tag)) ? 1'b1 : 1'b0;
    assign choser[3] = ((valid4 == 1'b1) && (rdata_tag4 == tag)) ? 1'b1 : 1'b0;
    assign ReadHit = choser[3] | choser[2] | choser[1] | choser[0] ;
    always@(posedge clk)begin
        if(rst)
            ReadHit_reg <= 0;
        else if(current_state == TAG_RD)
            ReadHit_reg <= ReadHit;
        else
            ReadHit_reg <= ReadHit_reg;
    end
    assign data_hit = ({256{choser[3]}} & rdata_data4) | ({256{choser[2]}} & rdata_data3) | ({256{choser[1]}} & rdata_data2) | ({256{choser[0]}} & rdata_data1);

    //未命中    写法规范？？？
    reg [1:0] counter;
    always @ (posedge clk)begin
        if(rst)begin
            wen1 <= 1'b0;
            wen2 <= 1'b0;
            wen3 <= 1'b0;
            wen4 <= 1'b0;
        end
        if((current_state == RECV) && ((from_mem_rd_rsp_valid & from_mem_rd_rsp_last) == 1'b1))begin  //别的写法？？？
            if(counter == 2'b00)begin
                wen1 <= 1'b1;
            end
            else if(counter == 2'b01)begin
                wen2 <= 1'b1;
            end
            else if(counter == 2'b10)begin
                wen3 <= 1'b1;
            end
            else begin
                wen4 <= 1'b1;
            end
        end else begin
            wen1 <= 1'b0;
            wen2 <= 1'b0;
            wen3 <= 1'b0;
            wen4 <= 1'b0;
        end
    end
    always @ (posedge clk)begin
        if(rst)
            counter <= 0;
        else if(current_state == EVICT)
            counter <= counter + 1; //可以这么写吗
        else 
            counter <= counter;
    end

    reg [255:0] reg_data;
    reg [3:0]   len; 
    always @ (posedge clk)begin
        if(rst)begin
            len <= 0;
            reg_data <= 256'b0;
        end
        if(current_state == RECV)begin
            if(from_mem_rd_rsp_valid)begin
                len <= len + 1;
                if(len == 4'b0000)
                    reg_data[31:0] <= from_mem_rd_rsp_data;
                else if(len == 4'b0001)
                    reg_data[63:32] <= from_mem_rd_rsp_data;
                else if(len == 4'b0010)
                    reg_data[95:64] <= from_mem_rd_rsp_data;
                else if(len == 4'b0011)
                    reg_data[127:96] <= from_mem_rd_rsp_data;
                else if(len == 4'b0100)
                    reg_data[159:128] <= from_mem_rd_rsp_data;
                else if(len == 4'b0101)
                    reg_data[191:160] <= from_mem_rd_rsp_data;
                else if(len == 4'b0110)
                    reg_data[223:192] <= from_mem_rd_rsp_data;
                else 
                    reg_data[255:224] <= from_mem_rd_rsp_data;
            end
            else 
                len <= len;
        end else
            len <= 4'b0;
    end

    assign wdata_data = reg_data;
    assign wdata_tag = Address[31:8];
    assign data_unhit = reg_data;

data_array data_array1(
    .clk    (clk),
    .wen    (wen1),
    .waddr  (index),
    .wdata  (wdata_data),
    .raddr  (index),
    .rdata  (rdata_data1)
);
data_array data_array2(
    .clk    (clk),
    .wen    (wen2),
    .waddr  (index),
    .wdata  (wdata_data),
    .raddr  (index),
    .rdata  (rdata_data2)
);
data_array data_array3(
    .clk    (clk),
    .wen    (wen3),
    .waddr  (index),
    .wdata  (wdata_data),
    .raddr  (index),
    .rdata  (rdata_data3)
);
data_array data_array4(
    .clk    (clk),
    .wen    (wen4),
    .waddr  (index),
    .wdata  (wdata_data),
    .raddr  (index),
    .rdata  (rdata_data4)
);

tag_array tag_array1(
    .clk    (clk),
    .rst    (rst),
    .wen    (wen1),
    .waddr  (index),
    .wdata  (wdata_tag),
    .raddr  (index),
    .rdata  (rdata_tag1),
    .valid  (valid1)
);
tag_array tag_array2(
    .clk    (clk),
    .rst    (rst),
    .wen    (wen2),
    .waddr  (index),
    .wdata  (wdata_tag),
    .raddr  (index),
    .rdata  (rdata_tag2),
    .valid  (valid2)
);
tag_array tag_array3(
    .clk    (clk),
    .rst    (rst),
    .wen    (wen3),
    .waddr  (index),
    .wdata  (wdata_tag),
    .raddr  (index),
    .rdata  (rdata_tag3),
    .valid  (valid3)
);
tag_array tag_array4(
    .clk    (clk),
    .rst    (rst),
    .wen    (wen4),
    .waddr  (index),
    .wdata  (wdata_tag),
    .raddr  (index),
    .rdata  (rdata_tag4),
    .valid  (valid4)
);

endmodule

