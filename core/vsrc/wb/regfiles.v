`include "defines.v"

module regfiles(
    //System Signals
    input wire rst_i,
    input wire clk_i,
    //from decode
    input wire [4:0]rs1_addr_i,
    input wire [4:0]rs2_addr_i,
    //from wb
    input wire [4:0]rd_addr_i,
    input wire [`XLEN-1:0] rd_data_i,
    input wire rd_we_i,
    //from ctx
    input wire [`XLEN-1:0] ctx_data_i [1:31],
    input wire ctx_re_i,
    //to ctx
    output reg [`XLEN-1:0] ctx_data_o [1:31],
    //to decode
    output reg [`XLEN-1:0] rs1_data_o,
    output reg [`XLEN-1:0] rs2_data_o
);

reg [`XLEN-1:0] x[0:31];

wire we = rd_we_i & (|rd_addr_i);  //x0 can't be written
assign rs1_data_o = (we & (rs1_addr_i == rd_addr_i)) ? rd_data_i : (ctx_re_i)? ctx_data_i[rs1_addr_i]: x[rs1_addr_i];
assign rs2_data_o = (we & (rs2_addr_i == rd_addr_i)) ? rd_data_i : (ctx_re_i)? ctx_data_i[rs2_addr_i]: x[rs2_addr_i];

integer i;

always @(posedge clk_i)begin
    if(rst_i)begin
        for (i=0;i<32;i=i+1)
            x[i] <= 0;
    end else if(ctx_re_i) begin
        for (i=1;i<32;i=i+1)
            x[i] <= ctx_data_i[i];
    end else begin
        if(we) begin
            x[rd_addr_i] <= rd_data_i;
        end
    end
end

always@(posedge clk_i)begin
    for (i=1;i<32;i=i+1)
        ctx_data_o[i] <= x[i];
end

task readRegister;
    /*verilator public*/
    input integer raddr;
    output integer val;
    begin
        val = x[raddr[4:0]];
    end
endtask    

endmodule
