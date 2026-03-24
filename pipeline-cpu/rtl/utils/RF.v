module RF(
    input wire clk,
    input wire reset,
    input wire RFWrite,
    input wire [4:0] rs1,rs2,rd,
    input wire [31:0] WriteData,
    output wire [31:0] RD1,RD2
);
reg [31:0] regfile[31:0]; // reg [31:0]为数据类型，rf[31:0]为数组，32位宽，32个寄存器

integer i;
always @(negedge clk or posedge reset) begin
    if(reset) begin
        for(i=0;i<32;i=i+1) regfile[i] <= i;
    end
    else if(RFWrite && (rd != 5'd0)) regfile[rd] <= WriteData; // 正常模式下且RegWrite有效，写rd
end

// 读rs1和rs2
assign RD1 = (rs1 != 0) ? regfile[rs1] : 0;
assign RD2 = (rs2 != 0) ? regfile[rs2] : 0;

endmodule