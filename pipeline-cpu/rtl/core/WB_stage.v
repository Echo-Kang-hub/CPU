`ifndef __WB_STAGE_V__   
`define __WB_STAGE_V__
`include "definition.vh"
`timescale 1ns / 1ps

module WB_stage(
    input  wire        clk,
    input  wire        reset,

    // from MA
    input  wire        MA_to_WB_valid,
    input  wire [`MA_to_WB_BUS_WIDTH-1:0] MA_to_WB_bus,
    output wire        WB_allowin,

    // to RF
    output wire        RF_write_enable_out,
    output wire [4:0]  RF_write_addr_out,
    output wire [31:0] RF_write_data_out,

    output wire        MAWB_RegWrite,
    output wire [4:0]  MAWB_rd,
    output wire [31:0] MAWB_RF_write_data
);
    reg [`MA_to_WB_BUS_WIDTH-1:0] MA_to_WB_bus_reg;
    reg                           WB_valid;

    wire WB_ready_go = 1'b1;

    assign WB_allowin = !WB_valid || WB_ready_go; 

    always @(posedge clk or posedge reset) begin
        if (reset) 
            WB_valid <= 1'b0;
        else begin
            if (WB_allowin) 
                WB_valid <= MA_to_WB_valid;
            if (WB_allowin && MA_to_WB_valid) 
                MA_to_WB_bus_reg <= MA_to_WB_bus;
        end
    end

    wire [31:0] WB_aluout;
    wire [31:0] WB_DM_read_data;
    wire [31:0] WB_PC_plus_4;
    wire [1:0]  WB_MemtoReg; 
    wire        WB_RegWrite;
    wire [4:0]  WB_rd;
    
    assign {
        WB_aluout, 
        WB_DM_read_data, 
        WB_PC_plus_4,
        WB_MemtoReg, WB_RegWrite, WB_rd} = MA_to_WB_bus_reg;

    assign RF_write_enable_out = WB_valid && WB_RegWrite; 
    assign RF_write_addr_out = WB_rd;

    assign RF_write_data_out = (WB_MemtoReg == `MemtoReg_MEM) ? WB_DM_read_data : 
                               (WB_MemtoReg == `MemtoReg_PC4) ? WB_PC_plus_4 : WB_aluout;

    // forwarding 
    assign MAWB_RegWrite = WB_valid && WB_RegWrite;
    assign MAWB_rd = WB_rd;
    assign MAWB_RF_write_data = RF_write_data_out;

endmodule
`endif