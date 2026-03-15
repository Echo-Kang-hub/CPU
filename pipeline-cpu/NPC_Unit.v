`define NPC_PLUS4 3'b000
`define NPC_BRANCH 3'b001
`define NPC_JUMP 3'b010
`define NPC_JALR 3'b100

module NPC_Unit(
    input [31:0] PC,
    input [2:0] NPCOp,
    input [31:0] IMM,
    input [31:0] aluout,
    output reg [31:0] NPC
);
always @(*) begin
    case(NPCOp)
        `NPC_PLUS4: NPC = PC + 4; // default
        `NPC_BRANCH: NPC = PC + IMM; // branch
        `NPC_JUMP: NPC = PC + IMM; // jal
        `NPC_JALR: NPC = aluout & ~32'h1; // jalr: make sure the last bit is 0
        default: NPC = PC + 4;
    endcase 
end    
endmodule