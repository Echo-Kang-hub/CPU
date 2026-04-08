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
`timescale 1ns / 1ps

module xgriscv_fpga_top(
    input wire        clk,
    input wire        rstn,
    input wire [15:0] sw_i,
    output wire [7:0] disp_seg_o,
    output wire [7:0] disp_an_o,
    
    // PS/2 keyboard interface
    input wire        ps2_clk,
    input wire        ps2_data,
    
    // VGA output
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b,
    output wire        vga_hsync,
    output wire        vga_vsync
);
   
    wire        Clk_CPU;
    wire [31:0] instr;
    wire [31:0] PC;

    wire        bus_write_enable;
    wire [31:0] bus_write_addr;
    wire [31:0] bus_write_data;
    wire [2:0]  bus_DM_Type;
    wire [31:0] bus_read_data;

    wire        DM_write_enable;
    wire [31:0] DM_write_addr;
    wire [31:0] DM_write_data;
    wire [2:0]  DM_Type;
    wire [31:0] DM_read_data;

    wire        reset = ~rstn;
    wire [31:0] seg7_data;
    wire        seg7_write_enable;
    wire [31:0] cpuseg7_data;
    wire [31:0] reg_data;

    // Keyboard signals
    wire [7:0]  key_code;
    wire        key_ready;
    wire        key_read;
    wire        key_interrupt;
    wire        overflow;

    // Synchronize PS/2 outputs from clk domain into CPU bus domain.
    reg [7:0] key_code_sync0;
    reg [7:0] key_code_sync1;
    reg       key_ready_sync0;
    reg       key_ready_sync1;
    
    // VGA signals
    wire [12:0] vga_addr;
    wire [7:0]  vga_write_data;
    wire        vga_write_enable;

    wire clk_vga;

    always @(posedge Clk_CPU or posedge reset) begin
        if (reset) begin
            key_code_sync0  <= 8'h00;
            key_code_sync1  <= 8'h00;
            key_ready_sync0 <= 1'b0;
            key_ready_sync1 <= 1'b0;
        end else begin
            key_code_sync0  <= key_code;
            key_code_sync1  <= key_code_sync0;
            key_ready_sync0 <= key_ready;
            key_ready_sync1 <= key_ready_sync0;
        end
    end

    pipeline_top U_CPU (
        .clk             (Clk_CPU),
        .reset           (reset),
        .instr_addr      (PC),
        .instr           (instr),
        .bus_write_enable (bus_write_enable),
        .bus_write_addr   (bus_write_addr),
        .bus_write_data   (bus_write_data),
        .bus_DM_Type      (bus_DM_Type),
        .bus_read_data    (bus_read_data),
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
        .DM_write_enable (DM_write_enable),
        .DM_Type         (DM_Type),
        .addr            (DM_write_addr),
        .din             (DM_write_data),
        .dout            (DM_read_data)
    );

    // I/O management (MIO_BUS)
    MIO_BUS U_MIO (
        .clk             (Clk_CPU),
        .reset           (reset),
        .sw_i            (sw_i),
        // from CPU
        .bus_write_enable (bus_write_enable),
        .bus_write_addr   (bus_write_addr),
        .bus_write_data   (bus_write_data),
        .bus_DM_Type      (bus_DM_Type),
        // from DM
        .DM_read_data     (DM_read_data),
        // Keyboard interface
        .key_code        (key_code_sync1),
        .key_ready       (key_ready_sync1),
        .key_read        (key_read),
        .key_interrupt   (key_interrupt),
        // VGA interface
        .vga_addr        (vga_addr),
        .vga_write_data  (vga_write_data),
        .vga_write_enable (vga_write_enable),

        // to CPU
        .bus_read_data    (bus_read_data),
        // to DM
        .DM_write_enable  (DM_write_enable),
        .DM_write_addr        (DM_write_addr),
        .DM_write_data    (DM_write_data),
        .DM_Type          (DM_Type),
        // to SEG7x16
        .cpuseg7_data    (cpuseg7_data),
        .seg7_write_enable (seg7_write_enable)
    );

    // Keyboard controller
    ps2_keyboard U_KBD(
        .clk                   (clk),
        .reset                 (reset),
        .ps2_clk               (ps2_clk),
        .ps2_data              (ps2_data),
        .key_read_acknowledge  (key_read),
        .key_code              (key_code),
        .key_ready             (key_ready),
        .overflow              (overflow)
    );

    // VGA display module
    vga_display U_VGA(
        .vga_clk           (vga_clk),
        .cpu_clk       (Clk_CPU),
        .reset         (reset),
        .vga_write_enable        (vga_write_enable),
        .vga_addr      (vga_addr),
        .vga_write_data  (vga_write_data),
        .vga_r         (vga_r),
        .vga_g         (vga_g),
        .vga_b         (vga_b),
        .vga_hsync     (vga_hsync),
        .vga_vsync     (vga_vsync)
    );
    
    // Seven segment display
    // 添加键盘调试信息
    wire [31:0] debug_data = {8'h0, key_code, 7'h0, key_ready, 7'h0, overflow};
    
    MULTI_CH32 U_Multi (
        .clk           (clk),
        .rst           (reset),
        .EN            (seg7_write_enable),
        .ctrl          (sw_i[5:0]),
        .Data0         (cpuseg7_data),
        .data1         ({2'b0, PC[31:2]}),
        .data2         (PC),
        .data3         (instr),
        .data4         (bus_write_addr),
        .data5         (bus_write_data),
        .data6         (DM_read_data), 
        .data7         (DM_write_addr),
        .reg_data      (reg_data),
        .seg7_data     (seg7_data)
    );

    SEG7x16 U_7SEG(
        .clk           (clk),
        .rst           (reset),
        .cs            (1'b1),
        .i_data        (seg7_data),
        .o_seg         (disp_seg_o),
        .o_sel         (disp_an_o)
    );

    // Clock divider
    CLK_DIV U_CLKDIV(
        .clk           (clk),
        .rst           (reset),
        .SW15          (sw_i[15]),
        .Clk_CPU       (Clk_CPU)
    );
    
    // VGA 25MHz pixel clock (100MHz / 4)
    reg [1:0] clk_div_cnt;
    always @(posedge clk or posedge reset) begin
        if (reset)
            clk_div_cnt <= 2'd0;
        else
            clk_div_cnt <= clk_div_cnt + 2'd1;
    end
    assign vga_clk = clk_div_cnt[1];  // 25MHz

endmodule