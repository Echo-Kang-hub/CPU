`timescale 1ns / 1ps
`ifndef SYNTHESIS
  `include "CLK_DIV.v"
  `include "MIO_BUS.v"
  `include "SEG7x16.v"
  `include "imem.v"
  `include "dmem.v"
  `include "pipeline_top.v"
  `include "ps2_keyboard.v"
  `include "vga_display.v"
`endif

module xgriscv_fpga_top(
    input wire    clk,              
    input wire    rstn,             
    input wire [15:0]  sw_i,        
    output wire [7:0]  disp_seg_o,  
    output wire [7:0]  disp_an_o,
    
    // PS/2 keyboard interface
    input wire    ps2_clk,
    input wire    ps2_data,
    
    // VGA output
    output wire [3:0] vga_r,
    output wire [3:0] vga_g,
    output wire [3:0] vga_b,
    output wire       vga_hsync,
    output wire       vga_vsync
);
   
    wire          Clk_CPU;          
    wire [31:0]   instr;            
    wire [31:0]   PC;               
    wire          MemWrite;         
    wire [31:0]   dm_din, dm_dout;  
    wire [31:0]   cpu_data_addr;    
    wire [31:0]   cpu_data_out;     
    wire [31:0]   cpu_data_in;
    wire [2:0]    cpu_data_amp;

    wire          rst = ~rstn;      
    wire [31:0]   seg7_data;        
    wire [6:0]    ram_addr;         
    wire [2:0]    ram_amp;
    wire          ram_we;           
    wire          seg7_we;
    wire [31:0]   cpuseg7_data;
    wire [31:0]   reg_data;

    // Keyboard signals
    wire [7:0]   key_code;
    wire         key_ready;
    wire         key_read;
    wire         key_interrupt;
    
    // VGA signals
    wire [12:0]  vga_addr;
    wire [7:0]   vga_write_data;
    wire         vga_we;

    pipeline_top U_CPU (
        .clk             (Clk_CPU),
        .reset           (rst),
        .instr_addr      (PC),
        .instr           (instr),
        .DM_write_addr   (cpu_data_addr),
        .DM_write_data   (cpu_data_out),
        .DM_write_enable (MemWrite),
        .DM_Type         (cpu_data_amp),
        .DM_read_data    (cpu_data_in),
        .reg_sel         (sw_i[10:6]),
        .reg_data        (reg_data),
        .ext_interrupt   (key_interrupt)
    );

    imem U_IM (
        .a               (PC[8:2]),
        .spo             (instr)
    );

    dmem U_DM (
        .clk             (Clk_CPU),
        .DMWr            (ram_we),
        .DMType          (ram_amp),
        .addr            (ram_addr),
        .din             (dm_din),
        .dout            (dm_dout)
    );

    // I/O management (MIO_BUS)
    MIO_BUS U_MIO (
        .clk           (clk),
        .rst           (rst),
        .sw_i            (sw_i),
        .mem_w           (MemWrite),
        .cpu_data_amp    (cpu_data_amp),
        .cpu_data_addr   (cpu_data_addr),
        .cpu_data_out    (cpu_data_out),
        .ram_data_out    (dm_dout),
        .key_code        (key_code),
        .key_ready       (key_ready),
        .key_read        (key_read),
        .key_interrupt   (key_interrupt),
        .vga_addr        (vga_addr),
        .vga_write_data  (vga_write_data),
        .vga_we          (vga_we),
        .cpu_data_in     (cpu_data_in),
        .ram_data_in     (dm_din),
        .ram_addr        (ram_addr),
        .cpuseg7_data    (cpuseg7_data),
        .ram_we          (ram_we),
        .ram_amp         (ram_amp),
        .seg7_we         (seg7_we)
    );

    // Keyboard controller
    ps2_keyboard U_KBD(
        .clk                   (clk),
        .reset                 (rst),
        .ps2_clk               (ps2_clk),
        .ps2_data              (ps2_data),
        .key_read_acknowledge  (key_read),
        .key_code              (key_code),
        .key_ready             (key_ready)
    );

    // VGA display module
    vga_display U_VGA(
        .clk           (clk),
        .reset         (rst),
        .cpu_addr      (vga_addr),
        .cpu_char      (vga_write_data),
        .cpu_we        (vga_we),
        .vga_r         (vga_r),
        .vga_g         (vga_g),
        .vga_b         (vga_b),
        .vga_hsync     (vga_hsync),
        .vga_vsync     (vga_vsync)
    );

    // Seven segment display
    MULTI_CH32 U_Multi (
        .clk           (clk),
        .rst           (rst),
        .EN            (seg7_we),
        .ctrl          (sw_i[5:0]),
        .Data0         (cpuseg7_data),
        .data1         ({2'b0, PC[31:2]}),
        .data2         (PC),
        .data3         (instr),
        .data4         (cpu_data_addr),
        .data5         (cpu_data_out),
        .data6         (dm_dout),
        .data7         ({23'b0, ram_addr, 2'b00}),
        .reg_data      (reg_data),
        .seg7_data     (seg7_data)
    );

    SEG7x16 U_7SEG(
        .clk           (clk),
        .rst           (rst),
        .cs            (1'b1),
        .i_data        (seg7_data),
        .o_seg         (disp_seg_o),
        .o_sel         (disp_an_o)
    );

    // Clock divider
    CLK_DIV U_CLKDIV(
        .clk           (clk),
        .rst           (rst),
        .SW15          (sw_i[15]),
        .Clk_CPU       (Clk_CPU)
    );

endmodule