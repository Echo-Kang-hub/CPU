`include "definition.vh"

module NPC(
    input [31:0]       PC_addr,

    input              Branch_taken,
    input [31:0]       Branch_target_addr,

    input              Jal_taken,
    input [31:0]       Jal_target_addr,

    input              Jalr_taken,
    input [31:0]       Jalr_target_addr,
    
    output wire [31:0] NPC_addr
);
    assign NPC_addr = Branch_taken ? Branch_target_addr :
                      Jal_taken    ? Jal_target_addr :
                      Jalr_taken   ? Jalr_target_addr :
                                     PC_addr + 4;
endmodule