`ifndef __HAZARD_DETECT_V__
`define __HAZARD_DETECT_V__
module hazard_detect(
    input wire [4:0] IFID_rs1,
    input wire [4:0] IFID_rs2,

    input wire       IFID_is_branch_jalr,

    // from EX
    input wire       IDEX_MemRead, // load
    input wire       IDEX_RegWrite, // alu
    input wire [4:0] IDEX_rd,
    
    // from MA
    input wire       EXMA_MemRead, // load
    input wire [4:0] EXMA_rd,

    // Flush
    input wire       Branch_taken,
    input wire       Jal_taken,
    input wire       Jalr_taken,
    input wire       mret_taken,
    input wire       interrupt_taken,

    output wire      stall,
    output wire      FLUSH_IFID
);
    wire load_use_stall;
    wire alu_branch_stall;
    wire load_branch_stall;
    // load-use EX=load,ID=use,EX use stall 1T
    assign load_use_stall = IDEX_MemRead && (IDEX_rd != 5'b0) && ((IDEX_rd == IFID_rs1) || (IDEX_rd == IFID_rs2));
    // alu-branch：EX=alu,ID=branch stall 1T
    assign alu_branch_stall = IFID_is_branch_jalr && IDEX_RegWrite && (IDEX_rd != 5'b0) && ((IDEX_rd == IFID_rs1) || (IDEX_rd == IFID_rs2));
    // load-branch:MA=load,ID=branch stall 1T，对于EX=load，ID=use，需阻塞2T，前1T阻塞由load-use实现
    assign load_branch_stall = IFID_is_branch_jalr && EXMA_MemRead && (EXMA_rd != 5'b0) && ((EXMA_rd == IFID_rs1) || (EXMA_rd == IFID_rs2));

    assign stall = load_use_stall || alu_branch_stall || load_branch_stall;
                   
    // 跳转发生，冲刷IF/ID
    // 如果stall，说明数据旧，跳转信号不可信；如果不stall，说明数据可行，跳转信号可信
    assign FLUSH_IFID = !stall && (Branch_taken || Jal_taken || Jalr_taken || mret_taken || interrupt_taken);

endmodule
`endif