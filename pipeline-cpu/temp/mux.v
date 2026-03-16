module PC_mux(
    input branch,
    input jump,
    input [31:0] PC,
    input [31:0] PC_IMM,
    input [31:0] aluout,
    output reg [31:0] NPC
);

    always @(*) NPC = PC + 4; // default
    // `define NPC_PLUS4 3'b000
    // `define NPC_BRANCH 3'b001
    // `define NPC_JUMP 3'b010
    // `define NPC_JALR 3'b100

    // always @(*) begin
    //     case(NPCOp)
    //         `NPC_PLUS4: NPC = PC + 4; // default
    //         `NPC_BRANCH: NPC = PC_IMM; // branch
    //         `NPC_JUMP: NPC = PC_IMM; // jal
    //         `NPC_JALR: NPC = aluout & ~32'h1; // jalr: make sure the last bit is 0
    //         default: NPC = PC + 4;
    //     endcase 
    // end    
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
