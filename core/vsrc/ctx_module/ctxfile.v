module ctxfile (

input wire clk_i,
input wire rst_i,
//from exe
//指令
input wire [`XLEN-1:0] oldctx_memaddr_i,
input wire [`XLEN-1:0] newctx_memaddr_i,
input wire [1:0] ctx_en_i,
input wire ctxret_i,
//from wb
//Forwarding 
input wire [`XLEN-1:0] fwd_wbregdata_i,
input wire [4:0] fwd_wbregaddr_i,
//from reg
//reg的暫存器  
input wire [`XLEN-1:0] oldctx_data_i [1:31],
//to reg 
output reg [`XLEN-1:0] newctx_data_o [1:31],
output reg ctx_re_o,
//to csr
//為了exception，更改自己設計的csr暫存器??
output reg [`XLEN-1:0] exception_o,
output reg [`XLEN-1:0] mscratch_addr_o,
output reg ctxret_o,
//to pipe_ctrl
//為了stalllllllllll
//發生exception就stall
output reg ctxstall_o
); 
//buferrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr
reg [`XLEN-1:0] ctx0 [0:31]; //for 4 context
reg [`XLEN-1:0] ctx1 [0:31]; //for 4 context
reg [`XLEN-1:0] ctx2 [0:31]; //for 4 context
reg [`XLEN-1:0] ctx3 [0:31]; //for 4 context
//buferrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr
reg [1:0] fifo_count;
reg [1:0] fifo_sel;


wire initialtask;
assign initialtask = (oldctx_memaddr_i == 0) & (ctx_en_i == 2'b11);

wire [3:0] newhit;
wire [3:0] oldhit;
wire [3:0] idlehit;
wire [1:0] newbuf_sel;
wire [1:0] oldbuf_sel;
wire [1:0] idlebuf_sel;
wire newbuf_hit;
wire oldbuf_hit;
wire idlebuf_hit;
//新context命中與否
assign newhit[0] = (newctx_memaddr_i == ctx0[0] & ctx0[0] != 0)? 1:0;
assign newhit[1] = (newctx_memaddr_i == ctx1[0] & ctx1[0] != 0)? 1:0;
assign newhit[2] = (newctx_memaddr_i == ctx2[0] & ctx2[0] != 0)? 1:0;
assign newhit[3] = (newctx_memaddr_i == ctx3[0] & ctx3[0] != 0)? 1:0;
//舊context命中與否
assign oldhit[0] = (oldctx_memaddr_i == ctx0[0] & ctx0[0] != 0)? 1:0;
assign oldhit[1] = (oldctx_memaddr_i == ctx1[0] & ctx1[0] != 0)? 1:0;
assign oldhit[2] = (oldctx_memaddr_i == ctx2[0] & ctx2[0] != 0)? 1:0;
assign oldhit[3] = (oldctx_memaddr_i == ctx3[0] & ctx3[0] != 0)? 1:0;
//ctx buffer是空
assign idlehit[0] = (ctx0[0] == 0)? 1:0;
assign idlehit[1] = (ctx1[0] == 0)? 1:0;
assign idlehit[2] = (ctx2[0] == 0)? 1:0;
assign idlehit[3] = (ctx3[0] == 0)? 1:0;

//選哪一個hit跟hit第幾個buffer
assign newbuf_sel = clog2(newhit);
assign oldbuf_sel = clog2(oldhit);
assign idlebuf_sel = (idlehit[0])? 2'b00:(idlehit[1])? 2'b01:(idlehit[2])? 2'b10:2'b11;
//若有hit則為真
assign newbuf_hit = |newhit;
assign oldbuf_hit = |oldhit;
assign idlebuf_hit = |idlehit;

assign exception_o = (ctx_en_i != 2'b00)? exception:0; 
assign ctxstall_o = (exception_o == 'd1)? 1:0;
assign ctxret_o = ctxret_i;

reg [1:0] writesel;
reg [1:0] readsel;
reg ctx_re;
reg [`XLEN-1:0] exception;

always @(*) begin
    ctx_re = 0;
    readsel = 0;
    exception = 0;  
    mscratch_addr_o = 0;
    if(newbuf_hit & oldbuf_hit) begin //old & new hit
        writesel = oldbuf_sel;
        readsel = newbuf_sel;
        ctx_re = 1;
        exception = 'd1;
        mscratch_addr_o = newctx_memaddr_i;
    end else if (!newbuf_hit & oldbuf_hit) begin //only old hit
        if (ctx_en_i == 2'b10) begin //ctx store
            writesel = oldbuf_sel;
        end else begin
            writesel = oldbuf_sel; 
            exception = 'd2;   //jump to LW
            mscratch_addr_o = newctx_memaddr_i;
        end
    end else if (newbuf_hit & !oldbuf_hit) begin //only new hit
        if (ctx_en_i == 2'b01) begin //ctx load
            writesel = 0;
            readsel = newbuf_sel;
            ctx_re = 1;
            exception = 'd1;
            mscratch_addr_o = newctx_memaddr_i;
        end else if (idlebuf_hit) begin
            writesel = idlebuf_sel;
            readsel = newbuf_sel;
            ctx_re = 1;
            exception = 'd1;
            mscratch_addr_o = newctx_memaddr_i;
        end else begin      
            writesel = (newbuf_sel == fifo_sel)? fifo_sel +1:fifo_sel;  
            readsel = (newbuf_sel == fifo_sel)? fifo_sel +1:fifo_sel; //choose victom to store
            exception = 'd3;  //jump to SW
            mscratch_addr_o = newctx_memaddr_i;
            ctx_re = 1;
        end    
    end else begin      // not hit
        if (initialtask) begin
            writesel = 0;
            exception = 'd2;   //jump to LW
            mscratch_addr_o = newctx_memaddr_i;
        end else if (ctx_en_i == 2'b01)begin  //load miss
            writesel = 0;
            exception = 'd2;   //jump to LW
            mscratch_addr_o = newctx_memaddr_i;
        end else if(ctx_en_i == 2'b10)begin   //store miss
            writesel = (idlebuf_hit)? idlebuf_sel:fifo_sel;
            readsel = (idlebuf_hit)? 0:fifo_sel;
            exception = (idlebuf_hit)? 'd0:'d5; //jump to only SW
            ctx_re = (idlebuf_hit)? 0:1;
        end else if (idlebuf_hit) begin
            writesel = idlebuf_sel;
            exception = 'd2;   //jump to LW
            mscratch_addr_o = newctx_memaddr_i;
        end else begin
            writesel = fifo_sel;
            readsel = fifo_sel;
            exception = 'd4; //jump to SW&LW
            ctx_re = 1;
            mscratch_addr_o = newctx_memaddr_i;
        end
    end 
end

integer i;


always @(posedge clk_i) begin //read new ctx or old ctx to store
    if(ctx_re & ctx_en_i != 2'b00) begin
        ctx_re_o <= ctx_re;
        case(readsel)
            2'b00:begin
                for (i=1;i<31;i=i+1) begin
                    newctx_data_o[i] <= ctx0[i];
                end
                newctx_data_o[31] <= ctx0[0];  //t6 store mem_addr
            end
            2'b01:begin
                for (i=1;i<31;i=i+1) begin
                    newctx_data_o[i] <= ctx1[i];
                end
                newctx_data_o[31] <= ctx1[0];
            end
            2'b10:begin
                for (i=1;i<31;i=i+1) begin
                    newctx_data_o[i] <= ctx2[i];
                end
                newctx_data_o[31] <= ctx2[0];
            end
            2'b11:begin
                for (i=1;i<31;i=i+1) begin
                    newctx_data_o[i] <= ctx3[i];
                end
                newctx_data_o[31] <= ctx3[0];
            end
        endcase       
    end else begin
        ctx_re_o <= 0;
    end
end

always @(posedge clk_i) begin
    fifo_sel <= fifo_count;
end

always @(posedge clk_i) begin
    if (rst_i)
        fifo_count <= 0;
    else if(exception_o == 'd3 | exception_o == 'd4 | exception_o == 'd5)
        fifo_count <= fifo_count + 2'b1;
end

always @(posedge clk_i) begin //initial
    if (rst_i) begin
            ctx_re_o <= 0;
            ctx0[0] <= 0;
            ctx1[0] <= 0;
            ctx2[0] <= 0;
            ctx3[0] <= 0;
    end else if(ctx_en_i[1] == 1'b1 & initialtask == 0) begin //write back old ctx
        case(writesel)
        2'b00: begin
            for (i=1;i<32;i=i+1) begin
                if (i == fwd_wbregaddr_i)
                    ctx0[i] <= fwd_wbregdata_i;
                else
                    ctx0[i] <= oldctx_data_i[i];
            end
            ctx0[0] <= oldctx_memaddr_i;
        end
        2'b01: begin
            for (i=1;i<32;i=i+1) begin
                if (i == fwd_wbregaddr_i)
                    ctx1[i] <= fwd_wbregdata_i;
                else
                    ctx1[i] <= oldctx_data_i[i];
            end
            ctx1[0] <= oldctx_memaddr_i;
        end
        2'b10: begin
            for (i=1;i<32;i=i+1) begin
                if (i == fwd_wbregaddr_i)
                    ctx2[i] <= fwd_wbregdata_i;
                else
                    ctx2[i] <= oldctx_data_i[i];
            end
            ctx2[0] <= oldctx_memaddr_i;
        end
        2'b11: begin
            for (i=1;i<32;i=i+1) begin
                if (i == fwd_wbregaddr_i)
                    ctx3[i] <= fwd_wbregdata_i;
                else
                    ctx3[i] <= oldctx_data_i[i];
            end
            ctx3[0] <= oldctx_memaddr_i;
        end
        endcase
    end
end

function integer clog2 (input integer n); begin 
    n = n - 1;
    for (clog2 = 0; n > 0; clog2 = clog2 + 1)
        n = n >> 1;
    end
endfunction  

endmodule
