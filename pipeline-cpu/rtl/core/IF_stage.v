`include "definition.vh"
module IF_stage(
    input  wire        clk,
    input  wire        reset,

    // 握手与总线
    input  wire        ID_allowin,
    output wire        IF_to_ID_valid,
    output wire [`IF_TO_ID_WD-1:0] IF_to_ID_bus,

    // IM 接口
    output wire [31:0] instr_address,
    input  wire [31:0] instr,

    // 控制流反馈 (分支预测失败/冲刷)
    input  wire        Branch_taken,
    input  wire [31:0] Branch_target_address
);

endmodule