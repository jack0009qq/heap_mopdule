`include "defines.v"


module pipectrl(   
    //from id 
    input wire loaduse_hazard_i,
    input wire mem_re_i,
    input wire mem_we_i,
    //from exe
    input wire [`XLEN-1:0] jump_addr_i,
    input wire je_i,
    input wire mtype_stall_i,
    input wire exectxstall_i,
    //from mem
    input wire memstall_i,
    //from csr
    input wire trap_taken_i,
    input wire [`XLEN-1:0] trap_entry_i,
    input wire system_ret_i,
    input wire [`XLEN-1:0] system_retaddr_i,
    //from ctx
    input wire ctxstall_i,
    input wire ctxret_i,
    input wire [`XLEN-1:0] ctxret_addr_i,
    //from heap
    input wire heapstall_i,
    //to pc
    output reg stallpc_o,
    output reg je_o,
    output reg [`XLEN-1:0] jump_addr_o,
    output reg trap_taken_o,
    output reg [`XLEN-1:0] trap_entry_o,
    output reg system_ret_o,
    output reg [`XLEN-1:0] system_retaddr_o,
    output reg ctxret_o,
    output reg [`XLEN-1:0] ctxret_addr_o,
    //to if
    output reg stallif_o,
    output reg flushif_o,
    //to id
    output reg flushid_o,
    output reg stallid_o,
    //to exe
    output reg stallexe_o,
    output reg flushexe_o,
    //to mem
    output reg stallmem_o,
    output reg flushmem_o,
    //to wb
    output reg stallwb_o
);

wire idmem_stall;
assign jump_addr_o = jump_addr_i;
assign je_o = je_i;
assign trap_entry_o = trap_entry_i;
assign trap_taken_o = trap_taken_i;
assign system_ret_o = system_ret_i;
assign system_retaddr_o = system_retaddr_i;
assign ctxret_o = ctxret_i;
assign ctxret_addr_o = ctxret_addr_i;
assign idmem_stall = mem_re_i | mem_we_i;

assign stallpc_o = loaduse_hazard_i | mtype_stall_i | exectxstall_i | ctxstall_i | heapstall_i | memstall_i | idmem_stall;
assign stallif_o = loaduse_hazard_i | mtype_stall_i | exectxstall_i | ctxstall_i | heapstall_i | memstall_i | idmem_stall;
assign stallid_o = mtype_stall_i | exectxstall_i | ctxstall_i | heapstall_i | memstall_i ;
assign stallexe_o = mtype_stall_i | memstall_i | heapstall_i  ;
assign stallmem_o = mtype_stall_i | memstall_i ;
assign stallwb_o = mtype_stall_i | memstall_i ;

assign flushif_o = je_i | trap_taken_i | system_ret_i | ctxret_i;
assign flushid_o = loaduse_hazard_i | je_i | trap_taken_i | system_ret_i | exectxstall_i | ctxret_i | idmem_stall;
assign flushexe_o = trap_taken_i | system_ret_i | ctxstall_i | ctxret_i;
assign flushmem_o = trap_taken_i | system_ret_i | ctxret_i ;

endmodule
