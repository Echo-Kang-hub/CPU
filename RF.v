module RF(
    input clk,
    input rstn,
    input RFWr,
    input [15:0] sw_i,
    input [4:0] A1,A2,A3,
    input [31:0] WD,
    output [31:0] RD1,RD2
);
    reg [31:0] rf[31:0]; // reg [31:0]为数据类型，rf[31:0]为数组，32位宽，32个寄存器

    integer i;
    always @(posedge clk or negedge rstn) begin
        if(!rstn) begin
            for(i=0;i<32;i=i+1) rf[i] <= i;
        end
        else if(RFWr && (!sw_i[1]) && (A3 != 5'd0)) rf[A3] <= WD; // 正常模式下且RegWrite有效，写rd
    end

    // 读rs1和rs2
    assign RD1 = (A1 != 0)?rf[A1]:0;
    assign RD2 = (A2 != 0)?rf[A2]:0;

endmodule