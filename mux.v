module PC_mux(

);
endmodule

module ALUSrcA_mux(
    input [1:0] ForwardingA,
    input [31:0] RD1,
    input [31:0] imm,
    output [31:0] A
);
    wire [31:0] A = RD1; // 目前没有转发，直接使用RD1
endmodule

module ALUSrcB_mux(
    input [1:0] ForwardingB,
    input [4:0] ALUSrcB,
    input [31:0] RD2,
    input [31:0] imm,
    output [31:0] B
);
    wire [31:0] B = ALUSrcB ? imm : RD2;
endmodule


module WB_mux(

);
endmodule
