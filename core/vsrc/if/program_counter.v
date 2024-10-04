`include "defines.v"

module program_counter(

    //System Signals
    input wire clk_i,
    input wire rst_i,
    //pipectrl
    input wire stall_i,
    input wire [`XLEN-1:0] jump_addr_i,
    input wire je_i,
    input wire [`XLEN-1:0] trap_entry_i, 
    input wire trap_taken_i,
    input wire [`XLEN-1:0] system_retaddr_i, //mret
    input wire system_ret_i,
    input wire [`XLEN-1:0] ctxret_addr_i, //ctxret
    input wire ctxret_i,
    //to rom & fetch
    output reg[`XLEN-1:0] pc_o 
);

always @(posedge clk_i) begin
    if (rst_i) begin
        pc_o <= 32'b0 ;
    end else if (trap_taken_i)begin
        pc_o <= trap_entry_i;
    end else if (ctxret_i)begin
        pc_o <= ctxret_addr_i;
    end else if (stall_i) begin
        pc_o <= pc_o;    
    end else if (system_ret_i) begin
        pc_o <= system_retaddr_i;
    end else if (je_i) begin
        pc_o <= jump_addr_i;

    end else begin 
        pc_o <= pc_o +4;
    end
end
endmodule
