`include "definition.vh"

// ==========================================
// MA 逻辑车间 (自带 EX/MA 寄存器前台)
// ==========================================
module MA_stage(
    input  wire        clk,
    input  wire        reset,

    // 向上半身 (EX 级) 接口
    input  wire        EX_to_MA_valid,
    input  wire [`EX_to_MA_BUS_WIDTH-1:0] EX_to_MA_bus,
    output wire        MA_allowin,

    // 向下半身 (WB 级) 接口
    input  wire        WB_allowin,
    output wire        MA_to_WB_valid,
    output wire [`MA_to_WB_BUS_WIDTH-1:0] MA_to_WB_bus,

    // DM (Data Memory) 接口
    output wire [31:0] DM_addr,
    output wire [31:0] DM_wdata,
    output wire        DM_we,
    input  wire [31:0] DM_rdata
);
    // ==========================================
    // 1. 【前台接待区】: EX/MA 流水线寄存器
    // ==========================================
    reg [`EX_to_MA_BUS_WIDTH-1:0] EX_to_MA_bus_reg;
    reg                       MA_valid;

    wire MA_ready_go = 1'b1; 

    assign MA_allowin = !MA_valid || (MA_ready_go && WB_allowin);
    assign MA_to_WB_valid = MA_valid && MA_ready_go;

    always @(posedge clk) begin
        if (reset) 
            MA_valid <= 1'b0;
        else if (MA_allowin) 
            MA_valid <= EX_to_MA_valid;
    end

    always @(posedge clk) begin
        if (MA_allowin && EX_to_MA_valid) 
            EX_to_MA_bus_reg <= EX_to_MA_bus;
    end

    // ==========================================
    // 2. 【车间干活区】: 访存逻辑
    // ==========================================
    wire [31:0] PC, ALU_result, store_data;
    wire [4:0]  RF_waddr;
    wire        RF_we, MEM_we;
    assign {PC, ALU_result, store_data, RF_waddr, RF_we, MEM_we} = EX_to_MA_bus_reg;

    assign DM_addr  = ALU_result;
    assign DM_wdata = store_data;
    // 极其关键：必须是寄存器里有真实有效的指令，且这是一条写内存指令，才能拉高 DM_we
    assign DM_we    = MEM_we && MA_valid; 

    // TODO: 这里假设还有一根 MEM_to_RF 信号用来控制 WB 级的多路选择器
    // wire MEM_to_RF;

    // ==========================================
    // 3. 【重新打包发车】
    // ==========================================
    assign MA_to_WB_bus = {PC, ALU_result, DM_rdata, RF_waddr, RF_we}; // 加入 MEM_to_RF

endmodule