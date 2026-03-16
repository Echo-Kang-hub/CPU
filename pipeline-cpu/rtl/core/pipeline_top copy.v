`timescale 1ns / 1ps
`include "definition.vh"
`include "IF_stage.v"
`include "ID_stage.v"
`include "EX_stage.v"
`include "MA_stage.v"
`include "WB_stage.v"

// 37条指令
// I0: LUI/AUIPC 2 
// I3: ADDI/SLTI/SLTIU/XORI/ORI/ANDI/SLLI/SRLI/SRAI 9
// I4: ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND 10
// I1: JAL/JALR/BEQ/BNE/BLT/BGE/BLTU/BGEU 8
// I2：LB/LH/LW/LBU/LHU/SB/SH/SW 8

module pipeline_top(
    input  wire        clk,
    input  wire        rstn,

    // Instruction Memory
    output wire [31:0] inst_addr,
    input  wire [31:0] inst_rdata,

    // Data Memory 接口
    output wire        data_we,
    output wire [31:0] data_addr,
    output wire [31:0] data_wdata,
    input  wire [31:0] data_rdata,
    output wire [2:0]  data_type // 可选：用于传 DMType（如字节/半字掩码）
);

    // 内部复位信号（统一为高电平有效或低电平有效，这里假设内部全用高电平复位方便处理）
    wire rst = ~rstn;

    // IF -> ID
    wire                    IF_to_ID_valid;
    wire                    ID_allowin;
    wire [`IF_TO_ID_WD-1:0] IF_to_ID_bus;  // 包含: {PC, Instruction}

    // ID -> EX
    wire                    ID_to_EX_valid;
    wire                    EX_allowin;
    wire [`ID_TO_EX_WD-1:0] ID_to_EX_bus;  // 包含: {PC, ALUOp, RF_rdata1, RF_rdata2, Imm, 各种控制信号...}

    // EX -> MA
    wire                    EX_to_MA_valid;
    wire                    MA_allowin;
    wire [`EX_TO_MA_WD-1:0] EX_to_MA_bus; // 包含: {PC, ALU_Result, RF_rdata2(用于Store), 访存控制信号, 写回控制信号...}

    // MA -> WB
    wire                    MA_to_WB_valid;
    wire                    WB_allowin;
    wire [`MA_TO_WB_WD-1:0] MA_to_WB_bus; // 包含: {PC, ALU_Result, Mem_Read_Data, 写回控制信号...}

    wire        rf_we_from_wb;
    wire [4:0]  rf_waddr_from_wb;
    wire [31:0] rf_wdata_from_wb;

    
    // 冲刷信号 (Flush)
    wire flush_IF; // 例如：预测失败或异常时冲刷取指级
    wire flush_ID; 
    wire flush_EX;
    
    // 分支重定向 (Branch Redirect) - 通常从 EX 或 ID 发出，送给 IF 修正 PC
    wire        br_taken;
    wire [31:0] br_target;

    // 前递数据 (Forwarding) - 送回 ID 级解决 RAW 数据冒险
    wire [31:0] EX_fwd_data;
    wire [31:0] MA_fwd_data;
    wire [31:0] WB_fwd_data;

   
    IF_stage U_IF (
        .clk            (clk),
        .rst            (rst),
        
        // 握手与总线
        .ID_allowin     (ID_allowin),
        .IF_to_ID_valid (IF_to_ID_valid),
        .IF_to_ID_bus   (IF_to_ID_bus),
        
        // IM 接口
        .inst_addr      (inst_addr),
        .inst_rdata     (inst_rdata),
        
        // 控制流反馈 (分支预测失败/冲刷)
        .br_taken       (br_taken),
        .br_target      (br_target),
        .flush          (flush_IF)
    );

    ID_stage U_ID (
        .clk            (clk),
        .rst            (rst),
        
        // 与 IF 的握手
        .ID_allowin     (ID_allowin),
        .IF_to_ID_valid (IF_to_ID_valid),
        .IF_to_ID_bus   (IF_to_ID_bus),
        
        // 与 EX 的握手
        .EX_allowin     (EX_allowin),
        .ID_to_EX_valid (ID_to_EX_valid),
        .ID_to_EX_bus   (ID_to_EX_bus),

        .rf_we_from_wb    (rf_we_from_wb),
        .rf_waddr_from_wb (rf_waddr_from_wb),
        .rf_wdata_from_wb (rf_wdata_from_wb),
        
        // 前递信号输入 (解决数据冒险)
        // .EX_fwd_data    (EX_fwd_data),   // 待接入
        // .MA_fwd_data   (MA_fwd_data),  // 待接入
        // .WB_fwd_data    (WB_fwd_data),   // 待接入
        
        // 冲刷
        .flush          (flush_ID)
    );

    EX_stage U_EX (
        .clk            (clk),
        .rst            (rst),
        
        // 与 ID 的握手
        .EX_allowin     (EX_allowin),
        .ID_to_EX_valid (ID_to_EX_valid),
        .ID_to_EX_bus   (ID_to_EX_bus),
        
        // 与 MA 的握手
        .MA_allowin     (MA_allowin),
        .EX_to_MA_valid(EX_to_MA_valid),
        .EX_to_MA_bus  (EX_to_MA_bus),
        
        // 分支计算结果送回 IF
        .br_taken       (br_taken),
        .br_target      (br_target),
        
        // 前递输出
        .EX_fwd_data    (EX_fwd_data),
        
        // 冲刷
        .flush          (flush_EX)
    );

    MA_stage U_MA (
        .clk            (clk),
        .rst            (rst),
        
        // 与 EX 的握手
        .MA_allowin     (MA_allowin),
        .EX_to_MA_valid(EX_to_MA_valid),
        .EX_to_MA_bus  (EX_to_MA_bus),
        
        // 与 WB 的握手
        .WB_allowin     (WB_allowin),
        .MA_to_WB_valid(MA_to_WB_valid),
        .MA_to_WB_bus  (MA_to_WB_bus),
        
        // DM 接口
        .data_we        (data_we),
        .data_addr      (data_addr),
        .data_wdata     (data_wdata),
        .data_rdata     (data_rdata),
        .data_type      (data_type),
        
        // 前递输出
        .MA_fwd_data   (MA_fwd_data)
    );

    WB_stage U_WB (
        .clk            (clk),
        .rst            (rst),
        
        // 与 MEM 的握手
        .WB_allowin     (WB_allowin),
        .MA_to_WB_valid(MA_to_WB_valid),
        .MA_to_WB_bus  (MA_to_WB_bus),

        // 写回数据到 ID 级的 RF (寄存器堆)
        // 注意：在实际项目中，寄存器堆通常物理上放在 ID 级，但由 WB 级提供写使能和写数据
        .rf_we          (rf_we_from_wb),
        .rf_waddr       (rf_waddr_from_wb),
        .rf_wdata       (rf_wdata_from_wb),
        
        // 前递输出
        .WB_fwd_data    (WB_fwd_data)
    );

    // =========================================================================
    // 4. 冲突控制单元 (Hazard Controller) - 初期可暂不实现，接0即可
    // =========================================================================
    /*
    hazard_ctrl U_HAZARD (
        .br_taken       (br_taken),
        .load_use_hazard(load_use_hazard),
        .flush_if       (flush_IF),
        .flush_id       (flush_ID),
        .flush_ex       (flush_EX)
    );
    */
    assign flush_IF = 1'b0;
    assign flush_ID = 1'b0;
    assign flush_EX = 1'b0;

endmodule