`ifndef __IF_STAGE_V__   
`define __IF_STAGE_V__
`include "definition.vh"
`timescale 1ns / 1ps

module IF_stage(
    input  wire        clk,
    input  wire        reset,

    input  wire        ID_allowin,  

    output wire [31:0] instr_addr,
    input  wire [31:0] instr,

    // 跳转信息 from ID
    input  wire        Branch_taken,
    input wire  [31:0] Branch_target_addr,
    input wire         Jal_taken,
    input wire  [31:0] Jal_target_addr,
    input wire         Jalr_taken,
    input wire  [31:0] Jalr_target_addr,

    // interrupt
    input wire         global_interrupt_enable,
    input wire  [31:0] mie,
    input wire  [31:0] mip,
    input wire  [31:0] mtvec,
    input wire         mret_taken,
    input wire  [31:0] mret_target_addr,

    // to ID
    output wire        IF_to_ID_valid,
    output wire [`IF_to_ID_BUS_WIDTH-1:0] IF_to_ID_bus,

    // internal signals
    output wire        interrupt_taken,
    output wire  [31:0] current_PC
);
    wire [31:0] PC_addr;
    wire [31:0] NPC_addr;

    wire IF_ready_go = 1'b1; 

    // PC 的更新条件：本级准备好，且下一级允许写入
    // 中断/mret 时也要更新 PC（跳转到 mtvec/mepc）
    wire PCWrite = IF_ready_go && ID_allowin;

    PC U_PC (
        .clk        (clk), 
        .reset      (reset), 
        .PCWrite    (PCWrite), 
        .NPC_addr   (NPC_addr), 
        .PC_addr    (PC_addr)
    );
    
    NPC U_NPC (
        .PC_addr            (PC_addr),
        .Branch_taken       (Branch_taken),
        .Branch_target_addr (Branch_target_addr),
        .Jal_taken          (Jal_taken),
        .Jal_target_addr    (Jal_target_addr),
        .Jalr_taken         (Jalr_taken),
        .Jalr_target_addr   (Jalr_target_addr),
        .interrupt_taken    (interrupt_taken),
        .mtvec_addr         (mtvec),
        .mret_taken         (mret_taken),
        .mret_target_addr   (mret_target_addr),
        .NPC_addr           (NPC_addr)
    );

    assign instr_addr     = PC_addr;
    assign IF_to_ID_valid = IF_ready_go; 
    assign IF_to_ID_bus   = {PC_addr, instr}; 

// interrupt
    wire ext_interrupt_pending = mie[11] & mip[11] & global_interrupt_enable;
    assign interrupt_taken = ext_interrupt_pending & ID_allowin;
    assign current_PC = PC_addr;

endmodule
`endif