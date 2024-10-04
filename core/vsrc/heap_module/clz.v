module clz(
    input [31:0] rs1_data_i,
    output reg [31:0] clzresult_o
);
    always @(*) begin
        integer i;
        clzresult_o = 0;
        for (i = 31; i >= 0; i = i - 1) begin
            if (rs1_data_i[i] == 1'b1) begin
                clzresult_o = 31 - i;
                break;
            end
        end      
    end
endmodule