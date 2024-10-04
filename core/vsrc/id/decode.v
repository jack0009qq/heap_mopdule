`include "defines.v"

module decode (
    //System Signals
    input wire clk_i,
    input wire rst_i,
    //from inst_fetch
    input wire [`XLEN-1:0] pc_i,
    input wire [`XLEN-1:0] inst_i,
    //from regfile
    input wire [`XLEN-1:0] reg_data1_i,
    input wire [`XLEN-1:0] reg_data2_i,
    //from csr
    input wire [`XLEN-1:0] csr_data_i,
    //from pipectrl
    input wire flush_i,
    input wire stall_i,
    //to regfile 
    output reg [4:0] rs1_addr_o,
    output reg [4:0] rs2_addr_o,
    //to csr
    output reg [11:0] csr_addr_o,
    //to exe
    output reg [`XLEN-1:0] pc_o,
    output reg [`XLEN-1:0] imm_o,
    output reg [4:0] rd_addr_o,
    output reg rd_we_o,
    output reg [2:0] opfunc3_o,
    output reg [2:0] optype_o,
    output reg shiftsel_o,
    output reg addsubsel_o,
    output reg typesel_o,
    output reg mem_re_o,
    output reg mem_we_o,
    output reg csr_we_o,
    output reg system_ret_o,
    output reg [`XLEN-1:0] exception_o,
    output reg [`XLEN-1:0] exceptionpc_o,
    output reg ctx_o,    
    //to forwarding
    output reg [`XLEN-1:0] rs1_o,
    output reg [`XLEN-1:0] rs2_o,
    output reg [4:0] fwd_raddr1_o,
    output reg [4:0] fwd_raddr2_o,
    output reg [11:0] fwd_csr_addr_o,
    output reg [`XLEN-1:0] fwd_csr_data_o,
    //to pipe ctrl
    output reg loaduse_hazard_o
);

wire [`XLEN-1:0] rv32inst = inst_i;
wire [6:0] opcode = rv32inst[6:0];
wire [2:0] opfunc3 = (LUItype|AUPICtype)? 3'b000:rv32inst[14: 12];
wire [6:0] opfunc7 = rv32inst[`XLEN-1 : 25];
assign rs1_addr_o = rv32inst[19:15];
assign rs2_addr_o = rv32inst[24:20];
assign csr_addr_o = rv32inst[31:20];

wire [4:0] rd_addr = rv32inst[11:7];
reg [2:0] optype;

//read write memory
wire mem_re,mem_we;
assign mem_re = Ltype ;
assign mem_we = Stype ;
//which type need write rd
wire reg_we;
assign reg_we = Itype | Rtype | Ltype | LUItype | AUPICtype | JALtype | JALRtype | Mtype | CSRtype | CTXtype;
wire csr_we;
assign csr_we = CSRtype;
//immediately type
wire [`XLEN-1:0] immI,immL,immS,immU,immJ,immB,immCSR;
assign immI = {{20{rv32inst[31]}}, rv32inst[31:20]};
assign immL = {{20{rv32inst[31]}}, rv32inst[31:20]};
assign immS = {{20{rv32inst[31]}}, rv32inst[31:25],rv32inst[11:7]};
assign immU = {rv32inst[31:12], 12'b0};
assign immJ = {{12{rv32inst[31]}}, rv32inst[19:12], rv32inst[20], rv32inst[30:21],1'b0};
assign immB = {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
assign immCSR = {27'b0,rv32inst[19:15]};
//optype
wire Itype = (opcode == 7'b0010011);
wire Rtype = (opcode == 7'b0110011) && (opfunc7 != 7'b0000001);
wire Mtype = (opcode == 7'b0110011) && (opfunc7 == 7'b0000001);
wire Ltype = (opcode == 7'b0000011);
wire Stype = (opcode == 7'b0100011);
wire LUItype = (opcode == 7'b0110111) ;
wire AUPICtype = (opcode == 7'b0010111);
wire JALtype = (opcode == 7'b1101111);
wire JALRtype = (opcode == 7'b1100111);
wire Btype = (opcode == 7'b1100011);
//system instruction
wire CSRtype = (opcode == 7'b1110011) && (opfunc3 != 3'b000);
wire MRETtype = (opcode == 7'b1110011) && (opfunc3 == 3'b000) && (rv32inst[31:20] == 12'b001100000010);
wire ECALLtype = (opcode == 7'b1110011) && (opfunc3 == 3'b000) && (rv32inst[31:20] == 12'b000000000000);

wire shiftsel = (opfunc7 == 7'b0100000)? 1 : 0 ; //sra:srl
wire addsubsel = (opcode == 7'b0110011) && (opfunc7 == 7'b0100000) && (opfunc3 == 3'b000); //add:sub
wire typesel = (JALtype || LUItype)?  1:0 ; //jal,lui : jalr,aupic

//data hazard
wire raddr1_thesame = (rs1_addr_o == rd_addr_o) && (Rtype || Stype || Btype || Itype || Ltype || JALRtype || CSRtype || MRETtype || Mtype || CTXtype);
wire raddr2_thesame = (rs2_addr_o == rd_addr_o) && (Rtype || Stype || Btype || Mtype || CTXtype) ;
assign loaduse_hazard_o = (raddr1_thesame | raddr2_thesame ) && mem_re_o;

//exception
wire [`XLEN-1:0] exception;
assign exception = (ECALLtype)? 'd11:0; //m_mode ecall

//ctx_new instruction
//heap opcode7 = ctx-------------------------------------------------------
wire CTXtype = (opcode == 7'b0001011);

/*
-----------------
finish Rtype,Itype,Stype,Utype,Ltype,LUItype,AUPICtype,JALtype,JALRtype,Btype,CSRtype,MRETtype,ECALLtype
*/

wire [`XLEN-1:0] imm;
assign imm = ({32{Itype}} & immI)
    |({32{Ltype}} & immL)
    |({32{Stype}} & immS)
    |({32{LUItype}} & immU)
    |({32{AUPICtype}} & immU)
    |({32{JALtype}} & immJ)
    |({32{JALRtype}} & immI)
    |({32{Btype}} & immB)
    |({32{CSRtype}} & immCSR)
        ;

always @(*) begin
    if (Rtype)
        optype = 3'b000;
    else if (Itype)
        optype = 3'b001;
    else if (Btype)
        optype = 3'b010;
    else if (Stype)
        optype = 3'b011;
    else if (LUItype | AUPICtype) 
        optype = 3'b100;
    else if (Mtype) 
        optype = 3'b101;
    else if (JALtype | JALRtype)
        optype = 3'b110;
    else 
        optype = 3'b111; 
end

always @(posedge clk_i) begin
    if(rst_i || flush_i) begin
        pc_o <= (flush_i)? pc_i:0;
        fwd_raddr1_o <= 0;
        fwd_raddr2_o <= 0;
        rs1_o <= 0;
        rs2_o <= 0;   
        rd_addr_o <= 0;
        rd_we_o <= 1;  
        imm_o <= 0;
        opfunc3_o <= 0;
        optype_o <= 1;
        shiftsel_o <= 0;
        addsubsel_o <= 0;
        typesel_o <=0;
        mem_re_o <= 0;
        mem_we_o <= 0;
        fwd_csr_addr_o <= 0;
        fwd_csr_data_o <= 0;
        csr_we_o <= 0;
        system_ret_o <= 0;
        exception_o <= 0;
        exceptionpc_o <= 0;
        ctx_o <= 0;
    end else if(stall_i)begin
        pc_o <= pc_o;
        fwd_raddr1_o <= fwd_raddr1_o;
        fwd_raddr2_o <= fwd_raddr2_o;
        rs1_o <= rs1_o;
        rs2_o <= rs2_o;   
        rd_addr_o <= rd_addr_o;
        rd_we_o <= rd_we_o;  
        imm_o <= imm_o;
        opfunc3_o <= opfunc3_o;
        optype_o <= optype_o;
        shiftsel_o <= shiftsel_o;
        addsubsel_o <= addsubsel_o;
        typesel_o <= typesel_o;
        mem_re_o <= mem_re_o;
        mem_we_o <= mem_we_o;    
        fwd_csr_addr_o <= fwd_csr_addr_o;
        fwd_csr_data_o <= fwd_csr_data_o;
        csr_we_o <= csr_we_o;
        system_ret_o <= system_ret_o;
        exception_o <= exception_o;
        exceptionpc_o <= exceptionpc_o;
        ctx_o <= ctx_o;
    end else begin
        pc_o <= pc_i;
        fwd_raddr1_o <= rs1_addr_o;
        fwd_raddr2_o <= rs2_addr_o;
        rd_addr_o <= rd_addr;
        rd_we_o <= reg_we;
        rs1_o <= reg_data1_i;
        rs2_o <= reg_data2_i;
        imm_o <= imm;
        opfunc3_o <= opfunc3;
        optype_o <= optype;
        shiftsel_o <= shiftsel; 
        addsubsel_o <= addsubsel;
        typesel_o <= typesel;
        mem_re_o <= mem_re;
        mem_we_o <= mem_we;
        fwd_csr_addr_o <= csr_addr_o;
        fwd_csr_data_o <= csr_data_i;
        csr_we_o <= csr_we; 
        system_ret_o <= MRETtype;
        exception_o <= exception;
        exceptionpc_o <= pc_i;
        ctx_o <= CTXtype;
    end
end

endmodule
