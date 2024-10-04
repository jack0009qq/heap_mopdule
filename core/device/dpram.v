`include "defines.v"

module dpram #(
    parameter RAM_SIZE        = 1, //mb
    parameter RAM_ADDR_WIDTH  = 20
)(
    //System Signals
    input wire clk_i,

    //from program counter
    input wire [`XLEN-1:0] addr_i,
    //from mem
    input wire [`XLEN-1:0] ram_addr_i,
    input wire [`XLEN-1:0] ram_data_i,
    input wire ram_we_i,
    input wire ram_req_i,
    //to mem
    output reg [`XLEN-1:0] ram_data_o,
    //to if
    output reg [`XLEN-1:0] inst_o

);

reg[7:0] mem[0:RAM_SIZE-1];
wire[RAM_ADDR_WIDTH-1:0] addr4;
assign addr4 = {addr_i[RAM_ADDR_WIDTH-1:2],2'b0};

wire[RAM_ADDR_WIDTH-1:0] ramaddr4;
assign ramaddr4 = {ram_addr_i[RAM_ADDR_WIDTH-1:2],2'b0};


always @(*) begin  //inst
    inst_o = {mem[addr4],mem[addr4+1],mem[addr4+2],mem[addr4+3]};
end

always @(*) begin //ram load
    if (ram_req_i) begin
        ram_data_o = {mem[ramaddr4],mem[ramaddr4+1],mem[ramaddr4+2],mem[ramaddr4+3]};
    end else begin
        ram_data_o = 0;
    end
end

always @(posedge clk_i) begin //ram write
    if(ram_we_i && ram_req_i)begin
            mem[ramaddr4] <= ram_data_i[31:24];
            mem[ramaddr4+1] <= ram_data_i[23:16]; 
            mem[ramaddr4+2] <= ram_data_i[15:8];
            mem[ramaddr4+3] <= ram_data_i[7:0];
    end
end

task readByte;
    /*verilator public*/
    input integer byte_addr;
    output integer val;
    begin
        val = {24'b0,mem[byte_addr[RAM_ADDR_WIDTH-1:0]]};
    end
endtask    

task writeByte;
        /*verilator public*/
        input integer byte_addr;
        input [7:0] val;
        begin
            mem[byte_addr[RAM_ADDR_WIDTH-1:0]] = val;
        end
    endtask    
endmodule    
