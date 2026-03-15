`define ALUOp_nop 5'b00000

`define ALUOp_sll 5'b00001
`define ALUOp_srl 5'b00010
`define ALUOp_sra 5'b00101

`define ALUOp_add 5'b00011

`define ALUOp_beq 5'b00100
`define ALUOp_bne 5'b01000
`define ALUOp_blt 5'b01100
`define ALUOp_bge 5'b10000
`define ALUOp_bltu 5'b10100
`define ALUOp_bgeu 5'b11000

module alu(
    input signed [31:0] A,B,
    input [4:0] ALUOp,
    output reg signed [31:0] C,
    output reg Zero
);
always @(*) begin
    C = 32'b0;
    case(ALUOp)
        `ALUOp_sll: C = A << B[4:0];
        `ALUOp_srl: C = A >> B[4:0];
        `ALUOp_sra: C = A >>> B[4:0];
        `ALUOp_add: C = A + B;
        `ALUOp_beq: C = {31'b0,(A!=B)};
        `ALUOp_bne: C = {31'b0,{A==B}};
        `ALUOp_blt: C = {31'b0,(A>=B)};
        `ALUOp_bge: C = {31'b0,(A<B)};
        `ALUOp_bltu: C = {31'b0,($unsigned(A)>=$unsigned(B))};
        `ALUOp_bgeu: C = {31'b0,{$unsigned(A)<$unsigned(B)}};
        default:C = 32'b0;
    endcase
    Zero = (C == 0)?1:0; // 阻塞赋值，需等C算出来，而不是同步
end
endmodule