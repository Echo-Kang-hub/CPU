`timescale 1ns / 1ps
`include "CLK_DIV.v"
`include "MIO_BUS.v"
`include "SEG7x16.v"
`include "imem.v"
`include "dmem.v"
`include "pipeline_top.v"

module IP2SOC_Top(
    input wire    clk,              
    input wire    rstn,             
    input wire [15:0]  sw_i,        
    output wire [7:0]  disp_seg_o,  
    output wire [7:0]  disp_an_o
);
  
    wire          Clk_CPU;          
    wire [31:0]   instr;            
    wire [31:0]   PC;               
    wire          MemWrite;         
    wire [31:0]   dm_din, dm_dout;  
    wire [31:0]   cpu_data_addr;    
    wire [31:0]   cpu_data_out;     
    wire [31:0]   cpu_data_in;      // MIO_BUS 返回给 CPU 的数据
    wire [3:0]    cpu_data_amp;     // CPU 访问类型 (4位)

    wire          rst = ~rstn;      
    wire [31:0]   seg7_data;        
    wire [6:0]    ram_addr;         
    wire [3:0]    ram_amp;          // 经过 MIO 转换后的 RAM 类型
    wire          ram_we;           
    wire          seg7_we;          // 数码管控制寄存器写使能
    wire [31:0]   cpuseg7_data;     // 存储在 MIO 里的数码管显示数据
    wire [31:0]   reg_data;         // CPU 寄存器堆输出的数据

    pipeline_top U_CPU (
        .clk             (Clk_CPU),          // 使用分频后的 CPU 时钟
        .reset           (rst),
        
        // 指令总线
        .instr_addr      (PC),
        .instr           (instr),
        
        // 数据总线 (对接 MIO_BUS)
        .DM_write_addr   (cpu_data_addr),
        .DM_write_data   (cpu_data_out),
        .DM_write_enable (MemWrite),
        // 这里的位宽匹配：将 CPU 的 3 位 DM_Type 扩展到 MIO 的 4 位，或直接连接
        .DM_Type         (cpu_data_amp[2:0]), 
        .DM_read_data    (cpu_data_in),
        
        // 调试接口：通过拨码开关 sw_i[10:6] 查看 32 个寄存器
        .reg_sel         (sw_i[10:6]), 
        .reg_data        (reg_data)
    );

    imem U_IM (
        .a               (PC[8:2]),          // 指令对齐
        .spo             (instr)
    );

    dmem U_DM (
        .clk             (Clk_CPU), 
        .DMWr            (ram_we), 
        .DMType          (ram_amp),          // MIO 控制 RAM 的读写宽度
        .addr            (ram_addr), 
        .din             (dm_din),
        .dout            (dm_dout)
    );

    // I/O 管理 (MIO_BUS)
    MIO_BUS U_MIO (
        .sw_i            (sw_i),             // 拨码开关输入
        .mem_w           (MemWrite),         // CPU 写请求
        .cpu_data_amp    (cpu_data_amp),     // 这里如果你 CPU 输出是 3 位，需赋给 cpu_data_amp[2:0]
        .cpu_data_addr   (cpu_data_addr),    // 访问地址
        .cpu_data_out    (cpu_data_out),     // CPU 写出的数据
        .ram_data_out    (dm_dout),          // 从 RAM 读到的数据
        
        .cpu_data_in     (cpu_data_in),      // 选通后返回给 CPU 的数据
        .ram_data_in     (dm_din),           // 送往 RAM 的数据
        .ram_addr        (ram_addr),         // 转换后的 RAM 地址
        .cpuseg7_data    (cpuseg7_data),     // CPU 写入数码管的值
        .ram_we          (ram_we),           // 最终 RAM 写使能
        .ram_amp         (ram_amp),
        .seg7_we         (seg7_we)           // 是否写数码管控制寄存器
    );

    
    // 多路数据选择器，用于切换数码管显示内容
    MULTI_CH32 U_Multi (
        .clk             (clk),
        .rst             (rst),
        .EN              (seg7_we),
        .ctrl            (sw_i[5:0]),        // sw[5:0] 决定显示 PC/指令/寄存器/内存等
        .Data0           (cpuseg7_data),
        .data1           ({2'b0, PC[31:2]}),
        .data2           (PC),
        .data3           (instr),
        .data4           (cpu_data_addr),
        .data5           (cpu_data_out),
        .data6           (dm_dout),
        .data7           ({23'b0, ram_addr, 2'b00}),
        .reg_data        (reg_data),         // 核心：将 CPU 寄存器数据送入显示器
        .seg7_data       (seg7_data)
    );

    SEG7x16 U_7SEG(
        .clk             (clk), 
        .rst             (rst),
        .cs              (1'b1),
        .i_data          (seg7_data),
        .o_seg           (disp_seg_o),
        .o_sel           (disp_an_o)
    );

    CLK_DIV U_CLKDIV( 
        .clk             (clk),
        .rst             (rst),
        .SW15            (sw_i[15]),         // 开关 15 控制 CPU 时钟频率
        .Clk_CPU         (Clk_CPU)
    );

endmodule