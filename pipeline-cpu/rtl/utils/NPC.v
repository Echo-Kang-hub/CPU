`include "definition.vh"

module NPC(
    input wire [31:0]       PC_addr,

    input wire              Branch_taken,
    input wire [31:0]       Branch_target_addr,

    input wire              Jal_taken,
    input wire [31:0]       Jal_target_addr,

    input wire              Jalr_taken,
    input wire [31:0]       Jalr_target_addr,
    
    // Interrupt interface
    input wire              int_taken,       // Interrupt is being taken
    input wire [31:0]       mtvec_addr,      // Trap vector address
    input wire              mret_taken,      // MRET instruction
    input wire [31:0]       mepc_addr,       // Return address from trap
    
    output wire [31:0] NPC_addr
);
    // Priority: Interrupt > MRET > Branch > Jal > Jalr > PC+4
    assign NPC_addr = int_taken    ? mtvec_addr :
                      mret_taken   ? mepc_addr :
                      Branch_taken ? Branch_target_addr :
                      Jal_taken    ? Jal_target_addr :
                      Jalr_taken   ? Jalr_target_addr :
                                     PC_addr + 4;
endmodule