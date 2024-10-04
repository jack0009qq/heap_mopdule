`include "defines.v"

module inst_fetch
    (
    //System Signals
    input wire clk_i,
    input wire rst_i,
    //from pipectrl
    input wire stall_i,
    input wire flush_i,
    //from rom
    input wire [`XLEN-1:0] inst_i,
    //from pc
    input wire [`XLEN-1:0] pc_i,
    //to id
    output reg[`XLEN-1:0] pc_o,
    output reg[`XLEN-1:0] inst_o
    );

always @(posedge clk_i) begin

    if(rst_i)begin
        inst_o <= 32'h00000013;
        pc_o <= 0;
    end else if (flush_i) begin
        inst_o <= 32'h00000013;
        pc_o <= pc_i;        
    end else if (stall_i) begin
        inst_o <= inst_o;
        pc_o <= pc_o;
    end else begin 
        inst_o <= inst_i;
        pc_o <= pc_i; 
    end 
end 

endmodule
