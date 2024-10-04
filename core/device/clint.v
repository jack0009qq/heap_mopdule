module clint (
    input wire clk_i,
    input wire rst_i,
    
    input wire req_i,
    input wire we_i,
    input wire [`XLEN-1:0] addr_i, //mtime, msip, mtimecmp
    input wire [`XLEN-1:0] data_i,

    output reg [`XLEN-1:0] data_o,
    //to csr
    output reg timer_irq_o,
    output reg software_irq_o 
);

localparam MSIP_BASE = 16'h0;
localparam MTIMECMP_BASE = 16'h4000;
localparam MTIME_ADDR = 16'hBFF8;
wire [15:0] addr = addr_i [15:0];

reg [`XLEN-1:0] mtime_reg [0:1];
reg [`XLEN-1:0] mtimecmp_reg [0:1];
reg [`XLEN-1:0] msip;
wire [63:0] mtime = {mtime_reg[1] ,mtime_reg[0]};
wire [63:0] mtimecmp = {mtimecmp_reg[1] ,mtimecmp_reg[0]};

//for software interrupt
wire is_msip_addr = (addr == MSIP_BASE); 
//for timer interrupt
wire is_mtime_addr0 = (addr == MTIME_ADDR); 
wire is_mtime_addr1 = (addr == MTIME_ADDR + 16'h4);
wire is_mtimecmp_addr0 = (addr == MTIMECMP_BASE);
wire is_mtimecmp_addr1 = (addr == MTIMECMP_BASE+16'h4);

wire carry = (mtime_reg[0] == 32'hFFFF_FFFF);

always @(*) begin
    if (req_i) begin
        if (is_msip_addr) 
            data_o = msip;
        else if (is_mtimecmp_addr0)
            data_o = mtimecmp_reg[0];
        else if (is_mtimecmp_addr1)
            data_o = mtimecmp_reg[1];
        else if(is_mtime_addr0)
            data_o = mtime_reg[0];
        else if(is_mtime_addr1)
            data_o = mtime_reg[1];
    end else
        data_o = 0;
end

always @(posedge clk_i) begin 
    if (rst_i)begin
        msip <= 32'b0;
        mtime_reg[0] <= 32'b0;
        mtime_reg[1] <= 32'b0;
        mtimecmp_reg[0] <= 32'h0; 
        mtimecmp_reg[1] <= 32'h0;
    end else if (we_i) begin
        if (is_msip_addr)
            msip <= data_i;
        else if (is_mtime_addr0)
            mtime_reg[0] <= data_i;
        else if (is_mtime_addr1)
            mtime_reg[1] <= data_i;
        else if (is_mtimecmp_addr0)
            mtimecmp_reg[0] <= data_i;
        else if (is_mtimecmp_addr1)
            mtimecmp_reg[1] <= data_i;
    end else begin
        mtime_reg[0] <= mtime_reg[0] + 1;
        mtime_reg[1] <= mtime_reg[1] + carry;
    end
end

assign timer_irq_o = (mtime >= mtimecmp) & (| mtimecmp);
assign software_irq_o = | msip;

endmodule
