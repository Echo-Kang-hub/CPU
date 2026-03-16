`include "definition.vh"
module EX_stage(
    input  wire        clk,
    input  wire        reset,

    // 与 ID 的握手
    output wire        EX_allowin,
    input  wire        ID_to_EX_valid,
    input  wire [`ID_TO_EX_WD-1:0] ID_to_EX_bus,

    // 与 MA 的握手
    input wire        MA_allowin,
    output wire        EX_to_MA_valid,
    output wire [`EX_TO_MA_WD-1:0] EX_to_MA_bus,

    // 分支计算结果送回 IF
    output wire        Branch_taken,
    output wire [31:0] Branch_target_address
);

endmodule