`include "definition.vh"
module WB_stage(
    input  wire        clk,
    input  wire        reset,

    // 与 MA 的握手
    output wire                    WB_allowin,
    input  wire                    MA_to_WB_valid,
    input  wire [`MA_TO_WB_WD-1:0] MA_to_WB_bus,

    // 写回数据到 ID 级的 RF (寄存器堆)
    output wire        RF_write_enable,
    output wire [4:0]  RF_write_address
);
endmodule