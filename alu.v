`define ALUOp_nop 5'b00000

`define ALUOp_sll 5'b00001
`define ALUOp_srl 5'b00010
`define ALUOp_sra 5'b00101

`define ALUOp_add 5'b00011
`define ALUOp_sub 5'b00110

`define ALUOp_and  5'b01111
`define ALUOp_or   5'b01011
`define ALUOp_xor  5'b01001
`define ALUOp_slt  5'b00111
`define ALUOp_sltu 5'b01010

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
        `ALUOp_sll:  C = A << B[4:0];
        `ALUOp_srl:  C = $unsigned(A) >> B[4:0];
        `ALUOp_sra:  C = A >>> B[4:0];
        `ALUOp_add:  C = A + B;
        `ALUOp_sub:  C = A - B;
        `ALUOp_and:  C = A & B;
        `ALUOp_or:   C = A | B;
        `ALUOp_xor:  C = A ^ B;
        `ALUOp_slt:  C = (A < B) ? 32'd1 : 32'd0;
        `ALUOp_sltu: C = ($unsigned(A) < $unsigned(B)) ? 32'd1 : 32'd0;
        // 分支：C=0 → Zero=1 → 跳转
        `ALUOp_beq:  C = {31'b0, (A != B)};                  // Zero=1 when A==B
        `ALUOp_bne:  C = {31'b0, (A == B)};                  // Zero=1 when A!=B
        `ALUOp_blt:  C = {31'b0, (A >= B)};                  // Zero=1 when A<B (signed)
        `ALUOp_bge:  C = {31'b0, (A < B)};                   // Zero=1 when A>=B (signed)
        `ALUOp_bltu: C = {31'b0, ($unsigned(A) >= $unsigned(B))}; // Zero=1 when A<B (unsigned)
        `ALUOp_bgeu: C = {31'b0, ($unsigned(A) <  $unsigned(B))}; // Zero=1 when A>=B (unsigned)
        default:     C = 32'b0;
    endcase
    Zero = (C == 0) ? 1 : 0;
end
endmodule