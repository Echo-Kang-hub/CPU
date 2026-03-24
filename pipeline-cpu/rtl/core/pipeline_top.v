`ifndef __PIPELINE_TOP_V__
`define __PIPELINE_TOP_V__
`include "definition.vh"
`include "IF_stage.v"
`include "ID_stage.v"
`include "EX_stage.v"
`include "MA_stage.v"
`include "WB_stage.v"
`include "csr.v"
`include "interrupt_ctrl.v"

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

    // I/O interface
    input  wire [31:0] io_rdata,
    output wire        io_rd_en,
    output wire        io_wr_en,
    output wire [31:0] io_addr,

    // External interrupt
    input  wire        external_int,

    // PS/2 interface
    input  wire        ps2_clk,
    input  wire        ps2_data,

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
    wire [31:0] MAWB_RF_write_data;

    // hazard detection
    wire IDEX_MemRead; 
    wire IDEX_RegWrite;
    wire [4:0] IDEX_rd;
    wire EXMA_MemRead;
    wire Flush_IFID;
    wire stall;

    // CSR signals
    wire        CSR_we;
    wire [2:0]  CSR_op;
    wire [11:0] CSR_addr;
    wire [31:0] CSR_wdata;
    wire        is_csr;
    wire [31:0] CSR_rdata;
    wire [31:0] CSR_result;
    
    // Interrupt signals
    wire        int_taken;
    wire [31:0] int_pc;
    wire        int_pending;
    wire        mret_taken;
    wire [31:0] mepc_out;
    wire [31:0] mtvec_out;
    
    // System instruction signals
    wire        is_mret;
    wire        is_ecall;
    wire        is_ebreak;
    
    // CSR register values
    wire        mstatus_mie;
    wire        mie_meie;
    wire        mip_meip;
    
    // PS/2 signals
    wire [31:0] ps2_rdata;
    wire        ps2_int;
    
    // Interrupt controller signals
    wire        int_flush_ifid;
    wire        int_flush_idex;


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
        
        // Interrupt interface
        .int_taken          (int_taken),
        .mtvec_addr         (mtvec_out),
        .mret_taken         (mret_taken),
        .mepc_addr          (mepc_out),
        
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

        // Interrupt interface
        .int_taken          (int_taken),
        .is_mret            (is_mret),
        .is_ecall           (is_ecall),
        .is_ebreak          (is_ebreak),

        .EXMA_RegWrite      (EXMA_RegWrite),
        .EXMA_rd            (EXMA_rd),
        .EXMA_aluout        (EXMA_aluout),

        .MAWB_RegWrite      (MAWB_RegWrite),
        .MAWB_rd            (MAWB_rd),
        .MAWB_RF_write_data (MAWB_RF_write_data),

        .IDEX_MemRead       (IDEX_MemRead),
        .IDEX_RegWrite      (IDEX_RegWrite),
        .IDEX_rd            (IDEX_rd),

        .EXMA_MemRead       (EXMA_MemRead),

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
        .MAWB_RF_write_data (MAWB_RF_write_data),

        .IDEX_MemRead       (IDEX_MemRead),
        .IDEX_RegWrite      (IDEX_RegWrite),
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

        // I/O interface
        .io_rdata           (ps2_rdata),
        .io_rd_en           (io_rd_en),
        .io_wr_en           (io_wr_en),
        .io_addr            (io_addr),

        .EXMA_RegWrite     (EXMA_RegWrite),
        .EXMA_rd            (EXMA_rd),
        .EXMA_aluout        (EXMA_aluout),

        .EXMA_MemRead       (EXMA_MemRead)
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

        // CSR interface
        .CSR_we_out         (CSR_we),
        .CSR_op_out         (CSR_op),
        .CSR_addr_out       (CSR_addr),
        .CSR_wdata_out      (CSR_wdata),
        .is_csr_out         (is_csr),

        .MAWB_RegWrite     (MAWB_RegWrite),
        .MAWB_rd            (MAWB_rd),
        .MAWB_RF_write_data (MAWB_RF_write_data)
    );

    // CSR module
    csr u_csr(
        .clk                (clk),
        .reset              (reset),
        
        // CSR read interface
        .csr_addr           (CSR_addr),
        .csr_rdata          (CSR_rdata),
        
        // CSR write interface
        .csr_we             (CSR_we),
        .csr_op             (CSR_op),
        .csr_wdata          (CSR_wdata),
        .csr_imm            (CSR_addr[4:0]),  // For CSR immediate instructions
        .csr_result         (CSR_result),
        
        // Interrupt interface
        .external_int       (ps2_int),
        .int_taken          (int_taken),
        .int_pc             (int_pc),
        .int_pending        (int_pending),
        
        // MRET interface
        .mret_taken         (mret_taken),
        .mepc_out           (mepc_out)
    );

    // Get mtvec from CSR
    assign mtvec_out = u_csr.mtvec;
    
    // Get mstatus.MIE and mie.MEIE from CSR
    assign mstatus_mie = u_csr.mstatus[3];
    assign mie_meie = u_csr.mie[11];
    assign mip_meip = u_csr.mip[11];

    // Interrupt controller
    interrupt_ctrl u_int_ctrl(
        .clk                (clk),
        .reset              (reset),
        
        // Interrupt sources
        .external_int       (external_int),
        
        // CSR interface
        .mstatus_mie        (mstatus_mie),
        .mie_meie           (mie_meie),
        .mip_meip           (mip_meip),
        
        // Pipeline control
        .int_taken          (int_taken),
        .int_pending        (int_pending),
        
        // Pipeline flush signals
        .branch_taken       (Branch_taken),
        .jal_taken          (Jal_taken),
        .jalr_taken         (Jalr_taken),
        .stall              (stall),
        
        // Current instruction in ID stage
        .id_valid           (IF_to_ID_valid),
        .id_pc              (instr_addr),
        .id_is_mret         (is_mret),
        
        // Output to pipeline
        .flush_ifid         (int_flush_ifid),
        .flush_idex         (int_flush_idex),
        .int_taken_out      (int_taken),
        .int_pc_out         (int_pc)
    );

    // PS/2 keyboard controller
    ps2_ctrl u_ps2_ctrl(
        .clk                (clk),
        .reset              (reset),
        
        // PS/2 interface
        .ps2_clk            (ps2_clk),
        .ps2_data           (ps2_data),
        
        // CPU interface
        .addr               (io_addr),
        .rd_en              (io_rd_en),
        .rdata              (ps2_rdata),
        
        // Interrupt output
        .int_out            (ps2_int)
    );

endmodule
`endif 