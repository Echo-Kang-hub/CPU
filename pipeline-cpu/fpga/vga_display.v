`ifndef __VGA_DISPLAY_V__
`define __VGA_DISPLAY_V__
`timescale 1ns / 1ps

module vga_display(
    input  wire vga_clk,
    input  wire cpu_clk,
    input  wire reset,

    input  wire        vga_write_enable,
    input  wire [12:0] vga_write_addr,
    input  wire [7:0]  vga_write_data, // ascii
    input  wire [12:0] vga_read_addr,
    output reg  [7:0]  vga_read_data,
    
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b,
    output wire        vga_hsync,
    output wire        vga_vsync
);

    parameter BG_ENABLE = 1'b0;

    // Text
    parameter TEXT_SCALE    = 2;
    parameter TEXT_X_OFFSET = 10'd16;
    parameter TEXT_Y_OFFSET = 10'd16;

    localparam CHAR_WIDTH   = 10'd8;
    localparam CHAR_HEIGHT  = 10'd16;
    localparam CELL_WIDTH   = CHAR_WIDTH * TEXT_SCALE;
    localparam CELL_HEIGHT  = CHAR_HEIGHT * TEXT_SCALE;

    // Margin
    localparam AVAIL_WIDTH  = (H_DISPLAY > (TEXT_X_OFFSET << 1)) ? (H_DISPLAY - (TEXT_X_OFFSET << 1)) : 10'd0;
    localparam AVAIL_HEIGHT = (V_DISPLAY > (TEXT_Y_OFFSET << 1)) ? (V_DISPLAY - (TEXT_Y_OFFSET << 1)) : 10'd0;
    localparam TEXT_COLS    = AVAIL_WIDTH / CELL_WIDTH;
    localparam TEXT_ROWS    = AVAIL_HEIGHT / CELL_HEIGHT;
    localparam TEXT_WIDTH   = TEXT_COLS * CELL_WIDTH;
    localparam TEXT_HEIGHT  = TEXT_ROWS * CELL_HEIGHT;
    localparam TEXT_X_START = TEXT_X_OFFSET + ((AVAIL_WIDTH - TEXT_WIDTH) >> 1);
    localparam TEXT_Y_START = TEXT_Y_OFFSET + ((AVAIL_HEIGHT - TEXT_HEIGHT) >> 1);

    // VGA ：640x480 @ 60Hz
    parameter H_TOTAL   = 10'd800;
    parameter H_SYNC    = 10'd96;
    parameter H_BACK    = 10'd144;
    parameter H_DISPLAY = 10'd640;
    parameter H_FRONT   = 10'd784;
    
    parameter V_TOTAL   = 10'd525;
    parameter V_SYNC    = 10'd2;
    parameter V_BACK    = 10'd35;
    parameter V_DISPLAY = 10'd480;
    parameter V_FRONT   = 10'd515;

    // Pixel counters
    reg [9:0] h_cnt;
    reg [9:0] v_cnt;
    
    // VGA signals
    wire h_valid, v_valid;
    wire valid;




    // Pixel counter
    // Horizontal counter
    always @(posedge vga_clk or posedge reset) begin
        if (reset)
            h_cnt <= 10'd0;
        else if (h_cnt == H_TOTAL - 1)
            h_cnt <= 10'd0;
        else
            h_cnt <= h_cnt + 1;
    end
    
    // Vertical counter
    always @(posedge vga_clk or posedge reset) begin
        if (reset)
            v_cnt <= 10'd0;
        else if (h_cnt == H_TOTAL - 1) begin
            if (v_cnt == V_TOTAL - 1)
                v_cnt <= 10'd0;
            else
                v_cnt <= v_cnt + 1;
        end
    end
    



    // define Window 
    assign vga_hsync = (h_cnt >= H_SYNC);
    assign vga_vsync = (v_cnt >= V_SYNC);
    
    assign h_valid = (h_cnt >= H_BACK) && (h_cnt < H_FRONT);
    assign v_valid = (v_cnt >= V_BACK) && (v_cnt < V_FRONT);
    assign valid = h_valid & v_valid;
    
    wire [9:0] h_pixel = h_valid ? (h_cnt - H_BACK) : 10'd0;
    wire [9:0] v_pixel = v_valid ? (v_cnt - V_BACK) : 10'd0;



    // 320x240 -> 640x480
    // 320*240 = 76800 entries.
    localparam BG_WIDTH  = 10'd320;
    localparam BG_HEIGHT = 10'd240;
    wire [9:0] bg_x = h_pixel >> 1;
    wire [9:0] bg_y = v_pixel >> 1;
    wire [16:0] bg_addr = bg_y * BG_WIDTH + bg_x;
    reg [11:0] bg_mem [0:76799];
    reg [11:0] bg_rgb_d1;
    reg [11:0] bg_rgb_d2;

    initial begin
        $readmemh("background.mem", bg_mem);
    end

    always @(posedge vga_clk) begin
        bg_rgb_d1 <= bg_mem[bg_addr];
        bg_rgb_d2 <= bg_rgb_d1;
    end

    wire [11:0] bg_rgb = BG_ENABLE ? bg_rgb_d2 : 12'h000;




    wire in_text_h = (h_pixel >= TEXT_X_START) && (h_pixel < (TEXT_X_START + TEXT_WIDTH));
    wire in_text_v = (v_pixel >= TEXT_Y_START) && (v_pixel < (TEXT_Y_START + TEXT_HEIGHT));
    wire in_text_area = valid && in_text_h && in_text_v;


    // calculate position
    wire [9:0] text_h_pixel = h_pixel - TEXT_X_START;
    wire [9:0] text_v_pixel = v_pixel - TEXT_Y_START;

    wire [9:0] font_h_pixel = text_h_pixel >> 1;
    wire [9:0] font_v_pixel = text_v_pixel >> 1;

    wire [6:0] char_col = font_h_pixel[9:3]; // / 8
    wire [4:0] char_row = font_v_pixel[8:4]; // / 16
    wire [3:0] char_row_pixel = font_v_pixel[3:0];
    wire [2:0] char_col_pixel = font_h_pixel[2:0];
    
    wire [12:0] char_addr = {2'b0, char_row, 6'b0} + {4'b0, char_row, 4'b0} + {6'b0, char_col};
    wire [12:0] char_addr_safe = (char_addr < 13'd2400) ? char_addr : 13'd0;
    

    // Character memory：write in cpu_clk, read in vga_clk
    reg [7:0] chr_mem [0:2399];
    reg [7:0] char_code_reg;

    integer i;
    initial begin
        for (i = 0; i < 2400; i = i + 1) begin
            chr_mem[i] = 8'h20;
        end
    end

    always @(posedge cpu_clk) begin
        if (vga_write_enable && (vga_write_addr < 13'd2400)) begin
            chr_mem[vga_write_addr] <= vga_write_data;
        end

        if (vga_read_addr < 13'd2400)
            vga_read_data <= chr_mem[vga_read_addr];
        else
            vga_read_data <= 8'h20;
    end
    
    always @(posedge vga_clk) begin
        char_code_reg <= chr_mem[char_addr_safe];
    end
    



    // Font ROM
    reg [7:0] font_data_reg;
    reg [7:0] font_mem [0:2047];
    initial begin
        $readmemh("font_data.mem", font_mem);
    end
    
    // ascii * 16
    wire [10:0] font_addr = {char_code_reg[6:0], 4'b0} + char_row_pixel;
    
    // 2-cycle memory read latency
    reg [2:0] char_col_pixel_d1, char_col_pixel_d2;
    reg       in_text_area_d1, in_text_area_d2;
    reg       valid_d1, valid_d2;
    reg       hl_d1, hl_d2;
    reg [6:0] char_base_d1, char_base_d2;

    always @(posedge vga_clk or posedge reset) begin
        if (reset) begin
            char_col_pixel_d1 <= 3'd0;
            char_col_pixel_d2 <= 3'd0;
            in_text_area_d1   <= 1'b0;
            in_text_area_d2   <= 1'b0;
            valid_d1          <= 1'b0;
            valid_d2          <= 1'b0;
            hl_d1             <= 1'b0;
            hl_d2             <= 1'b0;
            char_base_d1      <= 7'd0;
            char_base_d2      <= 7'd0;
        end else begin
            char_col_pixel_d1 <= char_col_pixel;
            in_text_area_d1   <= in_text_area;
            valid_d1          <= valid;
            hl_d1             <= char_code_reg[7];
            char_base_d1      <= char_code_reg[6:0];

            char_col_pixel_d2 <= char_col_pixel_d1;
            in_text_area_d2   <= in_text_area_d1;
            valid_d2          <= valid_d1;
            hl_d2             <= hl_d1;
            char_base_d2      <= char_base_d1;
        end
    end

    always @(posedge vga_clk) begin
        font_data_reg <= font_mem[font_addr];
    end
    
    // Get pixel color (only in text area)
    wire pixel_on = in_text_area_d2 && font_data_reg[7 - char_col_pixel_d2];
    wire is_food_char  = (char_base_d2 == 7'h2A);
    wire is_snake_char = (char_base_d2 == 7'h6F) || // o body
                         (char_base_d2 == 7'h3E) || // > head
                         (char_base_d2 == 7'h3C) || // < head
                         (char_base_d2 == 7'h5E) || // ^ head
                         (char_base_d2 == 7'h76);   // v head
    
    reg [3:0] vga_r_reg, vga_g_reg, vga_b_reg;
    
    always @(posedge vga_clk) begin
        if (valid_d2) begin
            if (pixel_on) begin
                if (hl_d2) begin
                    vga_r_reg <= 4'hC;
                    vga_g_reg <= 4'hA;
                    vga_b_reg <= 4'h2;
                end else if (is_food_char) begin
                    vga_r_reg <= 4'hF;
                    vga_g_reg <= 4'h1;
                    vga_b_reg <= 4'h1;
                end else if (is_snake_char) begin
                    vga_r_reg <= 4'h1;
                    vga_g_reg <= 4'hF;
                    vga_b_reg <= 4'h1;
                end else begin
                    vga_r_reg <= 4'hF;
                    vga_g_reg <= 4'hF;
                    vga_b_reg <= 4'hF;
                end
            end else begin
                vga_r_reg <= bg_rgb[11:8];
                vga_g_reg <= bg_rgb[7:4];
                vga_b_reg <= bg_rgb[3:0];
            end
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
