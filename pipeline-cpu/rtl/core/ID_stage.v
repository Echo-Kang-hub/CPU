`include "definition.vh"
module ID_stage(
    input  wire        clk,
    input  wire        reset,

    // 与 IF 的握手
    output wire                    ID_allowin,
    input  wire                    IF_to_ID_valid,
    input  wire [`IF_TO_ID_WD-1:0] IF_to_ID_bus,

    // 与 EX 的握手
    input wire                     EX_allowin,
    output wire                    ID_to_EX_valid,
    output wire [`ID_TO_EX_WD-1:0] ID_to_EX_bus,

    // 接收来自 WB 级的写回信号 (写入寄存器堆)
    input  wire        RF_write_enable,
    input  wire [4:0]  RF_write_address,
    input  wire [31:0] RF_write_data
);

endmodule