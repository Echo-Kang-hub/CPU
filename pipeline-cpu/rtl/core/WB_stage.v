`include "definition.vh"

module WB_stage(
    input  wire        clk,
    input  wire        reset,

    // from MA
    input  wire        MA_to_WB_valid,
    input  wire [`MA_to_WB_BUS_WIDTH-1:0] MA_to_WB_bus,
    output wire        WB_allowin,

    // to RF
    output wire        RF_we_out,
    output wire [4:0]  RF_waddr_out,
    output wire [31:0] RF_wdata_out
);
    // 修正1：重命名有效位寄存器为 WB_valid，避免与输入端口同名
    reg [`MA_to_WB_BUS_WIDTH-1:0] MA_to_WB_bus_reg;
    reg                           WB_valid;

    wire WB_ready_go = 1'b1;

    assign WB_allowin = !WB_valid || WB_ready_go; 

    always @(posedge clk or posedge reset) begin
        if (reset) 
            WB_valid <= 1'b0;
        else begin
            if (WB_allowin) 
                WB_valid <= MA_to_WB_valid; // 修正
            if (WB_allowin && MA_to_WB_valid) 
                MA_to_WB_bus_reg <= MA_to_WB_bus;
        end
    end

    // ==========================================
    // 2. 【车间干活区】: 拆包与写回选择
    // ==========================================
    wire [31:0] WB_DM_read_data;
    wire [31:0] WB_aluout;
    wire [1:0]  WB_WDSel; 
    wire        WB_RegWrite;
    wire [4:0]  WB_rd;
    wire [31:0] WB_PC_plus_4;
    
    // 修正2：拆包顺序必须与 MA 阶段的 assign MA_to_WB_bus 严格对应！
    // MA 里的顺序是：{DM_read_data, MA_aluout, MA_WDSel, MA_RegWrite, MA_rd, MA_PC_plus_4}
    assign {WB_DM_read_data, WB_aluout, WB_WDSel, WB_RegWrite, WB_rd, WB_PC_plus_4} = MA_to_WB_bus_reg;

    assign RF_we_out    = WB_RegWrite && WB_valid; 
    assign RF_waddr_out = WB_rd;

    // 修正3：使用 WDSel 进行多路选择。
    // 暂定：00 选 ALU，01 选 Mem。(后续需要加入 PC+4 和 imm)
    assign RF_wdata_out = (WB_WDSel == 2'b01) ? WB_DM_read_data : WB_aluout;

endmodule