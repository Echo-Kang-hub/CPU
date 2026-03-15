`include "definition.vh"

module NPC_Unit(
    input [31:0] PC,
    input [1:0] NPCOp,
    input [31:0] IMM,
    input [31:0] aluout,
    output reg [31:0] NPC
);
always @(*) begin
    case(NPCOp)
        `NPC_PLUS4: NPC = PC + 4; // default
        `NPC_BRANCH: NPC = PC + IMM; // branch
        `NPC_JAL: NPC = PC + IMM; // jal
        `NPC_JALR: NPC = aluout; // jalr
        default: NPC = PC + 4;
    endcase 
end    
endmodule