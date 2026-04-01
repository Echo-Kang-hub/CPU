`ifndef __VGA_DISPLAY_V__
`define __VGA_DISPLAY_V__
`timescale 1ns / 1ps

module vga_display(
    input  wire clk,           // 25MHz
    input  wire reset,
    
    // CPU write interface
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
    wire valid = h_valid & v_valid;
    
    // Character position
    wire [9:0] h_pixel;
    wire [9:0] v_pixel;
    wire [4:0] char_row;    // 0-29 (5 bits)
    wire [6:0] char_col;    // 0-79 (7 bits)
    wire [3:0] char_row_pixel;
    wire [3:0] char_col_pixel;
    
    // Character memory (30 rows x 80 cols = 2400 bytes)
    reg [7:0] chr_mem [0:2399];
    
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
    
    // Sync signals
    assign vga_hsync = (h_cnt >= H_SYNC);
    assign vga_vsync = (v_cnt >= V_SYNC);
    
    // Valid signals
    assign h_valid = (h_cnt >= H_BACK) && (h_cnt < H_FRONT);
    assign v_valid = (v_cnt >= V_BACK) && (v_cnt < V_FRONT);
    
    // Pixel coordinates
    assign h_pixel = h_valid ? (h_cnt - H_BACK) : 10'd0;
    assign v_pixel = v_valid ? (v_cnt - V_BACK) : 10'd0;
    
    // Character position (16 rows per char, 8 cols per char)
    assign char_row = v_pixel[8:4];           // / 16, 5 bits for 0-29
    assign char_col = h_pixel[9:3];           // / 8, 7 bits for 0-79
    assign char_row_pixel = v_pixel[3:0];     // % 16
    assign char_col_pixel = h_pixel[2:0];     // % 8
    
    // Character memory address (30 rows x 80 cols = 2400)
    // Use shift-add: row*80 = row*64 + row*16 = (row<<6) + (row<<4)
    wire [11:0] char_addr = ({1'b0, char_row, 6'b0}) + ({3'b0, char_row, 4'b0}) + {5'b0, char_col};
    
    // Read character from memory
    wire [7:0] char_code;
    assign char_code = chr_mem[char_addr];
    
    // Write to character memory
    always @(posedge clk) begin
        if (cpu_we)
            chr_mem[cpu_addr] <= cpu_char;
    end
    
    // Font ROM - initialized from font_data.mem
    wire [7:0] font_data;
    font_rom u_font_rom(
        .ascii(char_code),
        .row(char_row_pixel),
        .font_data(font_data)
    );
    
    // Get pixel color
    wire pixel_on = font_data[7 - char_col_pixel];
    
    // Output color (white on black)
    assign vga_r = valid ? (pixel_on ? 4'hF : 4'h0) : 4'h0;
    assign vga_g = valid ? (pixel_on ? 4'hF : 4'h0) : 4'h0;
    assign vga_b = valid ? (pixel_on ? 4'hF : 4'h0) : 4'h0;

endmodule


// Font ROM - initialized from font_data.mem
// 支持完整 ASCII 0-127 (128个字符，每个16行，共2048字节)
module font_rom(
    input  wire [7:0] ascii,
    input  wire [3:0] row,
    output wire [7:0] font_data
);
    // 128 characters x 16 rows = 2048 bytes total
    reg [7:0] font_mem [0:2047];
    
    initial begin
        $readmemh("font_data.mem", font_mem);
    end
    
    // 地址计算: font_addr = ascii * 16 + row
    // ASCII 0-127 直接映射到地址 0-2047
    wire [11:0] font_addr = ascii[6:0] * 16 + row;
    
    // 组合逻辑输出
    assign font_data = font_mem[font_addr];

endmodule
`endif