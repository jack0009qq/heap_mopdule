`include "defines.v"

module forwarding (
    //from decode
    input wire [4:0] rs1_addr_i,
    input wire [4:0] rs2_addr_i,
    input wire [`XLEN-1:0] rs1_data_i,
    input wire [`XLEN-1:0] rs2_data_i,

    input wire [11:0] csr_addr_i,
    input wire [`XLEN-1:0] csr_data_i,
    //from exe
    input wire [4:0] exe_rdaddr_i,
    input wire [`XLEN-1:0] exe_rddata_i,
    input wire exe_rdwe,

    input wire [11:0] exe_csraddr_i,
    input wire [`XLEN-1:0] exe_csrdata_i,
    input wire exe_csrwe_i,
    //from heap
    input [11:0] heap_csraddr_i,
    input [31:0] heap_csrdata_i,
    //from mem
    input wire [4:0]mem_rdaddr_i,
    input wire [`XLEN-1:0]mem_rddata_i,
    input wire mem_rdwe,

    input wire [11:0] mem_csraddr_i,
    input wire [`XLEN-1:0] mem_csrdata_i,
    input wire mem_csrwe_i,
    //from wb
    input wire [4:0]wb_rdaddr_i,
    input wire [`XLEN-1:0]wb_rddata_i,
    input wire wb_rdwe,

    input wire [11:0] wb_csraddr_i,
    input wire [`XLEN-1:0] wb_csrdata_i,
    input wire wb_csrwe_i,

    //to exe
    output reg [`XLEN-1:0] rs1_data_o,
    output reg [`XLEN-1:0] rs2_data_o,

    output reg [`XLEN-1:0] csr_data_o
);

wire exeid_addr1_same,exeid_addr2_same,exeid_csr_same;
wire exe_addr_not0;
wire memid_addr1_same,memid_addr2_same,memid_csr_same;
wire mem_addr_not0;
wire wbid_addr1_same,wbid_addr2_same,wbid_csr_same;
wire wb_addr_not0;

assign exeid_addr1_same = (rs1_addr_i == exe_rdaddr_i);
assign exeid_addr2_same = (rs2_addr_i == exe_rdaddr_i);
assign exeid_csr_same = (csr_addr_i == exe_csraddr_i);
assign memid_addr1_same = (rs1_addr_i == mem_rdaddr_i);
assign memid_addr2_same = (rs2_addr_i == mem_rdaddr_i);
assign memid_csr_same = (csr_addr_i == mem_csraddr_i);
assign wbid_addr1_same = (rs1_addr_i == wb_rdaddr_i);
assign wbid_addr2_same = (rs2_addr_i == wb_rdaddr_i);
assign wbid_csr_same = (csr_addr_i == wb_csraddr_i);
//--------------
assign heapid_csr_same = (csr_addr_i == heap_csraddr_i);

assign exe_addr_not0 = (|exe_rdaddr_i);
assign mem_addr_not0 = (|mem_rdaddr_i);
assign wb_addr_not0 = (|wb_rdaddr_i);

wire exedata1_forward,exedata2_forward,execsr_forward;
wire memdata1_forward,memdata2_forward,memcsr_forward;
wire wbdata1_forward,wbdata2_forward,wbcsr_forward;

assign exedata1_forward = (exe_rdwe & exe_addr_not0 & exeid_addr1_same);
assign exedata2_forward = (exe_rdwe & exe_addr_not0 & exeid_addr2_same);
assign execsr_forward = (exe_csrwe_i & exeid_csr_same);
assign memdata1_forward = (mem_rdwe & mem_addr_not0 & memid_addr1_same);
assign memdata2_forward = (mem_rdwe & mem_addr_not0 & memid_addr2_same);
assign memcsr_forward = (mem_csrwe_i & memid_csr_same);
assign wbdata1_forward = (wb_rdwe & wb_addr_not0 & wbid_addr1_same);
assign wbdata2_forward = (wb_rdwe & wb_addr_not0 & wbid_addr2_same);
assign wbcsr_forward = (wb_csrwe_i & wbid_csr_same);
//---------
assign heapcsr_forward = (heapid_csr_same);

always @(*) begin //rs1
    if (exedata1_forward) 
        rs1_data_o = exe_rddata_i; 
    else if (memdata1_forward) 
        rs1_data_o = mem_rddata_i;
    else if (wbdata1_forward) 
        rs1_data_o = wb_rddata_i;
    else 
        rs1_data_o = rs1_data_i;
end

always @(*) begin  //rs2
    if (exedata2_forward) 
        rs2_data_o = exe_rddata_i; 
    else if (memdata2_forward) 
        rs2_data_o = mem_rddata_i;
    else if (wbdata2_forward)
        rs2_data_o = wb_rddata_i;
    else 
        rs2_data_o = rs2_data_i;
end

always @(*) begin //csr 
    if (execsr_forward) 
        csr_data_o = exe_csrdata_i; 
    else if (memcsr_forward) 
        csr_data_o = mem_csrdata_i;
    else if (wbcsr_forward)
        csr_data_o = wb_csrdata_i;
    else if (heapcsr_forward)
        csr_data_o = heap_csrdata_i;
    else 
        csr_data_o = csr_data_i;
end

endmodule
