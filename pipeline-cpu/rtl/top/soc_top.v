`ifndef __SOC_TOP_V__   
`define __SOC_TOP_V__
`timescale 1ns / 1ps
`ifndef SYNTHESIS
    `include "pipeline_top.v"
    `include "dm.v"
    `include "imem.v"
`endif

module soc_top(
    input  wire        clk,
    input  wire        rstn,
    input  wire [4:0]  reg_sel,
    output wire [31:0] reg_data
);
    wire reset = ~rstn; 
    
    wire [31:0] instr_addr;
    wire [31:0] instr;
    wire [31:0] dm_write_addr;
    wire [31:0] dm_write_data;
    wire        dm_write_enable;
    wire [2:0]  dm_type;
    wire [31:0] dm_read_data;
       
    pipeline_top U_CPU(
        .clk             (clk),
        .reset           (reset),
        .instr_addr      (instr_addr),
        .instr           (instr),
        .DM_write_addr   (dm_write_addr),
        .DM_write_data   (dm_write_data),
        .DM_write_enable (dm_write_enable),
        .DM_Type         (dm_type),
        .DM_read_data    (dm_read_data),
        
        .reg_sel         (reg_sel),
        .reg_data        (reg_data)
    );
         
    imem U_IM ( 
        .a               (instr_addr[8:2]), 
        .spo             (instr)
    );
         
    dmem U_DM(
        .clk             (clk),
        .DMWr            (dm_write_enable),
        .DMType          (dm_type),
        .addr            (dm_write_addr), 
        .din             (dm_write_data),
        .dout            (dm_read_data)
    );
        
endmodule
`endif