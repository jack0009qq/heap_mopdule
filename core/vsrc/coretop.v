`include "defines.v"

module coretop (
    input wire rst_i,
    input wire clk_i,

    //rom
    input wire [`XLEN-1:0] rom_data_i,
    output reg [`XLEN-1:0] rom_addr_o,
    //ram
    input wire [`XLEN-1:0] ram_data_i,
    output reg [`XLEN-1:0] ram_addr_o,
    output reg [`XLEN-1:0] ram_wdata_o,
    output reg ram_we_o,
    output reg ram_req_o,

    //clint
    input wire timer_irq_i,
    input wire software_irq_i,
    input wire external_irq_i //no support now
);

//to dpram
assign rom_addr_o = pc_wire;
assign ram_addr_o  = memrom_ramaddr;
assign ram_wdata_o = memrom_ramdata;
assign ram_we_o    = memrom_memwe;
assign ram_req_o = memrom_memre | memrom_memwe ;
//to if
assign romif_inst = rom_data_i;
//to mem
assign rommem_ramdata = ram_data_i;

//pipeline ctrl
wire [`XLEN-1:0] pipectrlpc_jumpaddr;
wire pipectrlpc_je;
wire [`XLEN-1:0] pipectrlpc_trapentry;
wire pipectrlpc_traptaken;
wire [`XLEN-1:0]pipectrlpc_retaddr;
wire pipectrlpc_ret;

wire pipectrl_stallpc;
wire pipectrl_stallif;
wire pipectrl_stallid;
wire pipectrl_stallexe;
wire pipectrl_stallmem;
wire pipectrl_stallwb;

wire pipectrl_flushif;
wire pipectrl_flushid; 
wire pipectrl_flushexe;
wire pipectrl_flushmem;
//pc_rom
wire[`XLEN-1:0] pc_wire;
//rom_if
wire [`XLEN-1:0] romif_inst;
//rom_mem
wire [`XLEN-1:0] rommem_ramdata;
//if_id
wire[`XLEN-1:0] ifid_inst;
wire[`XLEN-1:0] ifid_pc;
//reg_id
wire[`XLEN-1:0] regid_data1;
wire[`XLEN-1:0] regid_data2;
//id_reg
wire[4:0] idreg_addr1;
wire[4:0] idreg_addr2;
//id_csr
wire [11:0] idcsr_addr;
//csr_id 
wire [`XLEN-1:0] csrid_data;
//id_exe
wire[`XLEN-1:0] idexe_pc;
wire[`XLEN-1:0] idexe_imm;
wire[4:0] idexe_rdaddr;
wire idexe_we;
wire [2:0]idexe_optype;
wire [2:0]idexe_opfunc3;
wire idexe_shiftsel;
wire idexe_addsubsel;
wire idexe_typesel;
wire idexe_memwe;
wire idexe_memre;
wire idexe_csrwe;
wire idexe_system_ret;
wire [`XLEN-1:0] idexe_exception;
wire [`XLEN-1:0] idexe_exceptionpc;
//id_forward
wire[`XLEN-1:0] idfwd_rs1;
wire[`XLEN-1:0] idfwd_rs2;
wire [4:0] idfwd_addr1;
wire [4:0] idfwd_addr2;
wire [11:0] idfwd_csraddr; //also to exe
wire [`XLEN-1:0] idfwd_csrdata;
//id_pipectrl
wire idpipectrl_loadusehazard;
//forward_exe
wire [`XLEN-1:0] fwdexe_rs1;
wire [`XLEN-1:0] fwdexe_rs2;
wire [`XLEN-1:0] fwdexe_csrdata;
//exe_mem
wire [`XLEN-1:0] exemem_pc;
wire [4:0] exemem_rdaddr;
wire [`XLEN-1:0]exemem_rddata;
wire exemem_we;
wire [`XLEN-1:0] exemem_memaddr;
wire exemem_memre;
wire exemem_memwe;
wire [2:0]exemem_opfunc3;
wire [11:0] exemem_csraddr;
wire [`XLEN-1:0] exemem_csrdata;
wire exemem_csrwe;
wire exemem_system_ret;
wire [`XLEN-1:0] exemem_exception;
wire [`XLEN-1:0] exemem_exceptionpc;
//exe_pipectrl
wire [`XLEN-1:0] exepipe_jumpaddr;
wire exepipe_je;
wire exepipe_stall;
//mem_wb
wire[4:0] memwb_rdaddr;
wire[`XLEN-1:0] memwb_rddata;
wire memwb_we;
wire [11:0] memwb_csraddr;
wire [`XLEN-1:0] memwb_csrdata;
wire memwb_csrwe;
//mem_pipectrl
wire mempipe_stall;
//mem_csr
wire [`XLEN-1:0] memcsr_pc;
wire memcsr_system_ret;
wire [`XLEN-1:0] memcsr_exception;
wire [`XLEN-1:0] memcsr_exceptionpc;
//mem_rom
wire [`XLEN-1:0] memrom_ramaddr;
wire [`XLEN-1:0] memrom_ramdata;
wire memrom_memwe;
wire memrom_memre;
//wb_reg
wire [4:0] wbreg_rdaddr;
wire [`XLEN-1:0] wbreg_rddata;
wire wbreg_we;
//wb_csr
wire [11:0] wbcsr_csraddr;
wire [`XLEN-1:0] wbcsr_csrdata;
wire wbcsr_csrwe;
//clint_csr
wire clint_software_irq = software_irq_i;
wire clint_timer_irq = timer_irq_i;
wire clint_external_irq = external_irq_i;
//csr_pipectrl
wire [`XLEN-1:0] csrpipe_entry;
wire csrpipe_taken;
wire [`XLEN-1:0] csrpipe_retaddr;
wire csrpipe_ret;

/////////use for ctx//////////
//id_exe
wire idexe_ctx; 
//exe_ctx
wire [`XLEN-1:0] exectx_oldmemaddr;
wire [`XLEN-1:0] exectx_newmemaddr;
wire [1:0] exectx_en;
wire exectx_ret;
//wb_ctx
wire [`XLEN-1:0] wbctx_regdata;
wire [4:0] wbctx_regaddr;
//reg_ctx
wire [`XLEN-1:0] regctx_olddata [1:31];
//ctx_reg
wire [`XLEN-1:0] ctxreg_newdata [1:31];
wire ctxreg_re;
//ctx_csr
wire [`XLEN-1:0] ctxcsr_exception;
wire [`XLEN-1:0] ctxcsr_mscratch;
wire ctxcsr_ret;
//csr_pipectrl
wire csrpipe_ctxret;
wire [`XLEN-1:0] csrpipe_ctxretaddr;
//ctx_pipectrl
wire ctxstall;

//exe_pipectrl
wire exectxstall;
//pipectrl_pc
wire pipectrlpc_ctxret;
wire [`XLEN-1:0] pipectrlpc_ctxretaddr;
/////////use for ctx//////////
/////////use for heap/////////
//heap_pipectrl------------------------
wire heapstall;
//exe_heap
wire [`XLEN-1:0] exeheap_memaddr;
wire [`XLEN-1:0] exeheap_priority;
wire [1:0] exeheap_en;
//heap_csr
wire [`XLEN-1:0] heapcsr_heapctx;
wire [`XLEN-1:0] heapcsr_heapctxfull;
wire [`XLEN-1:0] heapcsr_exception;
//heap_mem_for
wire [11:0] heapmem_addr;
wire [31:0] heapmem_data;
/////////use for heap/////////

pipectrl pipectrl0 (
    //from id
    .loaduse_hazard_i(idpipectrl_loadusehazard),
    .mem_re_i(idexe_memre),
    .mem_we_i(idexe_memwe),
    //from exe
    .jump_addr_i(exepipe_jumpaddr),
    .je_i(exepipe_je),
    .mtype_stall_i(exepipe_stall),
    .exectxstall_i(exectxstall),
    //from mem
    .memstall_i(mempipe_stall),
    //from csr
    .trap_entry_i(csrpipe_entry),
    .trap_taken_i(csrpipe_taken),
    .system_ret_i(csrpipe_ret),
    .system_retaddr_i(csrpipe_retaddr),
    .ctxret_i(csrpipe_ctxret),
    .ctxret_addr_i(csrpipe_ctxretaddr),
    //from ctx
    .ctxstall_i(ctxstall),
    //from heap
    .heapstall_i(heapstall),
    // to pc
    .jump_addr_o(pipectrlpc_jumpaddr),
    .je_o(pipectrlpc_je),
    .stallpc_o(pipectrl_stallpc),
    .trap_taken_o(pipectrlpc_traptaken),
    .trap_entry_o(pipectrlpc_trapentry),
    .system_ret_o(pipectrlpc_ret),
    .system_retaddr_o(pipectrlpc_retaddr),
    .ctxret_o(pipectrlpc_ctxret),
    .ctxret_addr_o(pipectrlpc_ctxretaddr),
    //to if
    .stallif_o(pipectrl_stallif),
    .flushif_o(pipectrl_flushif),
    //to id
    .flushid_o(pipectrl_flushid),
    .stallid_o(pipectrl_stallid),
    //to exe
    .stallexe_o(pipectrl_stallexe),
    .flushexe_o(pipectrl_flushexe),
    //to mem
    .stallmem_o(pipectrl_stallmem),
    .flushmem_o(pipectrl_flushmem),
    //to wb
    .stallwb_o(pipectrl_stallwb)

);

program_counter program_counter0(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .pc_o(pc_wire),
    .stall_i(pipectrl_stallpc),
    .jump_addr_i(pipectrlpc_jumpaddr),
    .je_i(pipectrlpc_je),
    .trap_entry_i(pipectrlpc_trapentry),
    .trap_taken_i(pipectrlpc_traptaken),
    .system_ret_i(pipectrlpc_ret),
    .system_retaddr_i(pipectrlpc_retaddr),
    .ctxret_i(pipectrlpc_ctxret),
    .ctxret_addr_i(pipectrlpc_ctxretaddr)
);

inst_fetch inst_fetch0(
    .clk_i(clk_i),
    .rst_i(rst_i),
    //from pipectrl
    .stall_i(pipectrl_stallif),
    .flush_i(pipectrl_flushif),
    //from rom 
    .inst_i(romif_inst),
    .pc_i(pc_wire), 
    //to id
    .inst_o(ifid_inst),
    .pc_o(ifid_pc)
);

regfiles regfiles0(
    .clk_i(clk_i),
    .rst_i(rst_i),
    //from id
    .rs1_addr_i(idreg_addr1),
    .rs2_addr_i(idreg_addr2),
    //from wb
    .rd_addr_i(wbreg_rdaddr),
    .rd_data_i(wbreg_rddata),
    .rd_we_i(wbreg_we),
    //from ctx
    .ctx_data_i(ctxreg_newdata),
    .ctx_re_i(ctxreg_re),
    //to ctx
    .ctx_data_o(regctx_olddata),
    //to id
    .rs1_data_o(regid_data1),
    .rs2_data_o(regid_data2)
);

ctxfile ctxfile0(
    .clk_i(clk_i),
    .rst_i(rst_i),
    //from exe
    .oldctx_memaddr_i(exectx_oldmemaddr),
    .newctx_memaddr_i(exectx_newmemaddr),
    .ctx_en_i(exectx_en),
    .ctxret_i(exectx_ret),
    //from wb
    .fwd_wbregdata_i(wbctx_regdata),
    .fwd_wbregaddr_i(wbctx_regaddr),
    //from reg
    .oldctx_data_i(regctx_olddata),
    //to reg 
    .newctx_data_o(ctxreg_newdata),
    .ctx_re_o(ctxreg_re),
    //to csr
    .exception_o(ctxcsr_exception),
    .mscratch_addr_o(ctxcsr_mscratch),
    .ctxret_o(ctxcsr_ret),
    //to pipe_ctrl
    .ctxstall_o(ctxstall)
);

csrfile csrflie0 (
    .clk_i(clk_i),
    .rst_i(rst_i),
    //from clint
    .timer_irq_i(clint_timer_irq),
    .software_irq_i(clint_software_irq),
    .external_irq_i(clint_external_irq),
    //from id 
    .csr_raddr_i(idcsr_addr),
    //from mem
    .mempc_i(memcsr_pc),
    .system_ret_i(memcsr_system_ret),
    .exception_i(memcsr_exception),
    .exceptionpc_i(memcsr_exceptionpc),
    //from ctx
    .ctx_exception_i(ctxcsr_exception),
    .ctx_mscratch_i(ctxcsr_mscratch),
    .ctxret_i(ctxcsr_ret),
    //from heap-----------------------------------
    .heapctx_i(heapcsr_heapctx),
    .heapfullctx_i(heapcsr_heapctxfull),
    .heap_exception_i(heapcsr_exception),
    //from wb
    .csr_waddr_i(wbcsr_csraddr),
    .csr_wdata_i(wbcsr_csrdata),
    .csr_we_i(wbcsr_csrwe),
    //to id
    .csr_rdata_o(csrid_data),
    //to pipectrl
    .trap_entry_o(csrpipe_entry),
    .trap_taken_o(csrpipe_taken),
    .system_ret_o(csrpipe_ret),
    .system_retaddr_o(csrpipe_retaddr),
    .ctxret_o(csrpipe_ctxret),
    .ctxret_addr_o(csrpipe_ctxretaddr)
);

decode decode0(
    .clk_i(clk_i),
    .rst_i(rst_i),
    //from pipe ctrl
    .flush_i(pipectrl_flushid),
    .stall_i(pipectrl_stallid),
    //from id
    .inst_i(ifid_inst),
    .pc_i(ifid_pc),
    //from reg 
    .reg_data1_i(regid_data1),
    .reg_data2_i(regid_data2),
    //from csr
    .csr_data_i(csrid_data),
    //to reg
    .rs1_addr_o(idreg_addr1),
    .rs2_addr_o(idreg_addr2),
    //to exe
    .pc_o(idexe_pc),
    .imm_o(idexe_imm),
    .rd_addr_o(idexe_rdaddr),
    .rd_we_o(idexe_we),
    .optype_o(idexe_optype),
    .opfunc3_o(idexe_opfunc3),
    .shiftsel_o(idexe_shiftsel),
    .addsubsel_o(idexe_addsubsel),
    .typesel_o(idexe_typesel),
    .mem_re_o(idexe_memre),
    .mem_we_o(idexe_memwe),
    .csr_we_o(idexe_csrwe),
    .system_ret_o(idexe_system_ret),
    .exception_o(idexe_exception),
    .exceptionpc_o(idexe_exceptionpc),
    .ctx_o(idexe_ctx),
    //to csr
    .csr_addr_o(idcsr_addr),
    //to forwarding
    .rs1_o(idfwd_rs1),
    .rs2_o(idfwd_rs2),
    .fwd_raddr1_o(idfwd_addr1),
    .fwd_raddr2_o(idfwd_addr2),
    .fwd_csr_addr_o(idfwd_csraddr),
    .fwd_csr_data_o(idfwd_csrdata),
    //to pipectrl
    .loaduse_hazard_o(idpipectrl_loadusehazard)
);

exe exe0(
    .clk_i(clk_i),
    .rst_i(rst_i),
    //from pipectrl
    .stall_i(pipectrl_stallexe),
    .flush_i(pipectrl_flushexe),
    //to pipectrl
    .jump_addr_o(exepipe_jumpaddr),
    .je_o(exepipe_je),
    .mtype_stall_o(exepipe_stall),
    .ctxstall_o(exectxstall),
    //from decode
    .pc_i(idexe_pc),
    .imm_i(idexe_imm),
    .rd_addr_i(idexe_rdaddr),
    .rd_we_i(idexe_we),
    .optype_i(idexe_optype),
    .opfunc3_i(idexe_opfunc3),
    .shiftsel_i(idexe_shiftsel),
    .addsubsel_i(idexe_addsubsel),
    .typesel_i(idexe_typesel),
    .mem_re_i(idexe_memre),
    .mem_we_i(idexe_memwe),
    .csr_addr_i(idfwd_csraddr),
    .csr_we_i(idexe_csrwe),
    .system_ret_i(idexe_system_ret),
    .exception_i(idexe_exception),
    .exceptionpc_i(idexe_exceptionpc),
    .ctx_i(idexe_ctx),
    //to mem & forwarding
    .pc_o(exemem_pc),
    .rd_addr_o(exemem_rdaddr),
    .rd_data_o(exemem_rddata),
    .rd_we_o(exemem_we),
    .mem_addr_o(exemem_memaddr),
    .mem_re_o(exemem_memre),
    .mem_we_o(exemem_memwe),
    .opfunc3_o(exemem_opfunc3),
    .csr_addr_o(exemem_csraddr),
    .csr_data_o(exemem_csrdata),
    .csr_we_o(exemem_csrwe),
    .system_ret_o(exemem_system_ret),
    .exception_o(exemem_exception),
    .exceptionpc_o(exemem_exceptionpc),
    //from forwarding
    .rs1_i(fwdexe_rs1),
    .rs2_i(fwdexe_rs2),
    .csr_data_i(fwdexe_csrdata),
    //to ctx
    .ctx_o(exectx_en),
    .newctx_memaddr_o(exectx_newmemaddr),
    .oldctx_memaddr_o(exectx_oldmemaddr),
    .ctxret_o(exectx_ret),
    //to heap---------------------------------------------------------
    .heap_o(exeheap_en),
    .ctx_memaddr_o(exeheap_memaddr),
    .task_priority_o(exeheap_priority)

);

heap heap0(
    .clk_i(clk_i),
    .rst_i(rst_i),
    //from exe
    .task_priority_i(exeheap_priority),
    .ctx_memaddr_i(exeheap_memaddr),
    .heap_en_i(exeheap_en),
    //to pipectrl
    .heapstall_o(heapstall),
    //to mem to forward
    .heapcsr_addr_o(heapmem_addr),
    .heapcsr_data_o(heapmem_data),
    //to csr
    .heap_exception_o(heapcsr_exception),
    .heapctx_o(heapcsr_heapctx),
    .heapfullctx_o(heapcsr_heapctxfull)
);

mem mem0(
    .clk_i(clk_i),
    .rst_i(rst_i),
    //from pipectrl
    .stall_i(pipectrl_stallmem),
    .flush_i(pipectrl_flushmem),
    //from exe 
    .pc_i(exemem_pc),
    .rd_addr_i(exemem_rdaddr),
    .rd_data_i(exemem_rddata),
    .rd_we_i(exemem_we),
    .mem_addr_i(exemem_memaddr),
    .mem_re_i(exemem_memre),
    .mem_we_i(exemem_memwe),
    .opfunc3_i(exemem_opfunc3),
    .csr_addr_i(exemem_csraddr),
    .csr_data_i(exemem_csrdata),
    .csr_we_i(exemem_csrwe),
    .system_ret_i(exemem_system_ret),
    .exception_i(exemem_exception),
    .exceptionpc_i(exemem_exceptionpc),
    //from heap----------------------------
    .heapcsr_addr_i(heapmem_addr),
    .heapcsr_data_i(heapmem_data),
    //from ram 
    .ram_data_i(rommem_ramdata),
    //to ram
    .ram_addr_o(memrom_ramaddr),
    .ram_data_o(memrom_ramdata),
    .ram_we_o(memrom_memwe),
    .ram_re_o(memrom_memre),
    //to wb & forwardind
    .rd_addr_o(memwb_rdaddr),
    .rd_data_o(memwb_rddata),
    .rd_we_o(memwb_we),
    .csr_addr_o(memwb_csraddr),
    .csr_data_o(memwb_csrdata),
    .csr_we_o(memwb_csrwe),
    //to csr
    .pc_o(memcsr_pc),
    .system_ret_o(memcsr_system_ret),
    .exception_o(memcsr_exception),
    .exceptionpc_o(memcsr_exceptionpc),
    //to pipectrl
    .stall_o(mempipe_stall)
);

writeback writeback0(
    .clk_i(clk_i),
    .rst_i(rst_i),
    //from pipectrl
    .stall_i(pipectrl_stallwb),
    //from exe 
    .rd_addr_i(memwb_rdaddr),
    .rd_data_i(memwb_rddata),
    .rd_we_i(memwb_we),
    .csr_addr_i(memwb_csraddr),
    .csr_data_i(memwb_csrdata),
    .csr_we_i(memwb_csrwe),
    //to reg & forwarding
    .rd_addr_o(wbreg_rdaddr),
    .rd_data_o(wbreg_rddata),
    .rd_we_o(wbreg_we),
    //to csr & forwarding
    .csr_addr_o(wbcsr_csraddr),
    .csr_data_o(wbcsr_csrdata),
    .csr_we_o(wbcsr_csrwe),
    //to ctx
    .fwdrd_data_o(wbctx_regdata),
    .fwdrd_addr_o(wbctx_regaddr)
);

forwarding forwarding0(
    //from id
    .rs1_addr_i(idfwd_addr1),
    .rs2_addr_i(idfwd_addr2),
    .rs1_data_i(idfwd_rs1),
    .rs2_data_i(idfwd_rs2),
    .csr_addr_i(idfwd_csraddr),
    .csr_data_i(idfwd_csrdata),
    //from exe 
    .exe_rdaddr_i(exemem_rdaddr),
    .exe_rddata_i(exemem_rddata),
    .exe_rdwe(exemem_we),
    .exe_csraddr_i(exemem_csraddr),
    .exe_csrdata_i(exemem_csrdata),
    .exe_csrwe_i(exemem_csrwe),
    //from heap
    .heap_csraddr_i(heapmem_addr),
    .heap_csrdata_i(heapmem_data),
    
    //from mem
    .mem_rdaddr_i(memwb_rdaddr),
    .mem_rddata_i(memwb_rddata),
    .mem_rdwe(memwb_we),
    .mem_csraddr_i(memwb_csraddr),
    .mem_csrdata_i(memwb_csrdata),
    .mem_csrwe_i(memwb_csrwe),
    //from wb
    .wb_rdaddr_i(wbreg_rdaddr),
    .wb_rddata_i(wbreg_rddata),
    .wb_rdwe(wbreg_we),
    .wb_csraddr_i(wbcsr_csraddr),
    .wb_csrdata_i(wbcsr_csrdata),
    .wb_csrwe_i(wbcsr_csrwe),
    //to exe
    .rs1_data_o(fwdexe_rs1),
    .rs2_data_o(fwdexe_rs2),
    .csr_data_o(fwdexe_csrdata)
);

endmodule
