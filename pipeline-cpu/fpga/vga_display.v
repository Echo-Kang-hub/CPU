`ifndef __VGA_DISPLAY_V__
`define __VGA_DISPLAY_V__
`timescale 1ns / 1ps

module vga_display(
    input  wire clk,  // 25MHz VGA pixel clock
    input  wire reset,
    
    // CPU write interface (CPU时钟域)
    input  wire [12:0] cpu_addr,
    input  wire [7:0]  cpu_char,
    input  wire        cpu_we,
    
    // VGA output
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b,
    output wire        vga_hsync,
    output wire        vga_vsync
);

    // 跨时钟域同步：CPU写入信号 -> VGA时钟域
    
    // 在VGA时钟域锁存
    reg [12:0] cpu_addr_reg;
    reg [7:0]  cpu_char_reg;
    reg        cpu_we_reg;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            cpu_addr_reg <= 13'd0;
            cpu_char_reg <= 8'd0;
            cpu_we_reg <= 1'b0;
        end else begin
            cpu_addr_reg <= cpu_addr;
            cpu_char_reg <= cpu_char;
            cpu_we_reg <= cpu_we;
        end
    end
    
    // 边沿检测
    reg cpu_we_d1;
    always @(posedge clk or posedge reset) begin
        if (reset)
            cpu_we_d1 <= 1'b0;
        else
            cpu_we_d1 <= cpu_we_reg;
    end
    
    wire cpu_we_rising = cpu_we_reg & ~cpu_we_d1;

    // VGA timing parameters (640x480 @ 60Hz)
    parameter H_TOTAL   = 10'd800;
    parameter H_SYNC    = 10'd96;
    parameter H_BACK    = 10'd144;
    parameter H_DISPLAY = 10'd640;
    parameter H_FRONT   = 10'd784;
    
    parameter V_TOTAL   = 10'd525;
    parameter V_SYNC    = 10'd2;
    parameter V_BACK    = 10'd35;
    parameter V_DISPLAY = 10'd480;
    parameter V_FRONT   = 10'd514;

    // Pixel counters
    reg [9:0] h_cnt;
    reg [9:0] v_cnt;
    
    // VGA signals
    wire h_valid, v_valid;
    wire valid;
    
    // Horizontal counter
    always @(posedge clk or posedge reset) begin
        if (reset)
            h_cnt <= 10'd0;
        else if (h_cnt == H_TOTAL - 1)
            h_cnt <= 10'd0;
        else
            h_cnt <= h_cnt + 1;
    end
    
    // Vertical counter
    always @(posedge clk or posedge reset) begin
        if (reset)
            v_cnt <= 10'd0;
        else if (h_cnt == H_TOTAL - 1) begin
            if (v_cnt == V_TOTAL - 1)
                v_cnt <= 10'd0;
            else
                v_cnt <= v_cnt + 1;
        end
    end
    
    // Sync signals (active low)
    assign vga_hsync = (h_cnt >= H_SYNC);
    assign vga_vsync = (v_cnt >= V_SYNC);
    
    // Valid signals
    assign h_valid = (h_cnt >= H_BACK) && (h_cnt < H_FRONT);
    assign v_valid = (v_cnt >= V_BACK) && (v_cnt < V_FRONT);
    assign valid = h_valid & v_valid;
    
    // Pixel coordinates
    wire [9:0] h_pixel = h_valid ? (h_cnt - H_BACK) : 10'd0;
    wire [9:0] v_pixel = v_valid ? (v_cnt - V_BACK) : 10'd0;
    
    // Character position (16 rows per char, 8 cols per char)
    wire [6:0] char_col = h_pixel[9:3];           // / 8, 7 bits for 0-79
    wire [4:0] char_row = v_pixel[8:4];           // / 16, 5 bits for 0-29
    wire [3:0] char_row_pixel = v_pixel[3:0];     // % 16
    wire [2:0] char_col_pixel = h_pixel[2:0];     // % 8
    
    // Character memory address calculation (row*80 + col)
    // row*80 = row*64 + row*16 = (row<<6) + (row<<4)
    wire [12:0] char_addr = {2'b0, char_row, 6'b0} + {4'b0, char_row, 4'b0} + {6'b0, char_col};
    
    
    // 显存 - 跨时钟域安全的读写
    reg [7:0] chr_mem [0:2399];
    reg [7:0] char_code_reg;
    
    // 写优先读：如果当前时钟周期写入同一地址，直接使用写入数据
    always @(posedge clk) begin
        if (cpu_we_rising && (cpu_addr_reg == char_addr))
            char_code_reg <= cpu_char_reg;
        else
            char_code_reg <= chr_mem[char_addr];
    end
    
    // 写入显存（使用同步后的信号）
    always @(posedge clk) begin
        if (cpu_we_rising)
            chr_mem[cpu_addr_reg] <= cpu_char_reg;
    end
    
    // Font ROM
    reg [7:0] font_data_reg;
    
    // Font ROM存储
    reg [7:0] font_mem [0:2047];
    initial begin
        $readmemh("font_data.mem", font_mem);
    end
    
    // ascii * 16 = ascii << 4
    wire [10:0] font_addr = {char_code_reg[6:0], 4'b0} + char_row_pixel;
    
    // 读取字体数据（寄存器输出，改善时序）
    always @(posedge clk) begin
        font_data_reg <= font_mem[font_addr];
    end
    
    // Get pixel color
    wire pixel_on = font_data_reg[7 - char_col_pixel];
    
    // Output color (white on black)
    reg [3:0] vga_r_reg, vga_g_reg, vga_b_reg;
    reg valid_reg;
    
    always @(posedge clk) begin
        valid_reg <= valid;
        if (valid) begin
            // 正常模式：显示字符
            vga_r_reg <= pixel_on ? 4'hF : 4'h0;
            vga_g_reg <= pixel_on ? 4'hF : 4'h0;
            vga_b_reg <= pixel_on ? 4'hF : 4'h0;
        end else begin
            vga_r_reg <= 4'h0;
            vga_g_reg <= 4'h0;
            vga_b_reg <= 4'h0;
        end
    end
    
    assign vga_r = vga_r_reg;
    assign vga_g = vga_g_reg;
    assign vga_b = vga_b_reg;

endmodule
`endif
