`include "defines.v"

module writeback (
    input wire rst_i,
    input wire clk_i,
    //from pipectrl
    input wire stall_i,
    //from mem
    input wire [4:0] rd_addr_i,
    input wire [`XLEN-1:0] rd_data_i,
    input wire rd_we_i,
    input wire [11:0] csr_addr_i,
    input wire [`XLEN-1:0] csr_data_i,
    input wire csr_we_i,
    //to reg
    output reg [4:0]rd_addr_o,
    output reg [`XLEN-1:0] rd_data_o,
    output reg rd_we_o,
    //to csr
    output reg [11:0] csr_addr_o,
    output reg [`XLEN-1:0] csr_data_o,
    output reg csr_we_o,
    //to ctx
    output reg [`XLEN-1:0] fwdrd_data_o,
    output reg [4:0] fwdrd_addr_o
);

assign fwdrd_data_o = rd_data_i; 
assign fwdrd_addr_o = (rd_we_i)? rd_addr_i:0;

always @(posedge clk_i) begin
    if(rst_i) begin
        rd_addr_o <= 0;
        rd_data_o <= 0;
        rd_we_o <= 0;
        csr_addr_o <= 0;
        csr_data_o <= 0;
        csr_we_o <= 0;
    end else if (stall_i) begin
        rd_addr_o <= rd_addr_o;
        rd_data_o <= rd_data_o;
        rd_we_o <= rd_we_o ;
        csr_addr_o <= csr_addr_o;
        csr_data_o <= csr_data_o;
        csr_we_o <= csr_we_o;
    end else begin
        rd_addr_o <= rd_addr_i;
        rd_data_o <= rd_data_i;
        rd_we_o <= rd_we_i;
        csr_addr_o <= csr_addr_i;
        csr_data_o <= csr_data_i;
        csr_we_o <= csr_we_i;
    end 
end
endmodule
