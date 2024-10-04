`include "defines.v"

module soc_top(

input wire clk_i,
input wire rst_i,

output reg halt_o //use for test

);

localparam int NrDevices = 3;
localparam int NrHosts = 1;
localparam int MemSize = 32'h1000000;
localparam int MemAddrWidth = 24;
// localparam int MemSize = 32'h200000;
// localparam int MemAddrWidth = 21;

`define HOST_CORE_PORT 0
`define DEV_RAM 0
`define DEV_CONSOLE 1
`define DEV_CLINT 2

//host signals
wire host_req [NrHosts];
wire host_gnt [NrHosts];
wire [`XLEN-1:0] host_addr [NrHosts];
wire [`XLEN-1:0] host_wdata [NrHosts];
wire [`XLEN-1:0] host_rdata [NrHosts];
wire host_we [NrHosts];

//device signals
wire device_req [NrDevices];
wire [`XLEN-1:0] device_addr[NrDevices];
wire [`XLEN-1:0] device_wdata[NrDevices];
wire [`XLEN-1:0] device_rdata[NrDevices];
wire device_we [NrDevices];

//Device address mapping
wire [`XLEN-1:0] cfg_device_addr_base [NrDevices];
wire [`XLEN-1:0] cfg_device_addr_mask [NrDevices];

// assign cfg_device_addr_base [`DEV_RAM] = 32'h000000;
// assign cfg_device_addr_mask [`DEV_RAM] = ~32'h1FFFFF; // 2 MB
// assign cfg_device_addr_base [`DEV_CONSOLE] = 32'h200000;
// assign cfg_device_addr_mask [`DEV_CONSOLE] = ~32'hFFFFF; // 1 MB
// assign cfg_device_addr_base [`DEV_CLINT] = 32'h2000000;
// assign cfg_device_addr_mask [`DEV_CLINT] = ~32'hFFFF; 

assign cfg_device_addr_base [`DEV_RAM] = 32'h000000;
assign cfg_device_addr_mask [`DEV_RAM] = ~32'hFFFFFF; // 16 MB
assign cfg_device_addr_base [`DEV_CONSOLE] = 32'h1000000;
assign cfg_device_addr_mask [`DEV_CONSOLE] = ~32'hFFFFF; // 1 MB
assign cfg_device_addr_base [`DEV_CLINT] = 32'h2000000;
assign cfg_device_addr_mask [`DEV_CLINT] = ~32'hFFFF; 


//rom & pc
wire[`XLEN-1:0] pcrom_pc;
wire[`XLEN-1:0] rompc_inst;
//console
wire halt_from_console;
assign halt_o = halt_from_console;
//clint
wire clint_software_irq;
wire clint_timer_irq;

wire external_irq = 0 ;

bus #(
    .NrDevices (NrDevices),
    .NrHosts (NrHosts),
    .DataWidth (`XLEN),
    .AddrressWidth (`XLEN)
)u_bus(
    .rst_i (rst_i),

    .host_req_i (host_req),
    .host_addr_i (host_addr),
    .host_we_i (host_we),
    .host_wdata_i (host_wdata),
    .host_rdata_o (host_rdata),
    .host_gnt_o (host_gnt),

    .device_rdata_i (device_rdata),
    .device_req_o (device_req),
    .device_addr_o (device_addr),
    .device_we_o (device_we),
    .device_wdata_o (device_wdata),

    .cfg_device_addr_base,  ///why no need to connect?
    .cfg_device_addr_mask
);

console #(
    .LogName("./log/console.log")  //what ?
    ) console0 (
    .clk_i     (clk_i),
    .rst_i     (rst_i),

    .req_i     (device_req[`DEV_CONSOLE]),
    .we_i      (device_we[`DEV_CONSOLE]),
    .addr_i    (device_addr[`DEV_CONSOLE]),
    .wdata_i   (device_wdata[`DEV_CONSOLE]),
    .halt_o    (halt_from_console)
    );

dpram #(
    .RAM_SIZE (MemSize),
    .RAM_ADDR_WIDTH (MemAddrWidth)
) dpram0 (
    .clk_i(clk_i),
    
    //pc
    .addr_i(pcrom_pc),
    .inst_o(rompc_inst),
    //from core
    .ram_addr_i(device_addr [`DEV_RAM]),
    .ram_data_i(device_wdata [`DEV_RAM]),
    .ram_we_i(device_we [`DEV_RAM]),
    .ram_req_i(device_req [`DEV_RAM]),
    //to core
    .ram_data_o(device_rdata [`DEV_RAM])
);

clint clint0(
    .clk_i(clk_i),
    .rst_i(rst_i),
    //from core
    .we_i(device_we[`DEV_CLINT]),
    .req_i(device_req[`DEV_CLINT]),
    .addr_i(device_addr[`DEV_CLINT]),
    .data_i(device_wdata[`DEV_CLINT]),
    //to core
    .data_o(device_rdata[`DEV_CLINT]),

    .timer_irq_o(clint_timer_irq),
    .software_irq_o(clint_software_irq)
);

coretop coretop0(
    .clk_i(clk_i),
    .rst_i(rst_i),
    //inst
    .rom_addr_o(pcrom_pc),
    .rom_data_i(rompc_inst),
    //ram
    .ram_data_i(host_rdata [`HOST_CORE_PORT]),
    .ram_addr_o(host_addr [`HOST_CORE_PORT]),
    .ram_wdata_o(host_wdata [`HOST_CORE_PORT]),
    .ram_we_o(host_we [`HOST_CORE_PORT]),
    .ram_req_o (host_req [`HOST_CORE_PORT]),

    .timer_irq_i(clint_timer_irq),
    .software_irq_i(clint_software_irq),
    .external_irq_i(external_irq)
);

endmodule
