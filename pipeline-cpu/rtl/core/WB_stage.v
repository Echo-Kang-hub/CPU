`include "definition.vh"

// ==========================================
// WB 逻辑车间 (自带 MA/WB 寄存器前台)
// ==========================================
module WB_stage(
    input  wire        clk,
    input  wire        reset,

    // 向上半身 (MA 级) 接口
    input  wire        MA_to_WB_valid,
    input  wire [`MA_to_WB_BUS_WIDTH-1:0] MA_to_WB_bus,
    output wire        WB_allowin,

    // 直接输出给 ID 级的 RF 端口
    output wire        RF_we_out,
    output wire [4:0]  RF_waddr_out,
    output wire [31:0] RF_wdata_out
);
    // ==========================================
    // 1. 【前台接待区】: MA/WB 流水线寄存器
    // ==========================================
    reg [`MA_to_WB_BUS_WIDTH-1:0] MA_to_WB_bus_reg;
    reg                       MA_to_WB_valid;

    wire WB_ready_go = 1'b1;

    // WB 是流水线最后一棒，它之后就是物理的 RF 了，所以它总是允许写入
    assign WB_allowin = !MA_to_WB_valid || WB_ready_go; 

    always @(posedge clk) begin
        if (reset) 
            MA_to_WB_valid <= 1'b0;
        else if (WB_allowin) 
            MA_to_WB_valid <= MA_to_WB_valid;
    end

    always @(posedge clk) begin
        if (WB_allowin && MA_to_WB_valid) 
            MA_to_WB_bus_reg <= MA_to_WB_bus;
    end

    // ==========================================
    // 2. 【车间干活区】: 写回数据选择
    // ==========================================
    wire [31:0] PC, ALU_result, DM_rdata;
    wire [4:0]  RF_waddr;
    wire        RF_we, MEM_to_RF; 
    
    // 拆包
    assign {PC, ALU_result, DM_rdata, RF_waddr, RF_we, MEM_to_RF} = MA_to_WB_bus_reg;

    // 真正的写入使能：指令本身要求写 RF，并且当前 WB 级里的指令是有效的
    assign RF_we_out    = RF_we && MA_to_WB_valid; 
    assign RF_waddr_out = RF_waddr;
    assign RF_wdata_out = MEM_to_RF ? DM_rdata : ALU_result;

endmodule