`ifndef __IF_STAGE_V__   
`define __IF_STAGE_V__
`default_nettype none
`include "definition.vh"

module IF_stage(
    input  wire        clk,
    input  wire        reset,

    input  wire        ID_allowin,  

    output wire [31:0] instr_addr,
    input  wire [31:0] instr,

    // 跳转信息 from ID
    input  wire        Branch_taken,
    input  wire [31:0] Branch_target_addr,
    input  wire        Jal_taken,
    input  wire [31:0] Jal_target_addr,
    input  wire        Jalr_taken,
    input  wire [31:0] Jalr_target_addr,

    // to ID
    output wire        IF_to_ID_valid,
    output wire [`IF_to_ID_BUS_WIDTH-1:0] IF_to_ID_bus,

    // hazard detection
    input  wire        stall
);
    wire [31:0] PC_addr;
    wire [31:0] NPC_addr;

    wire IF_ready_go = ~stall; 

    // PC 的更新条件：本级准备好，且下一级的 IF/ID 寄存器允许写入
    wire PCWrite = IF_ready_go && ID_allowin; // ID阻塞了，IF就不更新PC，即IF阻塞

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
        .NPC_addr           (NPC_addr)
    );

    assign instr_addr     = PC_addr;
    assign IF_to_ID_valid = IF_ready_go; 
    assign IF_to_ID_bus   = {PC_addr, instr}; 

endmodule
`endif