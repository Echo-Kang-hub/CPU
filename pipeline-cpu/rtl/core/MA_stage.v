`include "definition.vh"
module MA_stage(
    input  wire        clk,
    input  wire        reset,

    // 与 EX 的握手
    output wire                   MA_allowin,
    input wire                    EX_to_MA_valid,
    input wire [`EX_TO_MA_WD-1:0] EX_to_MA_bus,

    // 与 WB 的握手
    input wire                     WB_allowin,
    output wire                    MA_to_WB_valid,
    output wire [`MA_TO_WB_WD-1:0] MA_to_WB_bus,

    // DM 接口
    output wire        dm_write_enable,
    output wire [31:0] dm_address,
    output wire [31:0] dm_write_data,
    input  wire [31:0] dm_read_data,
    output wire [2:0]  dm_type
);
endmodule