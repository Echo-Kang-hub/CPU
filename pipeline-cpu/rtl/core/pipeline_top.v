`timescale 1ns / 1ps
`include "definition.vh"


module pipeline_top(
    input  wire        clk,
    input  wire        rstn,

    // Instruction Memory 接口 (连接到你的 im.v)
    output wire [31:0] inst_addr,
    input  wire [31:0] inst_rdata,

    // Data Memory 接口 (连接到你的 dm.v)
    output wire        data_we,
    output wire [31:0] data_addr,
    output wire [31:0] data_wdata,
    input  wire [31:0] data_rdata,
    output wire [2:0]  data_type // 可选：用于传 DMType（如字节/半字掩码）
);

    // 内部复位信号（统一为高电平有效或低电平有效，这里假设内部全用高电平复位方便处理）
    wire rst = ~rstn;

    // =========================================================================
    // 1. 定义级间握手信号与打包总线 (Packed Buses)
    // =========================================================================
    
    // IF -> ID
    wire                    if_to_id_valid;
    wire                    id_allowin;
    wire [`IF_TO_ID_WD-1:0] if_to_id_bus;  // 包含: {PC, Instruction}

    // ID -> EX
    wire                    id_to_ex_valid;
    wire                    ex_allowin;
    wire [`ID_TO_EX_WD-1:0] id_to_ex_bus;  // 包含: {PC, ALUOp, RF_rdata1, RF_rdata2, Imm, 各种控制信号...}

    // EX -> MEM
    wire                    ex_to_mem_valid;
    wire                    mem_allowin;
    wire [`EX_TO_MEM_WD-1:0]ex_to_mem_bus; // 包含: {PC, ALU_Result, RF_rdata2(用于Store), 访存控制信号, 写回控制信号...}

    // MEM -> WB
    wire                    mem_to_wb_valid;
    wire                    wb_allowin;
    wire [`MEM_TO_WB_WD-1:0]mem_to_wb_bus; // 包含: {PC, ALU_Result, Mem_Read_Data, 写回控制信号...}

    // =========================================================================
    // 2. 定义全局冲突控制与前递信号 (Hazard & Forwarding)
    // =========================================================================
    
    // 冲刷信号 (Flush)
    wire flush_if; // 例如：预测失败或异常时冲刷取指级
    wire flush_id; 
    wire flush_ex;
    
    // 分支重定向 (Branch Redirect) - 通常从 EX 或 ID 发出，送给 IF 修正 PC
    wire        br_taken;
    wire [31:0] br_target;

    // 前递数据 (Forwarding) - 送回 ID 级解决 RAW 数据冒险
    wire [31:0] ex_fwd_data;
    wire [31:0] mem_fwd_data;
    wire [31:0] wb_fwd_data;

    // =========================================================================
    // 3. 实例化 5 个流水级
    // =========================================================================

    // --- 1. 取指级 (Instruction Fetch) ---
    if_stage U_IF (
        .clk            (clk),
        .rst            (rst),
        
        // 握手与总线
        .id_allowin     (id_allowin),
        .if_to_id_valid (if_to_id_valid),
        .if_to_id_bus   (if_to_id_bus),
        
        // IM 接口
        .inst_addr      (inst_addr),
        .inst_rdata     (inst_rdata),
        
        // 控制流反馈 (分支预测失败/冲刷)
        .br_taken       (br_taken),
        .br_target      (br_target),
        .flush          (flush_if)
    );

    // --- 2. 译码级 (Instruction Decode) ---
    id_stage U_ID (
        .clk            (clk),
        .rst            (rst),
        
        // 与 IF 的握手
        .id_allowin     (id_allowin),
        .if_to_id_valid (if_to_id_valid),
        .if_to_id_bus   (if_to_id_bus),
        
        // 与 EX 的握手
        .ex_allowin     (ex_allowin),
        .id_to_ex_valid (id_to_ex_valid),
        .id_to_ex_bus   (id_to_ex_bus),
        
        // 前递信号输入 (解决数据冒险)
        // .ex_fwd_data    (ex_fwd_data),   // 待接入
        // .mem_fwd_data   (mem_fwd_data),  // 待接入
        // .wb_fwd_data    (wb_fwd_data),   // 待接入
        
        // 冲刷
        .flush          (flush_id)
    );

    // --- 3. 执行级 (Execution) ---
    ex_stage U_EX (
        .clk            (clk),
        .rst            (rst),
        
        // 与 ID 的握手
        .ex_allowin     (ex_allowin),
        .id_to_ex_valid (id_to_ex_valid),
        .id_to_ex_bus   (id_to_ex_bus),
        
        // 与 MEM 的握手
        .mem_allowin    (mem_allowin),
        .ex_to_mem_valid(ex_to_mem_valid),
        .ex_to_mem_bus  (ex_to_mem_bus),
        
        // 分支计算结果送回 IF
        .br_taken       (br_taken),
        .br_target      (br_target),
        
        // 前递输出
        .ex_fwd_data    (ex_fwd_data),
        
        // 冲刷
        .flush          (flush_ex)
    );

    // --- 4. 访存级 (Memory) ---
    mem_stage U_MEM (
        .clk            (clk),
        .rst            (rst),
        
        // 与 EX 的握手
        .mem_allowin    (mem_allowin),
        .ex_to_mem_valid(ex_to_mem_valid),
        .ex_to_mem_bus  (ex_to_mem_bus),
        
        // 与 WB 的握手
        .wb_allowin     (wb_allowin),
        .mem_to_wb_valid(mem_to_wb_valid),
        .mem_to_wb_bus  (mem_to_wb_bus),
        
        // DM 接口
        .data_we        (data_we),
        .data_addr      (data_addr),
        .data_wdata     (data_wdata),
        .data_rdata     (data_rdata),
        .data_type      (data_type),
        
        // 前递输出
        .mem_fwd_data   (mem_fwd_data)
    );

    // --- 5. 写回级 (Write Back) ---
    wb_stage U_WB (
        .clk            (clk),
        .rst            (rst),
        
        // 与 MEM 的握手
        .wb_allowin     (wb_allowin),
        .mem_to_wb_valid(mem_to_wb_valid),
        .mem_to_wb_bus  (mem_to_wb_bus),

        // 写回数据到 ID 级的 RF (寄存器堆)
        // 注意：在实际项目中，寄存器堆通常物理上放在 ID 级，但由 WB 级提供写使能和写数据
        // .rf_we          (rf_we_from_wb),
        // .rf_waddr       (rf_waddr_from_wb),
        // .rf_wdata       (rf_wdata_from_wb),
        
        // 前递输出
        .wb_fwd_data    (wb_fwd_data)
    );

    // =========================================================================
    // 4. 冲突控制单元 (Hazard Controller) - 初期可暂不实现，接0即可
    // =========================================================================
    /*
    hazard_ctrl U_HAZARD (
        .br_taken       (br_taken),
        .load_use_hazard(load_use_hazard),
        .flush_if       (flush_if),
        .flush_id       (flush_id),
        .flush_ex       (flush_ex)
    );
    */
    assign flush_if = 1'b0;
    assign flush_id = 1'b0;
    assign flush_ex = 1'b0;

endmodule