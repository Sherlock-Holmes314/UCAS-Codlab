`timescale 10 ns / 1 ns

module dirty_array(
        input        clk,
        input        rst,
        input  [2:0] waddr,
        input        wdata,
        input        wen,
        input  [2:0] raddr,
        output       rdata 
);


        reg    [7:0] dirty_array;

        always @(posedge clk)begin
                if(rst)begin
                        dirty_array <= 8'b0;
                end
                else begin
                        if(wen)begin
                                dirty_array[waddr] <= wdata;
                        end
                end
        end

        assign rdata = dirty_array[raddr];

endmodule
