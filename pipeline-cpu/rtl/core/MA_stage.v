`ifndef __MA_STAGE_V__   
`define __MA_STAGE_V__
`default_nettype none
`include "definition.vh"

module MA_stage(
    input  wire        clk,
    input  wire        reset,

    // from EX
    input  wire        EX_to_MA_valid,
    input  wire [`EX_to_MA_BUS_WIDTH-1:0] EX_to_MA_bus,
    output wire        MA_allowin,

    // to WB
    input  wire        WB_allowin,
    output wire        MA_to_WB_valid,
    output wire [`MA_to_WB_BUS_WIDTH-1:0] MA_to_WB_bus,

    // DM
    output wire [31:0] DM_write_addr,
    output wire [31:0] DM_write_data,
    output wire        DM_write_enable,
    input  wire [31:0] DM_read_data
);

    // receive from EX and store
    reg [`EX_to_MA_BUS_WIDTH-1:0] EX_to_MA_bus_reg;
    reg                           MA_valid;

    wire MA_ready_go = 1'b1; 

    assign MA_allowin = !MA_valid || (MA_ready_go && WB_allowin);
    assign MA_to_WB_valid = MA_valid && MA_ready_go;

    always @(posedge clk or posedge reset) begin
        if (reset) 
            MA_valid <= 1'b0;
        else begin
            if (MA_allowin) 
                MA_valid <= EX_to_MA_valid;
            if (MA_allowin && EX_to_MA_valid) 
                EX_to_MA_bus_reg <= EX_to_MA_bus;
        end
            
    end

    wire [31:0] MA_PC_plus_4;
    // MA
    wire [31:0] MA_aluout;
    wire MA_MemWrite;
    wire [2:0]  MA_DMType;
    // WB
    wire [1:0] MA_MemtoReg;
    wire MA_RegWrite;
    wire [4:0]  MA_rd;

    assign {
        MA_aluout, DM_write_data, 
        MA_PC_plus_4,
        MA_MemWrite, MA_DMType,
        MA_MemtoReg, MA_RegWrite, MA_rd} = EX_to_MA_bus_reg;

    assign DM_write_enable    = MA_MemWrite && MA_valid; 
    assign DM_write_addr      = MA_aluout;

    assign MA_to_WB_bus = {
        MA_aluout, // 32
        DM_read_data,  // 32
        MA_PC_plus_4, // 32
        MA_MemtoReg, MA_RegWrite, MA_rd};  // 2 + 1 + 5 = 8

endmodule
`endif