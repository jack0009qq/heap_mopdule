`include "defines.v"

module exe (
    input wire rst_i,  
    input wire clk_i,
    //from pipectrl
    input wire stall_i,
    input wire flush_i,
    //from decode
    input wire [`XLEN-1:0] pc_i,
    input wire [`XLEN-1:0] imm_i,
    input wire [4:0]rd_addr_i,
    input wire rd_we_i,
    input wire [2:0] opfunc3_i,
    input wire [2:0] optype_i,
    input wire shiftsel_i,
    input wire addsubsel_i,
    input wire typesel_i,
    input wire mem_re_i,
    input wire mem_we_i,
    input wire [11:0] csr_addr_i,
    input wire csr_we_i,
    input wire system_ret_i,
    input wire [`XLEN-1:0] exception_i,
    input wire [`XLEN-1:0] exceptionpc_i,
    input wire ctx_i,
    //from forwarding
    input wire [`XLEN-1:0] rs1_i,
    input wire [`XLEN-1:0] rs2_i,
    input wire [`XLEN-1:0] csr_data_i,
    //to memory & forwarding
    output reg [`XLEN-1:0] pc_o,
    output reg [4:0] rd_addr_o,
    output reg [`XLEN-1:0] rd_data_o,
    output reg rd_we_o,
    output reg [`XLEN-1:0] mem_addr_o,
    output reg mem_re_o,
    output reg mem_we_o,
    output reg [2:0] opfunc3_o,
    output reg [`XLEN-1:0] csr_data_o,
    output reg [11:0] csr_addr_o,
    output reg csr_we_o,
    output reg system_ret_o,
    output reg [`XLEN-1:0] exception_o,
    output reg [`XLEN-1:0] exceptionpc_o,
    //to pipectrl
    output reg [`XLEN-1:0] jump_addr_o,
    output reg je_o,
    output reg mtype_stall_o,
    output reg ctxstall_o,
    //to ctx
    output reg [1:0] ctx_o,
    output reg [`XLEN-1:0] newctx_memaddr_o,
    output reg [`XLEN-1:0] oldctx_memaddr_o,
    output reg ctxret_o,
    //to heap
    output reg [`XLEN-1:0] ctx_memaddr_o,
    output reg [`XLEN-1:0] task_priority_o,
    output reg [1:0] heap_o

);
wire [`XLEN-1:0] op1,op2;
assign op1 = (optype_i == 4)? (typesel_i)? 0:pc_i : rs1_i;
assign op2 = (optype_i == 1 || optype_i == 4)? imm_i:rs2_i;
reg [`XLEN-1:0] op_result,mtypea,mtypeb,csr_data;
reg csr_we;
wire [`XLEN-1:0] mem_addr;
assign mem_addr = (mem_re_i | mem_we_i)? $signed(rs1_i) + $signed(imm_i) : 0;

wire [`XLEN-1:0] divresult;
wire [63:0] mulresult;
wire [63:0] invertresult = ~mulresult+1;
wire mulstart = (optype_i == 5) & (opfunc3_i[2] == 0);
wire divstart = (optype_i == 5) & (opfunc3_i[2] == 1);
wire is_q_operation = (optype_i == 5) & (opfunc3_i[1] == 0);

wire mulisdone,divisdone;
wire is_b_zero = ~(|rs2_i);
//--------------------------------------------------------------------
reg [1:0] ctxop;
wire ctxret;
//假如不是ctx ret 就stall
assign ctxstall_o = ctx_i & (opfunc3_i != 3'b011);
assign ctxret =  ctx_i & (opfunc3_i == 3'b011);
//ctxret指令 stallllll
//clz
wire [31:0] clzresult;
reg  [31:0] clz_data;
//heap指令
reg [1:0] heapop;
//--------------------------------------------------------------------

always @(*) begin
    op_result = 0;
    mtypea = 0;
    mtypeb = 0;
    je_o = 0;
    jump_addr_o = 0;
    mtype_stall_o = 0;
    csr_data = 0;
    csr_we = 0;
    ctxop = 0;
    heapop = 0;
    if (optype_i == 0 || optype_i == 1 || optype_i == 4) begin //Rtype,Itype,Utype
        case(opfunc3_i)
            3'b000: op_result = (addsubsel_i)? op1 + (~op2 +1'b1) : op1 + op2 ; //sub:add
            3'b001: op_result = op1 << op2[4:0]; //sll
            3'b010: op_result = ($signed(op1) < $signed(op2))? 1 : 0; //slt
            3'b011: op_result = (op1 < op2)? 1 : 0; //sltu
            3'b100: op_result = op1 ^ op2; //xor
            3'b110: op_result = op1 | op2; //or
            3'b111: op_result = op1 & op2; //and
            3'b101: op_result = (shiftsel_i)? ($signed(op1) >>> op2[4:0]) : ($signed(op1) >> op2[4:0]); //sra:srl
        endcase
    end else if (optype_i == 2)begin //Btype
        jump_addr_o = pc_i + imm_i;
        case(opfunc3_i)
            3'b000: je_o = (op1 == op2)? 1:0 ; //beq
            3'b001: je_o = (op1 != op2)? 1:0 ; //bne
            3'b100: je_o = ($signed(op1) < $signed(op2))? 1:0 ; //blt
            3'b101: je_o = ($signed(op1) >= $signed(op2))? 1:0 ; //bge
            3'b110: je_o = (op1 < op2)? 1:0 ; //bltu
            3'b111: je_o = (op1 >= op2)? 1:0 ; //bgeu
            default : je_o = 0;
        endcase
    end else if (optype_i == 3)begin //Stype
        op_result = op2;
    end else if (optype_i == 5)begin //Mtype
        mtype_stall_o = ((!mulisdone) & (mulstart)) | ((!divisdone) & (divstart)) ;
        case(opfunc3_i)
            3'b000: begin  //mul
                mtypea = rs1_i;
                mtypeb = rs2_i;
                op_result = mulresult[`XLEN-1:0] & {32{mulisdone}}; 
            end
            3'b001: begin //muh
                mtypea = (rs1_i[31] == 1)? ~rs1_i+1:rs1_i;
                mtypeb = (rs2_i[31] == 1)? ~rs2_i+1:rs2_i;
                op_result =(rs1_i[31] ^ rs2_i[31])? invertresult[63:`XLEN] & {32{mulisdone}} : mulresult[63:`XLEN] & {32{mulisdone}}; 
            end
            3'b010: begin //mulhsu
                mtypea = (rs1_i[31] == 1)? ~rs1_i+1:rs1_i;
                mtypeb = rs2_i;
                op_result = (rs1_i[31] == 1)? invertresult[63:`XLEN] & {32{mulisdone}} : mulresult[63:`XLEN] & {32{mulisdone}}; 
            end
            3'b011: begin //mulhu
                mtypea = rs1_i;
                mtypeb = rs2_i;
                op_result = mulresult[63:`XLEN] & {32{mulisdone}}; 
            end
            3'b100: begin  //div
                mtypea = (rs1_i[31] == 1)? -rs1_i:rs1_i;
                mtypeb = (rs2_i[31] == 1)? -rs2_i:rs2_i;
                op_result = (is_b_zero)? divresult & {32{divisdone}}: (rs1_i[31] ^ rs2_i[31])? -divresult & {32{divisdone}}: divresult & {32{divisdone}};
            end
            3'b101: begin //divu
                mtypea = rs1_i;
                mtypeb = rs2_i;
                op_result = divresult & {32{divisdone}};
            end
            3'b110: begin //rem
                mtypea = (rs1_i[31] == 1)? -rs1_i:rs1_i;
                mtypeb = (rs2_i[31] == 1)? -rs2_i:rs2_i;
                op_result = (is_b_zero)? divresult& {32{divisdone}}: (rs1_i[31] == 1)? -divresult & {32{divisdone}}: divresult & {32{divisdone}};
            end
            3'b111: begin //remu
                mtypea = rs1_i;
                mtypeb = rs2_i;
                op_result = divresult & {32{divisdone}};
            end
            default:op_result = 0;
        endcase
    end else if (optype_i == 6)begin //Jtype
        op_result = pc_i + 4 ;
        jump_addr_o = typesel_i?  pc_i + imm_i : (rs1_i + imm_i) & {{31{1'b1}},1'b0}; //JAL : JALR
        je_o = 1;
    end else if (csr_we_i)begin //SYSTEMtype
        case(opfunc3_i)
            3'b001:begin //CSRRW
                op_result = csr_data_i;
                csr_data = op1; 
                csr_we = 1;
            end
            3'b010:begin //CSRRS
                op_result = csr_data_i;
                csr_data = csr_data_i | op1 ;
                csr_we = (op1 == 0)? 0:1;
            end
            3'b011:begin //CSRRC
                op_result = csr_data_i;
                csr_data = csr_data_i & ~op1;
                csr_we = (op1 == 0)? 0:1;
            end
            3'b101:begin //CSRRWI
                op_result = csr_data_i;
                csr_data = imm_i; 
                csr_we = 1;
            end
            3'b110:begin //CSRRSI
                op_result = csr_data_i;
                csr_data = csr_data_i | imm_i;
                csr_we = (imm_i == 0)? 0:1;
            end
            3'b111:begin //CSRRCI
                op_result = csr_data_i;
                csr_data = csr_data_i & ~imm_i;
                csr_we = (imm_i == 0)? 0:1;
            end
            default:begin
                op_result = 0;
                csr_data = 0;
                csr_we = 0;
            end
        endcase
    //新增heap指令--------------------------------------------------
    //為了exception 注意ctxfile運作問題，把他disable
    end else if(ctx_i) begin
        case(opfunc3_i)
            3'b000:begin
                ctxop = 2'b11; //ctx
                heapop = 2'b00;
            end
            3'b001:begin
                ctxop = 2'b01; //ctx load
                heapop = 2'b00;
            end
            3'b010:begin
                ctxop = 2'b10; //ctx store
                heapop = 2'b00;
            end
            3'b100:begin
                ctxop = 2'b00;
                heapop = 2'b01;//heap                
            end
            3'b101:begin
                ctxop = 2'b00;
                heapop = 2'b10;//heapdel                
            end
            3'b110:begin
                ctxop = 2'b00;
                heapop = 2'b11;//heapdeltask                 
            end
            3'b111:begin //clz
                clz_data = rs1_i;
                op_result = clzresult;


            end
            default:begin
                ctxop = 2'b00; 
                heapop = 2'b00;
            end
        endcase                                                                   
    end else begin
        op_result = 0;
        je_o = 0;
        jump_addr_o = 0;
        ctxop = 0;
        heapop = 0;
    end
end

clz clz0(
    .rs1_data_i(clz_data),
    .clzresult_o(clzresult)
);


mul mul0(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .a_i(mtypea),
    .b_i(mtypeb),
    .start_i(mulstart),
    .mulresult_o(mulresult),
    .isdone_o(mulisdone)
);

div div0(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .a_i(mtypea),
    .b_i(mtypeb),
    .start_i(divstart),
    .is_q_i(is_q_operation),
    .divresult_o(divresult),
    .isdone_o(divisdone)
);

always@(posedge clk_i) begin
    if (rst_i | flush_i) begin
        pc_o <= 0;
        rd_addr_o <= 0;
        rd_data_o <= 0;
        rd_we_o <= 0;
        mem_addr_o <= 0;
        mem_re_o <= 0 ;
        mem_we_o <= 0 ;
        opfunc3_o <= 0;
        csr_addr_o <= 0;
        csr_data_o <= 0;
        csr_we_o <= 0;
        system_ret_o <= 0;
        exception_o <= 0;
        exceptionpc_o <= 0;
    end else if (stall_i)begin
        pc_o <= pc_o;
        rd_addr_o <= rd_addr_o;
        rd_data_o <= rd_data_o;
        rd_we_o <= rd_we_o;
        mem_addr_o <= mem_addr_o;
        mem_re_o <= mem_re_o;
        mem_we_o <= mem_we_o ;
        opfunc3_o <= opfunc3_o;
        csr_addr_o <= csr_addr_o;
        csr_data_o <= csr_data_o;
        csr_we_o <= csr_we_o;
        system_ret_o <= system_ret_o;
        exception_o <= exception_o;
        exceptionpc_o <= exceptionpc_o;
    end else begin
        pc_o <= pc_i;
        rd_addr_o <= rd_addr_i;
        rd_data_o <= op_result;
        rd_we_o <= rd_we_i;
        mem_addr_o <= mem_addr;
        mem_re_o <= mem_re_i;
        mem_we_o <= mem_we_i ;
        opfunc3_o <= opfunc3_i;
        csr_addr_o <= csr_addr_i;
        csr_data_o <= csr_data;
        csr_we_o <= csr_we;
        system_ret_o <= system_ret_i;
        exception_o <= exception_i;
        exceptionpc_o <= exceptionpc_i;
    end
end    
//------------------------------------------------------------------------
//新增heap指令
always @(posedge clk_i)begin
    if (rst_i | flush_i) begin          
        ctx_o <= 0;
        newctx_memaddr_o <= 0; 
        oldctx_memaddr_o <= 0;
        ctxret_o <= 0;
        ctx_memaddr_o <= 0;
        task_priority_o <= 0;
        heap_o <= 0;
    end else if (stall_i) begin
        ctx_o <= ctx_o;
        newctx_memaddr_o <= newctx_memaddr_o; 
        oldctx_memaddr_o <= oldctx_memaddr_o;
        ctxret_o <= ctxret_o;
        ctx_memaddr_o <= ctx_memaddr_o;
        task_priority_o <= task_priority_o;
        heap_o <= heap_o;

    end else begin
        ctx_o <= ctxop;
        newctx_memaddr_o <= rs1_i; 
        oldctx_memaddr_o <= rs2_i;
        ctxret_o <= ctxret;
        ctx_memaddr_o <= rs1_i;
        task_priority_o <= rs2_i;
        heap_o <= heapop;
    end
end
endmodule
