`include "definition.vh"
`timescale 1ns / 1ps

module NPC(
    input wire [31:0]       PC_addr,

    input wire              Branch_taken,
    input wire [31:0]       Branch_target_addr,

    input wire              Jal_taken,
    input wire [31:0]       Jal_target_addr,

    input wire              Jalr_taken,
    input wire [31:0]       Jalr_target_addr,

    input wire              interrupt_taken,
    input wire [31:0]       mtvec_addr,
    
    input wire              mret_taken,
    input wire [31:0]       mret_target_addr,
    
    output wire [31:0] NPC_addr
);
    assign NPC_addr = mret_taken      ? mret_target_addr :
                      interrupt_taken ? mtvec_addr        :
                      Branch_taken    ? Branch_target_addr :
                      Jal_taken       ? Jal_target_addr    :
                      Jalr_taken      ? Jalr_target_addr   :
                                         PC_addr + 4;
endmodule