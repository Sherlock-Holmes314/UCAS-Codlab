`timescale 10ns / 1ns

`define CACHE_SET	8
`define CACHE_WAY	4
`define TAG_LEN		24
`define LINE_LEN	256

module dcache_top (
	input	      clk,
	input	      rst,
  
	//CPU interface
	/** CPU memory/IO access request to Cache: valid signal */
	input         from_cpu_mem_req_valid,
	/** CPU memory/IO access request to Cache: 0 for read; 1 for write (when req_valid is high) */
	input         from_cpu_mem_req,
	/** CPU memory/IO access request to Cache: address (4 byte alignment) */
	input  [31:0] from_cpu_mem_req_addr,
	/** CPU memory/IO access request to Cache: 32-bit write data */
	input  [31:0] from_cpu_mem_req_wdata,
	/** CPU memory/IO access request to Cache: 4-bit write strobe */
	input  [ 3:0] from_cpu_mem_req_wstrb,
	/** Acknowledgement from Cache: ready to receive CPU memory access request */
	output        to_cpu_mem_req_ready,
		
	/** Cache responses to CPU: valid signal */
	output        to_cpu_cache_rsp_valid,
	/** Cache responses to CPU: 32-bit read data */
	output [31:0] to_cpu_cache_rsp_data,
	/** Acknowledgement from CPU: Ready to receive read data */
	input         from_cpu_cache_rsp_ready,
		
	//Memory/IO read interface
	/** Cache sending memory/IO read request: valid signal */
	output        to_mem_rd_req_valid,
	/** Cache sending memory read request: address
	  * 4 byte alignment for I/O read 
	  * 32 byte alignment for cache read miss */
	output [31:0] to_mem_rd_req_addr,
        /** Cache sending memory read request: burst length
	  * 0 for I/O read (read only one data beat)
	  * 7 for cache read miss (read eight data beats) */
	output [ 7:0] to_mem_rd_req_len,
        /** Acknowledgement from memory: ready to receive memory read request */
	input	      from_mem_rd_req_ready,

	/** Memory return read data: valid signal of one data beat */
	input	      from_mem_rd_rsp_valid,
	/** Memory return read data: 32-bit one data beat */
	input  [31:0] from_mem_rd_rsp_data,
	/** Memory return read data: if current data beat is the last in this burst data transmission */
	input	      from_mem_rd_rsp_last,
	/** Acknowledgement from cache: ready to receive current data beat */
	output        to_mem_rd_rsp_ready,

	//Memory/IO write interface
	/** Cache sending memory/IO write request: valid signal */
	output        to_mem_wr_req_valid,
	/** Cache sending memory write request: address
	  * 4 byte alignment for I/O write 
	  * 4 byte alignment for cache write miss
          * 32 byte alignment for cache write-back */
	output [31:0] to_mem_wr_req_addr,
        /** Cache sending memory write request: burst length
          * 0 for I/O write (write only one data beat)
          * 0 for cache write miss (write only one data beat)
          * 7 for cache write-back (write eight data beats) */
	output [ 7:0] to_mem_wr_req_len,
        /** Acknowledgement from memory: ready to receive memory write request */
	input         from_mem_wr_req_ready,

	/** Cache sending memory/IO write data: valid signal for current data beat */
	output        to_mem_wr_data_valid,
	/** Cache sending memory/IO write data: current data beat */
	output [31:0] to_mem_wr_data,
	/** Cache sending memory/IO write data: write strobe
	  * 4'b1111 for cache write-back 
	  * other values for I/O write and cache write miss according to the original CPU request*/ 
	output [ 3:0] to_mem_wr_data_strb,
	/** Cache sending memory/IO write data: if current data beat is the last in this burst data transmission */
	output        to_mem_wr_data_last,
	/** Acknowledgement from memory/IO: ready to receive current data beat */
	input	      from_mem_wr_data_ready
);

  //TODO: Please add your D-Cache code here

  // 状态机定义
    wire [2:0] index;           // 组索引
    wire [23:0] tag;            // 标签
    wire [4:0] offset;          // bit偏移量
    wire ReadHit;
    reg  ReadHit_reg;
    wire DirtyEvict;
    reg  DirtyEvict_reg;
    wire [255:0] ReadData;
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
    wire         wdata_dirty;
    wire         rdata_dirty1;
    reg          wen_dirty1;
    wire         rdata_dirty2;
    reg          wen_dirty2;
    wire         rdata_dirty3;
    reg          wen_dirty3;
    wire         rdata_dirty4;
    reg          wen_dirty4;


    localparam BP_WR_REQ = 17'b00000000000000001;          //0001    0
    localparam BP_WR     = 17'b00000000000000010;          //0002    1
    localparam BP_RD     = 17'b00000000000000100;          //0004    2 
    localparam BP_RECV   = 17'b00000000000001000;          //0008    3
    localparam WAIT      = 17'b00000000000010000;          //0010    4
    localparam TAG_RD    = 17'b00000000000100000;          //0020    5
    localparam EVICT     = 17'b00000000001000000;          //0040    6
    localparam MEM_RD    = 17'b00000000010000000;          //0080    7
    localparam RECV      = 17'b00000000100000000;          //0100    8
    localparam REFILL    = 17'b00000001000000000;          //0200    9
    localparam RESP      = 17'b00000010000000000;          //0400    10
    localparam CACHE_RD  = 17'b00000100000000000;          //0800    11
    localparam TAG_WR    = 17'b00001000000000000;          //1000    12
    localparam CACHE_WR  = 17'b00010000000000000;          //2000    13
    localparam EVICT_WR_REQ  = 17'b00100000000000000;      //4000    14
    localparam EVICT_WR  = 17'b01000000000000000;          //8000    15
    localparam INIT      = 17'b10000000000000000;   

    reg [16:0] current_state;
    reg [16:0] next_state;

    // 地址解析
    reg [31:0]Address;
    wire [31:0]Address_evict;
    reg [1:0] counter;
    always @ (posedge clk)begin
        if(rst)
            counter <= 0;
        else if(((current_state == TAG_WR) || (current_state == TAG_RD)) && (ReadHit == 1'b0))
            counter <= counter + 1; //可以这么写吗
        else 
            counter <= counter;
    end

    always @(posedge clk)begin
	if(rst)
                Address <= 32'b0;
        else if((from_cpu_mem_req_valid & to_cpu_mem_req_ready) == 1'b1)
                Address <= from_cpu_mem_req_addr;
        else
                Address <= Address;
    end

    assign Address_evict = ({32{(~counter[1] & ~counter[0])}} & {rdata_tag1,index,5'b0}) | 
                        ({32{(~counter[1] &  counter[0])}} & {rdata_tag2,index,5'b0}) |
			({32{( counter[1] & ~counter[0])}} & {rdata_tag3,index,5'b0}) |
			({32{( counter[1] &  counter[0])}} & {rdata_tag4,index,5'b0}) ;
    assign index = Address[7:5];
    assign tag = Address[31:8];
    assign offset = Address[4:0];
    
    wire [255:0] Write_data_evict;
    assign Write_data_evict = ({256{(~counter[1] & ~counter[0])}} & rdata_data1) | 
                        ({256{(~counter[1] &  counter[0])}} & rdata_data2) |
			({256{( counter[1] & ~counter[0])}} & rdata_data3) |
			({256{( counter[1] &  counter[0])}} & rdata_data4) ;
    reg [31:0] Write_data;
    always @(posedge clk)begin
	if(rst)
	        Write_data <= 32'b0;
	else if((from_cpu_mem_req_valid & to_cpu_mem_req_ready & from_cpu_mem_req) == 1'b1)
	        Write_data <= from_cpu_mem_req_wdata;
    end
    reg [3:0] Write_strb;
    always @(posedge clk)begin
	if(rst)
	        Write_strb <= 4'b0;
	else if((from_cpu_mem_req_valid & to_cpu_mem_req_ready & from_cpu_mem_req) == 1'b1)
	        Write_strb <= from_cpu_mem_req_wstrb;
    end
    reg wrmode;
    always@(posedge clk)begin
        if(rst)
                wrmode <= 1'b0;
	else if((current_state == TAG_WR) || (current_state == BP_WR_REQ))
	        wrmode <= 1'b1;
	else if((current_state == TAG_RD) || (current_state == BP_RD))
	        wrmode <= 1'b0;
	else
	        wrmode <= wrmode;
    end

    reg passby;
    wire needbypass;
    assign needbypass = ((from_cpu_mem_req_addr[31:30] != 2'b0) || (from_cpu_mem_req_addr[31:5] == 27'b0)) ? 1:0;
    always@(posedge clk)begin
        if(rst)
                passby <= 1'b0;
	else if((current_state == BP_WR_REQ) || (current_state == BP_RD))
	        passby <= 1'b1;
	else if((current_state == TAG_RD) || (current_state == TAG_WR))
	        passby <= 1'b0;
	else
	        passby <= passby;
    end


    //状态机第一段
    
    always@(posedge clk)begin
	if(rst)
	    current_state <= INIT;
	else
	    current_state <= next_state;
    end

    //状态机第二段

    always@(*)begin
        case(current_state)
            INIT:next_state = WAIT;
            WAIT:begin
		if((from_cpu_mem_req_valid & to_cpu_mem_req_ready) == 1'b1)begin
			if((from_cpu_mem_req_addr[31:30] == 2'b0) && (from_cpu_mem_req_addr[31:5] != 27'b0))begin
				if(from_cpu_mem_req == 1'b1)
				        next_state = TAG_WR;
				else
				        next_state = TAG_RD;
			end
			else begin
				if(from_cpu_mem_req == 1'b1)
				        next_state = BP_WR_REQ;
				else
				        next_state = BP_RD;
			end
		end
		else
		        next_state = WAIT;
            end
            TAG_RD:begin
                if(ReadHit == 1'b1)
                        next_state = CACHE_RD;
                else 
                        next_state = EVICT;
            end
            EVICT:begin
		if(DirtyEvict == 1'b1)
		        next_state = EVICT_WR_REQ;
		else
		        next_state = MEM_RD;
	    end
            MEM_RD:begin
                if((from_mem_rd_req_ready & to_mem_rd_req_valid) == 1'b1) 
                        next_state = RECV;
                else
                        next_state = MEM_RD;
            end
            RECV:begin
                if((from_mem_rd_rsp_valid & from_mem_rd_rsp_last & to_mem_rd_rsp_ready) == 1'b1)
                        next_state = REFILL;
                else
                        next_state = RECV;
            end
            REFILL:begin
		if(wrmode == 1'b0)
		        next_state = RESP;
		else 
		        next_state = CACHE_WR;
	    end
            RESP:begin
                if((from_cpu_cache_rsp_ready & to_cpu_cache_rsp_valid) == 1'b1)
                        next_state = WAIT;
                else
                        next_state = RESP;
            end
            CACHE_RD:next_state = RESP;
	    TAG_WR:begin
		if(ReadHit == 1'b1)
		        next_state = CACHE_WR;
		else
		        next_state = EVICT;
	    end
	    EVICT_WR_REQ:begin
		if((from_mem_wr_req_ready & to_mem_wr_req_valid) == 1'b1)
		        next_state = EVICT_WR;
		else
		        next_state = EVICT_WR_REQ;
	    end
	    EVICT_WR:begin
		if((from_mem_wr_data_ready & to_mem_wr_data_last & to_mem_wr_data_valid) == 1'b1)
		        next_state = MEM_RD;
		else
		        next_state =EVICT_WR;
	    end
	    CACHE_WR:next_state = WAIT;
            BP_WR_REQ:begin
		if((from_mem_wr_req_ready & to_mem_wr_req_valid) == 1'b1)
		        next_state = BP_WR;
		else
		        next_state = BP_WR_REQ;
	    end
	    BP_WR:begin
	        if((from_mem_wr_data_ready & to_mem_wr_data_last & to_mem_wr_data_valid) == 1'b1)
	                next_state = WAIT;
		else
		        next_state = BP_WR;
            end
	    BP_RD:begin
		if((from_mem_rd_req_ready & to_mem_rd_req_valid) == 1'b1)
		        next_state = BP_RECV;
		else
		        next_state = BP_RD;
	    end
	    BP_RECV:begin
		if((from_mem_rd_rsp_valid & from_mem_rd_rsp_last & to_mem_rd_rsp_ready) == 1'b1)
		        next_state = RESP;
		else
		        next_state = BP_RECV;
	    end
            default:next_state = INIT;
        endcase
    end

    //状态机第三段
    assign to_cpu_mem_req_ready = current_state[4] | rst ;
    assign to_cpu_cache_rsp_valid = current_state[10];
    assign to_mem_rd_req_valid = current_state[7] | current_state[2];
    assign to_mem_rd_rsp_ready = current_state[8] | current_state[3] | rst;
    assign to_mem_rd_req_addr = (from_cpu_mem_req_addr & {32{current_state[2]}}) | ({Address[31:5],5'b0} & {32{current_state[7]}});
    assign to_mem_rd_req_len = ({8{~needbypass}} & {5'b0,3'b111}) | ({8{needbypass}} & 8'b0);
    assign to_cpu_cache_rsp_data = ({32{to_cpu_cache_rsp_valid & ~passby}} & (
                                   ({32{~offset[4] & ~offset[3] & ~offset[2]}} & ReadData[31:0])    | 
                                   ({32{~offset[4] & ~offset[3] &  offset[2]}} & ReadData[63:32])   |
                                   ({32{~offset[4] &  offset[3] & ~offset[2]}} & ReadData[95:64])   |
                                   ({32{~offset[4] &  offset[3] &  offset[2]}} & ReadData[127:96])  |
                                   ({32{ offset[4] & ~offset[3] & ~offset[2]}} & ReadData[159:128]) |
                                   ({32{ offset[4] & ~offset[3] &  offset[2]}} & ReadData[191:160]) |
                                   ({32{ offset[4] &  offset[3] & ~offset[2]}} & ReadData[223:192]) |
                                   ({32{ offset[4] &  offset[3] &  offset[2]}} & ReadData[255:224]) 
				   ) ) | ({32{to_cpu_cache_rsp_valid & passby}} & reg_data[31:0]);
    assign ReadData = ({256{ReadHit_reg}} & data_hit) | ({256{~ReadHit_reg}} & data_unhit); 
    assign to_mem_wr_req_addr = ({32{passby | needbypass}} & from_cpu_mem_req_addr) | ({32{~(passby | needbypass)}} & Address_evict);
    assign to_mem_wr_req_valid = current_state[0] | current_state[14];
    assign to_mem_wr_req_len = ({8{(~needbypass)}} & {5'b0,3'b111}) | ({8{(needbypass)}} & 8'b0);
    assign to_mem_wr_data_valid = current_state[1] | current_state[15];
    
    wire [255:0] Write_data_real;
    assign Write_data_real = ({256{ passby | needbypass}} & {224'b0,from_cpu_mem_req_wdata}) | ({256{~(passby | needbypass)}} & Write_data_evict);
    reg [31:0] Write_data_reg;

    reg [3:0] len_w;
    always@(posedge clk)begin
	if(rst)begin
	        Write_data_reg <= 32'b0;
		len_w <= 4'b0;
	end
	else if(current_state == EVICT_WR)begin
		if(from_mem_wr_data_ready ==1'b1)begin
			len_w <= len_w + 1;
			if(len_w == 4'b0001)
			        Write_data_reg <= Write_data_real[63:32];
			else if(len_w == 4'b0010)
			        Write_data_reg <= Write_data_real[95:64];
			else if(len_w == 4'b0011)
			        Write_data_reg <= Write_data_real[127:96];
			else if(len_w == 4'b0100)
			        Write_data_reg <= Write_data_real[159:128];
			else if(len_w == 4'b0101)
			        Write_data_reg <= Write_data_real[191:160];
			else if(len_w == 4'b0110)
			        Write_data_reg <= Write_data_real[223:192];
			else if(len_w == 4'b0111)
			        Write_data_reg <= Write_data_real[255:224];
                        else
                                Write_data_reg <= Write_data_reg;
		end 
	end
	else begin
	        len_w <= 4'b0001;
                Write_data_reg <= Write_data_real[31:0];
        end
    end

    assign to_mem_wr_data = Write_data_reg;
    assign to_mem_wr_data_last = (passby & current_state[1]) | (~passby & (len_w[3]) & current_state[15]);
    assign to_mem_wr_data_strb = ({4{passby | needbypass}} & from_cpu_mem_req_wstrb) | ({4{~(passby | needbypass)}} & 4'b1111);

    //命中;dirty check
    wire [3:0] choser;
    assign choser[0] = ((valid1 == 1'b1) && (rdata_tag1 == tag)) ? 1'b1 : 1'b0;
    assign choser[1] = ((valid2 == 1'b1) && (rdata_tag2 == tag)) ? 1'b1 : 1'b0;
    assign choser[2] = ((valid3 == 1'b1) && (rdata_tag3 == tag)) ? 1'b1 : 1'b0;
    assign choser[3] = ((valid4 == 1'b1) && (rdata_tag4 == tag)) ? 1'b1 : 1'b0;
    assign ReadHit = choser[3] | choser[2] | choser[1] | choser[0] ;
    assign DirtyEvict = ((~counter[1] & ~counter[0] & rdata_dirty1) | 
                        (~counter[1] &  counter[0] & rdata_dirty2) |
			( counter[1] & ~counter[0] & rdata_dirty3) |
			( counter[1] &  counter[0] & rdata_dirty4)) & (~ReadHit);
    always@(posedge clk)begin
        if(rst)
            ReadHit_reg <= 0;
        else if((current_state == TAG_RD) || (current_state == TAG_WR))
            ReadHit_reg <= ReadHit;
        else
            ReadHit_reg <= ReadHit_reg;
    end
    always@(posedge clk)begin
        if(rst)
            DirtyEvict_reg <= 0;
        else if((current_state == TAG_RD) || (current_state == TAG_WR))
            DirtyEvict_reg <= DirtyEvict;
        else
            DirtyEvict_reg <= DirtyEvict_reg;
    end
    assign data_hit = ({256{choser[3]}} & rdata_data4) | ({256{choser[2]}} & rdata_data3) | ({256{choser[1]}} & rdata_data2) | ({256{choser[0]}} & rdata_data1);

    //未命中    写法规范？？？
    always @ (posedge clk)begin
        if(rst)begin
            wen1 <= 1'b0;
            wen2 <= 1'b0;
            wen3 <= 1'b0;
            wen4 <= 1'b0;
            wen_dirty1 <= 1'b0;
            wen_dirty2 <= 1'b0;
            wen_dirty3 <= 1'b0;
            wen_dirty4 <= 1'b0;
        end
        else if( (current_state == REFILL) && (wrmode == 1'b1) )begin  //别的写法？？？
                if(counter == 2'b00)begin
                        wen1 <= 1'b1;
                        wen_dirty1 <= 1'b1;
                end
                else if(counter == 2'b01)begin
                        wen2 <= 1'b1;
                        wen_dirty2 <= 1'b1;
                end
                else if(counter == 2'b10)begin
                        wen3 <= 1'b1;
                        wen_dirty3 <= 1'b1;
                end
                else begin
                        wen4 <= 1'b1;
                        wen_dirty4 <= 1'b1;
                end
    	end else if( ((current_state == RECV) && ((from_mem_rd_rsp_valid & from_mem_rd_rsp_last) == 1'b1)) )begin
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
        end else if((current_state == TAG_WR) && (ReadHit == 1'b1) )begin
                        if(choser[0] == 1'b1)begin
                                wen1 <= 1'b1;
                                wen_dirty1 <= 1'b1;
                        end
                        else if(choser[1] == 1'b1)begin
                                wen2 <= 1'b1;
                                wen_dirty2 <= 1'b1;
                        end
                        else if(choser[2] == 1'b1)begin
                                wen3 <= 1'b1;
                                wen_dirty3 <= 1'b1;
                        end
                        else begin
                                wen4 <= 1'b1;
                                wen_dirty4 <= 1'b1;
                        end
        end
	else begin
                wen1 <= 1'b0;
                wen2 <= 1'b0;
                wen3 <= 1'b0;
                wen4 <= 1'b0;
                wen_dirty1 <= 1'b0;
                wen_dirty2 <= 1'b0;
                wen_dirty3 <= 1'b0;
                wen_dirty4 <= 1'b0;
        end
    end

    reg [255:0] reg_data;
    reg [3:0]   len; 
    always @ (posedge clk)begin
        if(rst)begin
            len <= 0;
            reg_data <= 256'b0;
        end
        if((current_state == RECV) || (current_state == BP_RECV))begin
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

    wire [255:0] Write_data_cache;
    wire [31:0] Write_data_cache_byte;
    wire [31:0] Write_data_cache_bit;
    assign Write_data_cache_byte = (({32{~offset[4] & ~offset[3] & ~offset[2]}} & ReadData[31:0])    | 
                         ({32{~offset[4] & ~offset[3] &  offset[2]}} & ReadData[63:32])   |
                         ({32{~offset[4] &  offset[3] & ~offset[2]}} & ReadData[95:64])   |
                         ({32{~offset[4] &  offset[3] &  offset[2]}} & ReadData[127:96])  |
                         ({32{ offset[4] & ~offset[3] & ~offset[2]}} & ReadData[159:128]) |
                         ({32{ offset[4] & ~offset[3] &  offset[2]}} & ReadData[191:160]) |
                         ({32{ offset[4] &  offset[3] & ~offset[2]}} & ReadData[223:192]) |
                         ({32{ offset[4] &  offset[3] &  offset[2]}} & ReadData[255:224]) 
   		        );
    assign Write_data_cache_bit[7:0] = ({8{Write_strb[0]}} & Write_data[7:0]) | ({8{~Write_strb[0]}} & Write_data_cache_byte[7:0]);  
    assign Write_data_cache_bit[15:8] = ({8{Write_strb[1]}} & Write_data[15:8]) | ({8{~Write_strb[1]}} & Write_data_cache_byte[15:8]);  
    assign Write_data_cache_bit[23:16] = ({8{Write_strb[2]}} & Write_data[23:16]) | ({8{~Write_strb[2]}} & Write_data_cache_byte[23:16]);  
    assign Write_data_cache_bit[31:24] = ({8{Write_strb[3]}} & Write_data[31:24]) | ({8{~Write_strb[3]}} & Write_data_cache_byte[31:24]);  
    assign Write_data_cache = (({256{~offset[4] & ~offset[3] & ~offset[2]}} & {ReadData[255:32],Write_data_cache_bit[31:0]}) | 
                         ({256{~offset[4] & ~offset[3] &  offset[2]}} & {ReadData[255:64],Write_data_cache_bit,ReadData[31:0]})   |
                         ({256{~offset[4] &  offset[3] & ~offset[2]}} & {ReadData[255:96],Write_data_cache_bit,ReadData[63:0]})   |
                         ({256{~offset[4] &  offset[3] &  offset[2]}} & {ReadData[255:128],Write_data_cache_bit,ReadData[95:0]})  |
                         ({256{ offset[4] & ~offset[3] & ~offset[2]}} & {ReadData[255:160],Write_data_cache_bit,ReadData[127:0]}) |
                         ({256{ offset[4] & ~offset[3] &  offset[2]}} & {ReadData[255:192],Write_data_cache_bit,ReadData[159:0]}) |
                         ({256{ offset[4] &  offset[3] & ~offset[2]}} & {ReadData[255:224],Write_data_cache_bit,ReadData[191:0]}) |
                         ({256{ offset[4] &  offset[3] &  offset[2]}} & {Write_data_cache_bit,ReadData[223:0]})
   		        );
    assign wdata_data = ({256{current_state[9]}} & reg_data) | ({256{current_state[13]}} & Write_data_cache);
    assign wdata_tag = Address[31:8];
    assign wdata_dirty = 1'b1;
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
dirty_array dirty_array1(
    .clk    (clk),
    .rst    (rst),
    .wen    (wen_dirty1),
    .waddr  (index),
    .wdata  (wdata_dirty),
    .raddr  (index),
    .rdata  (rdata_dirty1)
);
dirty_array dirty_array2(
    .clk    (clk),
    .rst    (rst),
    .wen    (wen_dirty2),
    .waddr  (index),
    .wdata  (wdata_dirty),
    .raddr  (index),
    .rdata  (rdata_dirty2)
);
dirty_array dirty_array3(
    .clk    (clk),
    .rst    (rst),
    .wen    (wen_dirty3),
    .waddr  (index),
    .wdata  (wdata_dirty),
    .raddr  (index),
    .rdata  (rdata_dirty3)
);
dirty_array dirty_array4(
    .clk    (clk),
    .rst    (rst),
    .wen    (wen_dirty4),
    .waddr  (index),
    .wdata  (wdata_dirty),
    .raddr  (index),
    .rdata  (rdata_dirty4)
);

endmodule


