`include "defines.v"

module mem(
    input wire rst_i,
    input wire clk_i,
    //from pipectrl
    input wire stall_i,
    input wire flush_i,
    //from exe 
    input wire [`XLEN-1:0] pc_i,
    input wire [4:0] rd_addr_i,
    input wire [`XLEN-1:0] rd_data_i,
    input wire rd_we_i,
    input wire [`XLEN-1:0] mem_addr_i,
    input wire mem_re_i,
    input wire mem_we_i,
    input wire [2:0] opfunc3_i,
    input wire [11:0] csr_addr_i,
    input wire [`XLEN-1:0] csr_data_i,
    input wire csr_we_i, 
    input wire system_ret_i,
    input wire [`XLEN-1:0] exception_i,
    input wire [`XLEN-1:0] exceptionpc_i,
    //----------------from heap
    input [11:0] heapcsr_addr_i,
    input [31:0] heapcsr_data_i,
    //from ram
    input wire [`XLEN-1:0] ram_data_i,
    //to ram 
    output reg [`XLEN-1:0] ram_addr_o,
    output reg [`XLEN-1:0] ram_data_o,
    output reg ram_we_o,
    output reg ram_re_o,
    //to wb & forwarding
    output reg [4:0]rd_addr_o,
    output reg [`XLEN-1:0] rd_data_o,
    output reg rd_we_o,
    output reg [11:0] csr_addr_o,
    output reg [`XLEN-1:0] csr_data_o,
    output reg csr_we_o,
    //to csr 
    output reg [`XLEN-1:0] pc_o,
    output reg system_ret_o,
    output reg [`XLEN-1:0] exception_o,
    output reg [`XLEN-1:0] exceptionpc_o,
    //to pipectrl
    output reg stall_o
);

//for csr_data
reg[31:0] csr_data;
assign pc_o = pc_i; //interrupt pc
assign system_ret_o = system_ret_i; //system_ret 
assign exception_o = exception_i;
assign exceptionpc_o = exceptionpc_i;

wire[1:0] ram_addr_offset;
assign ram_addr_offset = mem_addr_i[1:0] & 2'b11; //0,1,2,3
assign ram_re_o = mem_re_i & (S == S_DONE);
assign ram_we_o = mem_we_i & (S == S_DONE);
reg [`XLEN-1:0] rd_data;

//stall 5 clk
assign stall_o = ((mem_re_i|mem_we_i) & ~is_done)? 1:0;


always@(*) begin
    if(mem_re_i)begin
        ram_addr_o = mem_addr_i;
        case(opfunc3_i)
            3'b000:begin //LB
                case(ram_addr_offset)
                    2'b00:rd_data = {{24{ram_data_i[7]}}, ram_data_i[7:0]};
                    2'b01:rd_data = {{24{ram_data_i[15]}}, ram_data_i[15:8]};
                    2'b10:rd_data = {{24{ram_data_i[23]}}, ram_data_i[23:16]};
                    2'b11:rd_data = {{24{ram_data_i[31]}}, ram_data_i[31:24]};
                endcase
            end
            3'b001:begin //LH
                case(ram_addr_offset)
                    2'b00:rd_data = {{16{ram_data_i[15]}}, ram_data_i[15:0]};
                    2'b10:rd_data = {{16{ram_data_i[31]}}, ram_data_i[31:16]};
                    default:rd_data = 0;
                endcase
            end
            3'b010:begin //LW
                rd_data = ram_data_i;
            end
            3'b100:begin //LBU
                case(ram_addr_offset)
                    2'b00:rd_data = {24'b0, ram_data_i[7:0]};
                    2'b01:rd_data = {24'b0, ram_data_i[15:8]};
                    2'b10:rd_data = {24'b0, ram_data_i[23:16]};
                    2'b11:rd_data = {24'b0, ram_data_i[31:24]};
                endcase
            end
            3'b101:begin //LHU
                case(ram_addr_offset)
                    2'b00:rd_data = {16'b0, ram_data_i[15:0]};
                    2'b10:rd_data = {16'b0, ram_data_i[31:16]};
                    default:rd_data = 0;
                endcase
            end 
            default:begin
                rd_data = rd_data_i;
                ram_addr_o = 0;
            end
        endcase
    end else begin
        rd_data = rd_data_i;
        ram_addr_o = 0;
    end
end

// reg [`XLEN-1:0] ram_addr;
// reg [`XLEN-1:0] ram_data; 

always @(*) begin
    if(mem_we_i & (S == S_DONE)) begin
        ram_addr_o = mem_addr_i;
        case(opfunc3_i)
            3'b000:begin //SB
                case(ram_addr_offset)
                    2'b00:ram_data_o = {ram_data_i[31:8],rd_data_i[7:0]};
                    2'b01:ram_data_o = {ram_data_i[31:16],rd_data_i[7:0], ram_data_i[7:0]};
                    2'b10:ram_data_o = {ram_data_i[31:24],rd_data_i[7:0], ram_data_i[15:0]};
                    2'b11:ram_data_o = {rd_data_i[7:0],ram_data_i[23:0]};
                endcase
            end
            3'b001:begin //SH
                case(ram_addr_offset)
                    2'b00:ram_data_o = {ram_data_i[31:16],rd_data_i[15:0]};
                    2'b10:ram_data_o = {rd_data_i[15:0],ram_data_i[15:0]};
                    default:ram_data_o = 0;
                endcase
            end
            3'b010:begin //SW
                ram_data_o = rd_data_i;
            end
            default:begin
                ram_addr_o = 0;
                ram_data_o = 0;
            end
        endcase
    end
end

// always @(posedge clk_i) begin
//     if(mem_we_i & S == S_DONE)begin
//         ram_data_o <= ram_data;
//     end
// end

wire cnt_done;
assign cnt_done = ~|cnt;
reg is_done;
reg  [2:0]     cnt;

// ================================================================================
// Finite State Machine
//
localparam           S_IDLE        = 3'b000;
localparam           S_CALC        = 3'b001;
localparam           S_DONE        = 3'b011;
reg [2 : 0] S, S_nxt;

always @(posedge clk_i)
begin
    if (rst_i|~(mem_re_i|mem_we_i))
        S <= S_IDLE;
    else
        S <= S_nxt;
end

always @(*)
begin
    case (S)
        S_IDLE:
            S_nxt =  S_CALC;
        S_CALC:
            S_nxt = (cnt_done)? S_DONE : S_CALC;
        S_DONE:
            S_nxt = S_IDLE;
        default:
            S_nxt = S_IDLE;
    endcase
end

// ================================================================================
// Computation
//

always @(posedge clk_i)
begin
    if (S == S_IDLE && (mem_re_i|mem_we_i) ==1'b1)begin
        cnt <= 'd3;
    end
    else if (S == S_CALC)begin
        cnt <= cnt - 'd1;
    end
end

always @(*)begin
    if (S == S_DONE) begin
        is_done = 1'b1;
    end else begin
        is_done = 1'b0;
    end
end
//csrhepppppppppppppppppppppppppppppppppp
always @(*)begin
    if (csr_addr_i == heapcsr_addr_i) begin
        csr_data = heapcsr_data_i;
    end else begin
        csr_data = csr_data_i;
    end
end

always @(posedge clk_i) begin
    if(rst_i | flush_i) begin
        rd_addr_o <= 0;
        rd_data_o <= 0;
        rd_we_o <= 0;
        csr_addr_o <= 0;
        csr_data_o <= 0;
        csr_we_o <= 0;
    end else if (stall_i)begin
        rd_addr_o <= rd_addr_o;
        rd_data_o <= rd_data_o;
        rd_we_o <= rd_we_o ;
        csr_addr_o <= csr_addr_o;
        csr_data_o <= csr_data_o;
        csr_we_o <= csr_we_o; 
    end else begin
        rd_addr_o <= rd_addr_i;
        rd_data_o <= rd_data;
        rd_we_o <= rd_we_i ;
        csr_addr_o <= csr_addr_i;
        csr_data_o <= csr_data;
        csr_we_o <= csr_we_i;
    end 
    
end
endmodule
