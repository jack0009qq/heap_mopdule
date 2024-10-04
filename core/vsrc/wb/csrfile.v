module csrfile (
    input wire clk_i,
    input wire rst_i,
    //from clint 
    input wire timer_irq_i,
    input wire software_irq_i,
    input wire external_irq_i, //no support now
    //from id
    input wire [11:0] csr_raddr_i,
    //from mem
    input wire [`XLEN-1:0] mempc_i,
    input wire system_ret_i,
    input wire [`XLEN-1:0] exception_i,
    input wire [`XLEN-1:0] exceptionpc_i,
    //from wb
    input wire csr_we_i,
    input wire [11:0] csr_waddr_i,
    input wire [`XLEN-1:0] csr_wdata_i,
    //from ctx
    input wire [`XLEN-1:0] ctx_exception_i,
    input wire [`XLEN-1:0] ctx_mscratch_i,
    input wire ctxret_i,
    //from heap
    input wire [31:0] heapctx_i,
    input wire [31:0] heapfullctx_i,
    input wire [31:0] heap_exception_i,
    //to id
    output reg [`XLEN-1:0] csr_rdata_o,
    //to pipectrl
    output reg [`XLEN-1:0] trap_entry_o,
    output reg trap_taken_o,
    output reg [`XLEN-1:0] system_retaddr_o,
    output reg system_ret_o,
    output reg [`XLEN-1:0] ctxret_addr_o,
    output reg ctxret_o
);
//0318 exception
/*
分為兩部分
1.硬體：在csrfile裡mtvec放入trapvector的位置，也可以用位移去做相對應的exception
        然後再把地址傳給pc，之後就會跳到trapvector副程式的地方去做執行
    流程: ctx產生exception送進csrfile
        =>csrfile修改mctxpc
        =>csrfile修改mscratch
        =>把地址放進trap_entry傳入pc
2.作業系統：在trap.c裡把trap_vector的位置寫入mtvec，然後發生exception就會跳進mtvec所存的地址作執行
           在entry.S的trap_vector可以呼叫trap.c的traphandler
*/


//          Machine information Register
`define MVENDORID   12'hF11     //manufacturer id
`define MARCHID     12'hF12     //architecture id
`define MIMPID      12'hF13     //cpu version id
`define MHARTID     12'hF14     //cpu hart id

//              Machine Trap Setup
`define MSTATUS     12'h300     //cpu status
`define MISA        12'h301     //extension support
`define MEDELEG     12'h302     //choose lower mode to handle exception
`define MIDELEG     12'h303     //choose lower mode to handle interrupt
`define MIE         12'h304     //interrupt enable    
`define MTVEC       12'h305     //trap handler base addr
`define MCOUNTEREN  12'h306     //hpm(hardware performance monitor)counter use in lower mode enable

//            Machine Trap Handling
`define MSCRATCH    12'h340     //scratch register
`define MEPC        12'h341     //excepton pc addr
`define MCAUSE      12'h342     //trap cause
`define MTVAL       12'h343     //bad addr or instruction
`define MIP         12'h344     //interrupt pending

//            Machine Counter/Timers
`define MCYCLE      12'hB00     //machine cycle counter
`define MINSTRET    12'hB02     //machine instruction-retired counter
`define MCYCLEH     12'hB80     //upper 32bit of mcycle
`define MINSTRETH   12'hB82     //upper 32bit of minstret

//            User Counter/Timers
`define CYCLE       12'hC00     //cycle counter for RDCYCLE instruction 
`define TIME        12'hC01     //timer for RDTIME instruction         
`define CYCLEH      12'hC80

//Read-Only
wire [`XLEN-1:0] mvendorid = 0;
wire [`XLEN-1:0] marchid = 0;
wire [`XLEN-1:0] mimpid = 0;
wire [`XLEN-1:0] mhartid = 0;
//    
reg [`XLEN-1:0] misa;
wire [1:0]  mxl = 2'b01 ; // machine XLEN
wire [25:0] mextensions = 26'b00000000000001000100000000; // ISA extensions - IM
assign misa = {mxl, 4'b0, mextensions};
//
reg [`XLEN-1:0] mstatus;
reg [`XLEN-1:0] mip; //ok
reg [`XLEN-1:0] mie;
reg [`XLEN-1:0] mtvec;
reg [`XLEN-1:0] mcounteren;
reg [`XLEN-1:0] mscratch; //ok
reg [`XLEN-1:0] mepc;
reg [`XLEN-1:0] mcause;
reg [`XLEN-1:0] mtval;

reg [63:0] mcycle;  //ok
//reg [`XLEN-1:0] medeleg;
//reg [`XLEN-1:0] mideleg;
//reg [63:0] minstret;

//custom
reg [31:0] mctxcause;
`define MCTXCAUSE 12'h7c0
//reg [31:0] ctx_cause; //for write mctxcause 

reg [31:0] mctxpc;
reg [31:0] mctxvec;
//---------------------
reg [31:0] mheapctx;
reg [31:0] mheapfullctx;
//--------------------
reg ctx_taken; 
`define MCTXVEC 12'h7c1
`define MCTXPC 12'h7c2
`define MHEAPCTX 12'h7c3
`define MHEAPFULLCTX 12'h7c4

always @(posedge clk_i) begin //mheapctx
    if (rst_i) begin
        mheapctx <= 0;
    end else if ( heapctx_i != 0 ) begin
        mheapctx <= heapctx_i; 
    end else
        mheapctx <= mheapctx;
end

always @(posedge clk_i) begin //mheapfullctx
    if (rst_i) begin
        mheapfullctx <= 0;
    end else if ( heapfullctx_i != 0 ) begin
        mheapfullctx <= heapfullctx_i; 
    end else
        mheapfullctx <= mheapfullctx;
end


always @(posedge clk_i) begin //mctxpc
    if (rst_i) begin
        mctxpc <= 0;
    end else if (csr_we_i && csr_waddr_i == `MCTXPC) begin
        mctxpc <= csr_wdata_i; 
    end else if (ctx_exception_i != 'd0 & ctx_exception_i != 'd1) begin
        mctxpc <= mempc_i + 4;
    end else if (heap_exception_i == 'd6 || heap_exception_i == 'd7) begin
        mctxpc <= mempc_i + 4;
    end else
        mctxpc <= mctxpc;
end

always @(posedge clk_i) begin //mctxvec
    if (rst_i) begin
        mctxvec <= 0;
    end else if (csr_we_i && csr_waddr_i == `MCTXVEC) begin
        mctxvec <= csr_wdata_i; 
    end else
        mctxvec <= mctxvec;
end

always @(posedge clk_i) begin //mcause
    if (rst_i) begin
        mctxcause <= 0;
    // end else if (ctx_taken) begin
    //     mctxcause <= ctx_cause;
    end else if (csr_we_i && csr_waddr_i == `MCTXCAUSE) begin
        mctxcause <= csr_wdata_i; 
    end else begin
        mctxcause <= mctxcause;
    end
end

//

always @(posedge clk_i) begin //mip
    if (rst_i) begin
        mip <= 0;
// not support S,U mode so can't write now
//    end else if (csr_we_i && csr_waddr_i == `MIP) begin   
//        mip <= csr_wdata_i; 
    end else begin
        mip <= {20'b0, external_irq_i, 3'b0, timer_irq_i, 3'b0, software_irq_i, 3'b0} & mie;
    end
end

always @(posedge clk_i) begin //mie
    if (rst_i) begin
        mie <= 0;
    end else if (csr_we_i && csr_waddr_i == `MIE) begin
        mie <= {20'b0,csr_wdata_i[11],3'b0,csr_wdata_i[7],3'b0,csr_wdata_i[3],3'b0}; //only m_mode
    end else begin
        mie <= mie;
    end
end

always @(posedge clk_i) begin //mcycle
    if (rst_i) begin
        mcycle <= 64'b0;
    end else if (csr_we_i) begin
        case (csr_waddr_i)
            `MCYCLE :
                mcycle [31:0] <= csr_wdata_i;
            `MCYCLEH :
                mcycle [63:32] <= csr_wdata_i;
            default : mcycle <= mcycle;
        endcase
    end else begin
        mcycle <= mcycle + 1;
    end
end

always @(posedge clk_i) begin //mstatus
    if (rst_i) begin
        mstatus <=  {19'b0, 2'b11, 7'b0, 1'b1, 3'b0}; //mpp = 11(always m_mode) ,mie = 1;
    end else if (trap_taken) begin
        mstatus[3] <= 0; //mie = 0
        mstatus[7] <= mstatus[3]; //mpie = mie
    end else if (system_ret_i) begin
        mstatus[3] <= mstatus[7]; //mie = mpie 
        mstatus[7] <= 1; //mpie = 0
    end else if (csr_we_i && csr_waddr_i == `MSTATUS) begin
        mstatus <= csr_wdata_i; 
    end else begin
        mstatus <= mstatus;
    end
end

always @(posedge clk_i) begin //mcause
    if (rst_i) begin
        mcause <= 0;
    end else if (trap_taken) begin
        mcause <= interrupt_cause;
    end else if (csr_we_i && csr_waddr_i == `MCAUSE) begin
        mcause <= csr_wdata_i; 
    end else begin
        mcause <= mcause;
    end
end

always @(posedge clk_i) begin //mtvec
    if (rst_i) begin
        mtvec <= 0;
    end else if (csr_we_i && csr_waddr_i == `MTVEC) begin
        mtvec <= csr_wdata_i; 
    end else begin
        mtvec <= mtvec;
    end
end

always @(posedge clk_i) begin //mtval
    if (rst_i) begin
        mtval <= 0;
    end else if (csr_we_i && csr_waddr_i == `MTVAL) begin
        mtval <= csr_wdata_i; 
    end else begin
        mtval <= mtval;
    end
end

always @(posedge clk_i) begin //mepc
    if (rst_i) begin
        mepc <= 0;
    end else if (exception_i != 0) begin
        mepc <= exceptionpc_i;    
    end else if (trap_taken && (exception_i == 0)) begin
        mepc <= mempc_i;
    end else if (csr_we_i && csr_waddr_i == `MEPC) begin
        mepc <= csr_wdata_i; 
    end else begin
        mepc <= mepc;
    end
end

always @(posedge clk_i) begin //mscratch
    if (rst_i) begin
        mscratch <= 0;
    end else if (ctx_exception_i != 0 & ctx_exception_i != 'd5) begin 
        mscratch <= ctx_mscratch_i;
    end else if (csr_we_i && csr_waddr_i == `MSCRATCH) begin
        mscratch <= csr_wdata_i; 
    end else begin
        mscratch <= mscratch;
    end
end

always @(posedge clk_i) begin //mcounteren
    if (rst_i) begin
        mcounteren <= 0;
    end else if (csr_we_i && csr_waddr_i == `MCOUNTEREN) begin
        mcounteren <= csr_wdata_i; 
    end else begin
        mcounteren <= mcounteren;
    end
end

always @ (*) begin //read
    if ((csr_waddr_i == csr_raddr_i) && (csr_we_i)) begin  // bypass the write port to the read port
        csr_rdata_o = csr_wdata_i;
    end else begin
        case (csr_raddr_i)
            `MVENDORID: csr_rdata_o = mvendorid;

            `MARCHID: csr_rdata_o = marchid;

            `MIMPID: csr_rdata_o = mimpid;

            `MHARTID: csr_rdata_o = mhartid;

            `MISA: csr_rdata_o = misa;

            `MCYCLE, `CYCLE: csr_rdata_o = mcycle[31:0];

            `MCYCLEH, `CYCLEH: csr_rdata_o = mcycle[63:32];

            `MSTATUS: csr_rdata_o = mstatus;

            `MIE: csr_rdata_o = mie;

            `MTVEC: csr_rdata_o = mtvec;

            `MSCRATCH: csr_rdata_o = mscratch;

            `MEPC: csr_rdata_o = mepc;

            `MCAUSE: csr_rdata_o = mcause;

            `MIP: csr_rdata_o = mip;

            `MTVAL: csr_rdata_o = mtval;

            `MCTXCAUSE: csr_rdata_o = mctxcause;

            `MCTXPC: csr_rdata_o = mctxpc;

            `MCTXVEC: csr_rdata_o = mctxvec;

            `MHEAPCTX: csr_rdata_o = mheapctx;

            `MHEAPFULLCTX: csr_rdata_o = mheapfullctx;

            default: csr_rdata_o = 0;
        endcase  
    end 
end 

//--------------        interrupt ctrl       ----------------
reg [`XLEN-1:0] interrupt_cause; //for write mcause
reg [`XLEN-1:0] trap_entry;
reg trap_taken;
wire [`XLEN-1:0] mtvec_base;
assign mtvec_base = {mtvec[31:2],2'b00};

always @(*) begin
    trap_taken = 0;
    ctx_taken = 0; 
    interrupt_cause = 0;
    //ctx_cause = 0;
    trap_entry = 0;
    if (exception_i != 0) begin
        trap_taken = 1;
        interrupt_cause = exception_i;
        trap_entry = mtvec_base;
    end else if (ctx_exception_i != 0 && ctx_exception_i != 1) begin
        ctx_taken = 1; 
        //ctx_cause = ctx_exception_i;
        trap_entry = mctxvec + 4*ctx_exception_i;
    end else if (heap_exception_i != 0 && heap_exception_i == 6) begin
        ctx_taken = 1; 
        //heap_full
        trap_entry = mctxvec + 4*heap_exception_i;
    end else if (heap_exception_i != 0 && heap_exception_i == 7) begin
        ctx_taken = 1; 
        //heap_empty;
        trap_entry = mctxvec + 4*heap_exception_i;
    end else if (mstatus[3] & (exception_i == 0)) begin
        if (external_irq_i & mie[11]) begin
            trap_taken = 1;
            interrupt_cause = {1'b1,27'b0,4'd11};
            trap_entry = (mtvec[1:0] == 2'b00)? mtvec_base:mtvec_base + (interrupt_cause[30:0] << 2);
        end else if (timer_irq_i & mie[7]) begin
            trap_taken = 1;
            interrupt_cause = {1'b1,27'b0,4'd7};
            trap_entry = (mtvec[1:0] == 2'b00)? mtvec_base:mtvec_base + (interrupt_cause[30:0] << 2);
        end else if (software_irq_i & mie[3]) begin
            trap_taken = 1;
            interrupt_cause = {1'b1,27'b0,4'd3};
            trap_entry = (mtvec[1:0] == 2'b00)? mtvec_base:mtvec_base + (interrupt_cause[30:0] << 2);
        end else begin
            trap_taken = 0;
            interrupt_cause = 0;
            trap_entry = 0;
        end
    end 

end

assign trap_taken_o = trap_taken | ctx_taken;
assign trap_entry_o = trap_entry;
assign system_ret_o = system_ret_i;
assign system_retaddr_o = mepc ;
assign ctxret_o = ctxret_i;
assign ctxret_addr_o = mctxpc;

endmodule
