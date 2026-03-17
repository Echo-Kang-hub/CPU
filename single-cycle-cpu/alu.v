`include "definition.vh"
// I3: ADDI/SLTI/SLTIU/XORI/ORI/ANDI/SLLI/SRLI/SRAI 9
// I4: ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND 10
// I1: JALR/BEQ/BNE/BLT/BGE/BLTU/BGEU 8

module alu(
    input signed [31:0] A,B,
    input [4:0] ALUOp,
    output reg signed [31:0] C,
    output reg Zero
);
    always @(*) begin
        C = 32'b0;
        case(ALUOp)
            `ALUOp_add: C = A + B;
            `ALUOp_sub:  C = A - B;
            `ALUOp_and:  C = A & B;
            `ALUOp_or:   C = A | B;
            `ALUOp_xor:  C = A ^ B;

            `ALUOp_sll: C = A << B[4:0];
            `ALUOp_srl: C = A >> B[4:0];
            `ALUOp_sra: C = A >>> B[4:0];
            `ALUOp_slt:  C = ($signed(A) < $signed(B)) ? 32'b1 : 32'b0;
            `ALUOp_sltu: C = ($unsigned(A) < $unsigned(B)) ? 32'b1 : 32'b0;
            
            `ALUOp_beq: C = {31'b0, (A != B)};
            `ALUOp_bne: C = {31'b0, (A == B)};
            `ALUOp_blt: C = {31'b0, (A >= B)};
            `ALUOp_bge: C = {31'b0, (A < B)};
            `ALUOp_bltu: C = {31'b0, ($unsigned(A) >= $unsigned(B))};
            `ALUOp_bgeu: C = {31'b0, ($unsigned(A) < $unsigned(B))};
            default:C = 32'b0;
        endcase
        Zero = (C == 0)?1:0; // 阻塞赋值，需等C算出来，而不是同步
    end
endmodule