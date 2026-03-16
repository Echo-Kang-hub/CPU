`timescale 1ns / 1ps
`include "definition.vh"
`include "IF_stage.v"
`include "ID_stage.v"
`include "EX_stage.v"
`include "MA_stage.v"
`include "WB_stage.v"

// 37条基本指令
// I0: LUI/AUIPC (2)
// I3: ADDI/SLTI/SLTIU/XORI/ORI/ANDI/SLLI/SRLI/SRAI (9)
// I4: ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND (10)
// I1: JAL/JALR/BEQ/BNE/BLT/BGE/BLTU/BGEU (8)
// I2: LB/LH/LW/LBU/LHU/SB/SH/SW (8)

module pipeline_top(
    input  wire        clk,
    input  wire        rstn,

    // Instruction Memory
    output wire [31:0] instr_address,
    input  wire [31:0] instr,

    // Data Memory
    output wire        dm_write_enable,
    output wire [31:0] dm_address,
    output wire [31:0] dm_write_data,
    input  wire [31:0] dm_read_data,
    output wire [2:0]  dm_type // 可选：用于传 DMType（如字节/半字掩码）
);

    // 内部复位信号（低电平有效转高电平有效）
    wire reset = ~rstn;

    // IF -> ID 阶段
    wire                    IF_to_ID_valid;
    wire                    ID_allowin;
    wire [`IF_TO_ID_WD-1:0] IF_to_ID_bus;  // 包含: {PC, Instruction}

    // ID -> EX 阶段
    wire                    ID_to_EX_valid;
    wire                    EX_allowin;
    wire [`ID_TO_EX_WD-1:0] ID_to_EX_bus;  // 包含: {PC, ALU_Op, RF_read_data1, RF_read_data2, Immediate, 各种控制信号...}

    // EX -> MA 阶段
    wire                    EX_to_MA_valid;
    wire                    MA_allowin;
    wire [`EX_TO_MA_WD-1:0] EX_to_MA_bus;  // 包含: {PC, ALU_Result, RF_read_data2(用于Store), 访存控制, 写回控制...}

    // MA -> WB 阶段
    wire                    MA_to_WB_valid;
    wire                    WB_allowin;
    wire [`MA_TO_WB_WD-1:0] MA_to_WB_bus;  // 包含: {PC, ALU_Result, Memory_read_data, 写回控制...}


    // 写回信号 (从 WB 级倒流回 ID 级的寄存器堆 RF)
    wire        RF_write_enable_from_WB;
    wire [4:0]  RF_write_address_from_WB;
    wire [31:0] RF_write_data_from_WB;
    
    // 冲刷信号 (Flush - 用于清空流水线级里的错误数据)
    wire FLUSH_IF; 
    wire FLUSH_ID; 
    wire FLUSH_EX;
    
    // 分支重定向 (Branch Redirect - 从 EX 或 ID 发出，送回 IF 修正 PC)
    wire        Branch_taken;
    wire [31:0] Branch_target_address;

    // 前递数据 (Forwarding - 提前把算好的数据送回 ID 级解决数据冒险)
    wire [31:0] EX_forwarding_data;
    wire [31:0] MA_forwarding_data;
    wire [31:0] WB_forwarding_data;


    

    // --- 1. 取指级 (Instruction Fetch) ---
    IF_stage U_IF (
        .clk                    (clk),
        .reset                  (reset),
        
        // 握手与总线
        .ID_allowin             (ID_allowin),
        .IF_to_ID_valid         (IF_to_ID_valid),
        .IF_to_ID_bus           (IF_to_ID_bus),
        
        // IM 接口
        .instr_address    (instr_address),
        .instr  (instr),
        
        // 控制流反馈 (分支预测失败/冲刷)
        .Branch_taken           (Branch_taken),
        .Branch_target_address  (Branch_target_address)
        // .FLUSH_IF               (FLUSH_IF)
    );

    // --- 2. 译码级 (Instruction Decode) ---
    ID_stage U_ID (
        .clk                    (clk),
        .reset                  (reset),
        
        // 与 IF 的握手
        .ID_allowin             (ID_allowin),
        .IF_to_ID_valid         (IF_to_ID_valid),
        .IF_to_ID_bus           (IF_to_ID_bus),
        
        // 与 EX 的握手
        .EX_allowin             (EX_allowin),
        .ID_to_EX_valid         (ID_to_EX_valid),
        .ID_to_EX_bus           (ID_to_EX_bus),

        // 接收来自 WB 级的写回信号 (写入寄存器堆)
        .RF_write_enable        (RF_write_enable_from_WB),
        .RF_write_address       (RF_write_address_from_WB),
        .RF_write_data          (RF_write_data_from_WB)
        
        // 前递信号输入 (解决数据冒险)
        // .EX_forwarding_data  (EX_forwarding_data), 
        // .MA_forwarding_data  (MA_forwarding_data),
        // .WB_forwarding_data  (WB_forwarding_data), 
        
        // 冲刷
        // .FLUSH_ID               (FLUSH_ID)
    );

    // --- 3. 执行级 (Execution) ---
    EX_stage U_EX (
        .clk                    (clk),
        .reset                  (reset),
        
        // 与 ID 的握手
        .EX_allowin             (EX_allowin),
        .ID_to_EX_valid         (ID_to_EX_valid),
        .ID_to_EX_bus           (ID_to_EX_bus),
        
        // 与 MA 的握手
        .MA_allowin             (MA_allowin),
        .EX_to_MA_valid         (EX_to_MA_valid),
        .EX_to_MA_bus           (EX_to_MA_bus),
        
        // 分支计算结果送回 IF
        .Branch_taken           (Branch_taken),
        .Branch_target_address  (Branch_target_address)
        
        // // 前递输出
        // .EX_forwarding_data     (EX_forwarding_data),
        
        // // 冲刷
        // .FLUSH_EX               (FLUSH_EX)
    );

    // --- 4. 访存级 (Memory Access) ---
    MA_stage U_MA (
        .clk                    (clk),
        .reset                  (reset),
        
        // 与 EX 的握手
        .MA_allowin             (MA_allowin),
        .EX_to_MA_valid         (EX_to_MA_valid),
        .EX_to_MA_bus           (EX_to_MA_bus),
        
        // 与 WB 的握手
        .WB_allowin             (WB_allowin),
        .MA_to_WB_valid         (MA_to_WB_valid),
        .MA_to_WB_bus           (MA_to_WB_bus),
        
        // DM 接口
        .dm_write_enable (dm_write_enable),
        .dm_address      (dm_address),
        .dm_write_data   (dm_write_data),
        .dm_read_data    (dm_read_data),
        .dm_type         (dm_type)
        
        // // 前递输出
        // .MA_forwarding_data       (MA_forwarding_data)
    );

    // --- 5. 写回级 (Write Back) ---
    WB_stage U_WB (
        .clk                    (clk),
        .reset                  (reset),
        
        // 与 MA 的握手
        .WB_allowin             (WB_allowin),
        .MA_to_WB_valid         (MA_to_WB_valid),
        .MA_to_WB_bus           (MA_to_WB_bus),

        // 写回数据到 ID 级的 RF (寄存器堆)
        .RF_write_enable        (RF_write_enable_from_WB),
        .RF_write_address       (RF_write_address_from_WB),
        .RF_write_data          (RF_write_data_from_WB),
        
        // 前递输出
        .WB_forwarding_data     (WB_forwarding_data)
    );


    // =========================================================================
    // 4. 冲突控制单元 (Hazard Controller) - 初期不实现，接0处理
    // =========================================================================
    
    assign FLUSH_IF = 1'b0;
    assign FLUSH_ID = 1'b0;
    assign FLUSH_EX = 1'b0;

endmodule