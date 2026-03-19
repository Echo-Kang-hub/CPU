`ifndef __PIPELINE_TOP_V__
`define __PIPELINE_TOP_V__
`include "definition.vh"
`include "IF_stage.v"
`include "ID_stage.v"
`include "EX_stage.v"
`include "MA_stage.v"
`include "WB_stage.v"
module pipeline_top(
    input  wire        clk,
    input  wire        reset,

    output wire [31:0] instr_addr,
    input  wire [31:0] instr,

    output wire [31:0] DM_write_addr,
    output wire [31:0] DM_write_data,
    output wire        DM_write_enable,
    output wire [2:0]  DM_Type, 
    input  wire [31:0] DM_read_data,

    input wire [4:0]  reg_sel,
    output wire [31:0] reg_data
);


    wire IF_to_ID_valid;
    wire [`IF_to_ID_BUS_WIDTH-1:0] IF_to_ID_bus;
    wire ID_allowin;

    wire ID_to_EX_valid;
    wire [`ID_to_EX_BUS_WIDTH-1:0] ID_to_EX_bus;
    wire EX_allowin;

    wire EX_to_MA_valid;
    wire [`EX_to_MA_BUS_WIDTH-1:0] EX_to_MA_bus;
    wire MA_allowin;

    wire MA_to_WB_valid;
    wire [`MA_to_WB_BUS_WIDTH-1:0] MA_to_WB_bus;
    wire WB_allowin;

    // WB -> ID (寄存器写回)
    wire        RF_write_enable;
    wire [4:0]  RF_write_addr;
    wire [31:0] RF_write_data;

    // ID -> IF (分支跳转)
    wire        Branch_taken;
    wire [31:0] Branch_target_addr;
    wire        Jal_taken;
    wire [31:0] Jal_target_addr;
    wire        Jalr_taken;
    wire [31:0] Jalr_target_addr;

    // forwarding
    wire EXMA_RegWrite;
    wire [4:0]  EXMA_rd;
    wire [31:0] EXMA_aluout;

    wire MAWB_RegWrite;
    wire [4:0]  MAWB_rd;
    wire [31:0] MAWB_aluout;

    // hazard detection
    wire IDEX_MemRead; 
    wire [4:0] IDEX_rd;
    wire Flush_IFID;


    IF_stage u_IF_stage(
        .clk                (clk),
        .reset              (reset),
        
        .ID_allowin         (ID_allowin),
        
        .instr_addr         (instr_addr),
        .instr              (instr),
        
        .Branch_taken       (Branch_taken),
        .Branch_target_addr (Branch_target_addr),
        .Jal_taken          (Jal_taken),
        .Jal_target_addr    (Jal_target_addr),
        .Jalr_taken         (Jalr_taken),
        .Jalr_target_addr   (Jalr_target_addr),
        
        .IF_to_ID_valid     (IF_to_ID_valid),
        .IF_to_ID_bus       (IF_to_ID_bus)
    );

    ID_stage u_ID_stage(
        .clk                (clk),
        .reset              (reset),
        
        .IF_to_ID_valid     (IF_to_ID_valid),
        .IF_to_ID_bus       (IF_to_ID_bus),
        .ID_allowin         (ID_allowin),
        
        .EX_allowin         (EX_allowin),
        .ID_to_EX_valid     (ID_to_EX_valid),
        .ID_to_EX_bus       (ID_to_EX_bus),
        
        .WB_RF_write_enable (RF_write_enable),
        .WB_RF_write_addr   (RF_write_addr),
        .WB_RF_write_data   (RF_write_data),
        
        .Branch_taken       (Branch_taken),
        .Branch_target_addr (Branch_target_addr),
        .Jal_taken          (Jal_taken),
        .Jal_target_addr    (Jal_target_addr),
        .Jalr_taken         (Jalr_taken),
        .Jalr_target_addr   (Jalr_target_addr),

        .EXMA_RegWrite      (EXMA_RegWrite),
        .EXMA_rd            (EXMA_rd),
        .EXMA_aluout        (EXMA_aluout),

        .MAWB_RegWrite      (MAWB_RegWrite),
        .MAWB_rd            (MAWB_rd),
        .MAWB_aluout        (MAWB_aluout),

        .IDEX_MemRead       (IDEX_MemRead),
        .IDEX_rd            (IDEX_rd),
        .FLUSH_IFID         (Flush_IFID),

        .reg_sel            (reg_sel),
        .reg_data           (reg_data)
    );

    EX_stage u_EX_stage(
        .clk                (clk),
        .reset              (reset),
        
        .ID_to_EX_valid     (ID_to_EX_valid),
        .ID_to_EX_bus       (ID_to_EX_bus),
        .EX_allowin         (EX_allowin),
        
        .MA_allowin         (MA_allowin),
        .EX_to_MA_valid     (EX_to_MA_valid),
        .EX_to_MA_bus       (EX_to_MA_bus),

        .EXMA_RegWrite     (EXMA_RegWrite),
        .EXMA_rd            (EXMA_rd),
        .EXMA_aluout        (EXMA_aluout),

        .MAWB_RegWrite     (MAWB_RegWrite),
        .MAWB_rd            (MAWB_rd),
        .MAWB_aluout        (MAWB_aluout),

        .IDEX_MemRead       (IDEX_MemRead),
        .IDEX_rd            (IDEX_rd)
    );

    MA_stage u_MA_stage(
        .clk                (clk),
        .reset              (reset),
        
        .EX_to_MA_valid     (EX_to_MA_valid),
        .EX_to_MA_bus       (EX_to_MA_bus),
        .MA_allowin         (MA_allowin),
        
        .WB_allowin         (WB_allowin),
        .MA_to_WB_valid     (MA_to_WB_valid),
        .MA_to_WB_bus       (MA_to_WB_bus),
        
        .DMType            (DM_Type),
        .DM_write_addr      (DM_write_addr),
        .DM_write_data      (DM_write_data),
        .DM_write_enable    (DM_write_enable),
        .DM_read_data       (DM_read_data),

        .EXMA_RegWrite     (EXMA_RegWrite),
        .EXMA_rd            (EXMA_rd),
        .EXMA_aluout        (EXMA_aluout)
    );

    WB_stage u_WB_stage(
        .clk                (clk),
        .reset              (reset),
        
        .MA_to_WB_valid     (MA_to_WB_valid),
        .MA_to_WB_bus       (MA_to_WB_bus),
        .WB_allowin         (WB_allowin),
        
        .RF_write_enable_out(RF_write_enable),
        .RF_write_addr_out  (RF_write_addr),
        .RF_write_data_out  (RF_write_data),

        .MAWB_RegWrite     (MAWB_RegWrite),
        .MAWB_rd            (MAWB_rd),
        .MAWB_aluout        (MAWB_aluout)
    );

endmodule
`endif 