`timescale 1ns / 1ps

`ifdef TB_FAST_CLK
module CLK_DIV #(
    parameter USE_SW15_CLK_SEL = 1'b0,
    parameter FAST_CLKDIV_BIT  = 2,
    parameter SLOW_CLKDIV_BIT  = 25
)(
    input wire clk,
    input wire rst,
    input wire SW15,
    output wire Clk_CPU
);
    assign Clk_CPU = clk;
endmodule
`endif

// Full gameplay regression for snake_vga:
// 1) eat food => score +1 and length +1
// 2) wall hit => game over + final score shown
// 3) game-over menu W/S + Up/Down selection + no position drift
// 4) restart path works
// 5) self hit => game over
// 6) exit path works (BYE)
module tb_snake_gameplay_full;
    reg clk;
    reg rstn;
    reg [15:0] sw_i;
    reg ps2_clk;
    reg ps2_data;

    wire [7:0] disp_seg_o;
    wire [7:0] disp_an_o;
    wire [3:0] vga_r;
    wire [3:0] vga_g;
    wire [3:0] vga_b;
    wire vga_hsync;
    wire vga_vsync;

    integer pass_count;
    integer fail_count;
    integer wall_score_expected;

    localparam integer START_ARROW_ROW = 8;
    localparam integer START_ARROW_COL = 12;
    localparam integer EXIT_ARROW_ROW  = 10;
    localparam integer EXIT_ARROW_COL  = 15;

    xgriscv_fpga_top UUT (
        .clk        (clk),
        .rstn       (rstn),
        .sw_i       (sw_i),
        .disp_seg_o (disp_seg_o),
        .disp_an_o  (disp_an_o),
        .ps2_clk    (ps2_clk),
        .ps2_data   (ps2_data),
        .vga_r      (vga_r),
        .vga_g      (vga_g),
        .vga_b      (vga_b),
        .vga_hsync  (vga_hsync),
        .vga_vsync  (vga_vsync)
    );

    initial begin
        clk = 1'b0;
        rstn = 1'b0;
        // SW15=1 makes delay_tick skip software busy-wait.
        // With TB_FAST_CLK, CPU clock is still fast in simulation.
        sw_i = 16'h8000;
        ps2_clk = 1'b1;
        ps2_data = 1'b1;
        pass_count = 0;
        fail_count = 0;
    end

    always #5 clk = ~clk;

    function [7:0] chr_at;
        input integer row;
        input integer col;
        begin
            chr_at = UUT.U_VGA.chr_mem[row * 80 + col];
        end
    endfunction

    function [7:0] base_chr;
        input [7:0] c;
        begin
            base_chr = c & 8'h7F;
        end
    endfunction

    function [7:0] head_x;
        begin
            head_x = UUT.U_DM.RAM[64][7:0];
        end
    endfunction

    function [7:0] head_y;
        begin
            head_y = UUT.U_DM.RAM[96][7:0];
        end
    endfunction

    function [31:0] snake_len;
        begin
            snake_len = UUT.U_DM.RAM[2];
        end
    endfunction

    function [31:0] direction_word;
        begin
            direction_word = UUT.U_DM.RAM[3];
        end
    endfunction

    function [31:0] score_word;
        begin
            score_word = UUT.U_DM.RAM[4];
        end
    endfunction

    function [1:0] menu_sel;
        begin
            menu_sel = UUT.U_DM.RAM[10][1:0];
        end
    endfunction

    task wait_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(posedge clk);
        end
    endtask

    task ps2_send_byte;
        input [7:0] code;
        integer i;
        reg [10:0] frame;
        begin
            frame[0] = 1'b0;
            frame[8:1] = code;
            frame[9] = ~(^code);
            frame[10] = 1'b1;

            for (i = 0; i < 11; i = i + 1) begin
                ps2_data = frame[i];
                #40 ps2_clk = 1'b0;
                #40 ps2_clk = 1'b1;
            end

            ps2_data = 1'b1;
            #160;
        end
    endtask

    task ps2_send_make;
        input [7:0] code;
        begin
            ps2_send_byte(code);
        end
    endtask

    task ps2_send_ext_make;
        input [7:0] code;
        begin
            ps2_send_byte(8'hE0);
            ps2_send_byte(code);
        end
    endtask

    task ps2_send_make_break;
        input [7:0] code;
        begin
            ps2_send_byte(code);
            ps2_send_byte(8'hF0);
            ps2_send_byte(code);
        end
    endtask

    task ps2_send_ext_make_break;
        input [7:0] code;
        begin
            ps2_send_byte(8'hE0);
            ps2_send_byte(code);
            ps2_send_byte(8'hE0);
            ps2_send_byte(8'hF0);
            ps2_send_byte(code);
        end
    endtask

    task pass_msg;
        input [8*80-1:0] tag;
        begin
            pass_count = pass_count + 1;
            $display("[PASS] %0s", tag);
        end
    endtask

    task fail_msg;
        input [8*80-1:0] tag;
        begin
            fail_count = fail_count + 1;
            $display("[FAIL] %0s", tag);
        end
    endtask

    task expect_menu_sel_within;
        input [1:0] expected;
        input integer max_cycles;
        input [8*80-1:0] tag;
        integer i;
        reg hit;
        begin
            hit = 1'b0;
            for (i = 0; i < max_cycles; i = i + 1) begin
                if (menu_sel() === expected) begin
                    hit = 1'b1;
                    i = max_cycles;
                end
                @(posedge clk);
            end

            if (hit)
                pass_msg(tag);
            else
                fail_msg({tag, " menu_sel timeout"});
        end
    endtask

    task expect_game_init_within;
        input integer max_cycles;
        input [8*80-1:0] tag;
        integer i;
        reg hit;
        begin
            hit = 1'b0;
            for (i = 0; i < max_cycles; i = i + 1) begin
                if ((snake_len() == 32'd5) && (direction_word() == 32'd1) && (head_x() == 8'd20) && (head_y() == 8'd6)) begin
                    hit = 1'b1;
                    i = max_cycles;
                end
                @(posedge clk);
            end

            if (hit)
                pass_msg(tag);
            else
                fail_msg({tag, " init timeout"});
        end
    endtask

    task expect_head_xy_within;
        input [7:0] ex;
        input [7:0] ey;
        input integer max_cycles;
        input [8*80-1:0] tag;
        integer i;
        reg hit;
        begin
            hit = 1'b0;
            for (i = 0; i < max_cycles; i = i + 1) begin
                if ((head_x() == ex) && (head_y() == ey)) begin
                    hit = 1'b1;
                    i = max_cycles;
                end
                @(posedge clk);
            end

            if (hit)
                pass_msg(tag);
            else
                fail_msg({tag, " head xy timeout"});
        end
    endtask

    task expect_game_over_banner_within;
        input integer max_cycles;
        input [8*80-1:0] tag;
        integer i;
        reg hit;
        begin
            hit = 1'b0;
            for (i = 0; i < max_cycles; i = i + 1) begin
                if ((base_chr(chr_at(2, 14)) == 8'h47) &&
                    (base_chr(chr_at(2, 15)) == 8'h41) &&
                    (base_chr(chr_at(2, 16)) == 8'h4D) &&
                    (base_chr(chr_at(2, 17)) == 8'h45)) begin
                    hit = 1'b1;
                    i = max_cycles;
                end
                @(posedge clk);
            end

            if (hit)
                pass_msg(tag);
            else
                fail_msg({tag, " no GAME OVER"});
        end
    endtask

    task expect_start_screen_within;
        input integer max_cycles;
        input [8*80-1:0] tag;
        integer i;
        reg hit;
        begin
            hit = 1'b0;
            for (i = 0; i < max_cycles; i = i + 1) begin
                // "WASD TO MOVE" starts at row4 col13.
                if ((base_chr(chr_at(4, 13)) == 8'h57) &&
                    (base_chr(chr_at(4, 14)) == 8'h41) &&
                    (base_chr(chr_at(4, 15)) == 8'h53) &&
                    (base_chr(chr_at(4, 16)) == 8'h44)) begin
                    hit = 1'b1;
                    i = max_cycles;
                end
                @(posedge clk);
            end

            if (hit)
                pass_msg(tag);
            else
                fail_msg({tag, " no start screen"});
        end
    endtask

    task expect_bye_within;
        input integer max_cycles;
        input [8*80-1:0] tag;
        integer i;
        reg hit;
        begin
            hit = 1'b0;
            for (i = 0; i < max_cycles; i = i + 1) begin
                if ((base_chr(chr_at(14, 38)) == 8'h42) &&
                    (base_chr(chr_at(14, 39)) == 8'h59) &&
                    (base_chr(chr_at(14, 40)) == 8'h45)) begin
                    hit = 1'b1;
                    i = max_cycles;
                end
                @(posedge clk);
            end

            if (hit)
                pass_msg(tag);
            else
                fail_msg({tag, " BYE not shown"});
        end
    endtask

    task expect_over_layout_invariant_within;
        input integer max_cycles;
        input [8*80-1:0] tag;
        integer i;
        reg hit;
        begin
            hit = 1'b0;
            for (i = 0; i < max_cycles; i = i + 1) begin
                if ((base_chr(chr_at(8, 15)) == 8'h52) &&
                    (base_chr(chr_at(8, 16)) == 8'h45) &&
                    (base_chr(chr_at(8, 17)) == 8'h53) &&
                    (base_chr(chr_at(8, 18)) == 8'h54) &&
                    (base_chr(chr_at(8, 19)) == 8'h41) &&
                    (base_chr(chr_at(8, 20)) == 8'h52) &&
                    (base_chr(chr_at(8, 21)) == 8'h54) &&
                    (base_chr(chr_at(10, 14)) == 8'h53) &&
                    (base_chr(chr_at(10, 15)) == 8'h54) &&
                    (base_chr(chr_at(10, 16)) == 8'h41) &&
                    (base_chr(chr_at(10, 17)) == 8'h52) &&
                    (base_chr(chr_at(10, 18)) == 8'h54) &&
                    (base_chr(chr_at(10, 20)) == 8'h4D) &&
                    (base_chr(chr_at(10, 21)) == 8'h45) &&
                    (base_chr(chr_at(10, 22)) == 8'h4E) &&
                    (base_chr(chr_at(10, 23)) == 8'h55) &&
                    (base_chr(chr_at(12, 17)) == 8'h45) &&
                    (base_chr(chr_at(12, 18)) == 8'h58) &&
                    (base_chr(chr_at(12, 19)) == 8'h49) &&
                    (base_chr(chr_at(12, 20)) == 8'h54)) begin
                    hit = 1'b1;
                    i = max_cycles;
                end
                @(posedge clk);
            end

            if (hit)
                pass_msg(tag);
            else begin
                $display("[INFO] over row8 cols13..23 = %02h %02h %02h %02h %02h %02h %02h %02h %02h %02h %02h",
                         chr_at(8,13), chr_at(8,14), chr_at(8,15), chr_at(8,16), chr_at(8,17), chr_at(8,18),
                         chr_at(8,19), chr_at(8,20), chr_at(8,21), chr_at(8,22), chr_at(8,23));
                $display("[INFO] over row10 cols12..24 = %02h %02h %02h %02h %02h %02h %02h %02h %02h %02h %02h %02h %02h",
                         chr_at(10,12), chr_at(10,13), chr_at(10,14), chr_at(10,15), chr_at(10,16), chr_at(10,17),
                         chr_at(10,18), chr_at(10,19), chr_at(10,20), chr_at(10,21), chr_at(10,22), chr_at(10,23), chr_at(10,24));
                $display("[INFO] over row12 cols15..22 = %02h %02h %02h %02h %02h %02h %02h %02h",
                         chr_at(12,15), chr_at(12,16), chr_at(12,17), chr_at(12,18), chr_at(12,19), chr_at(12,20), chr_at(12,21), chr_at(12,22));
                fail_msg({tag, " layout drift"});
            end
        end
    endtask

    task expect_over_selected_visual_within;
        input [1:0] sel;
        input integer max_cycles;
        input [8*80-1:0] tag;
        integer i;
        reg hit;
        begin
            hit = 1'b0;
            for (i = 0; i < max_cycles; i = i + 1) begin
                if (sel == 2'd0) begin
                    if ((base_chr(chr_at(8, 13)) == 8'h3E) &&
                        (base_chr(chr_at(8, 23)) == 8'h3C) &&
                        (base_chr(chr_at(10, 12)) == 8'h20) &&
                        (base_chr(chr_at(10, 25)) == 8'h20) &&
                        (base_chr(chr_at(12, 15)) == 8'h20) &&
                        (base_chr(chr_at(12, 22)) == 8'h20)) begin
                        hit = 1'b1;
                        i = max_cycles;
                    end
                end else if (sel == 2'd1) begin
                    if ((base_chr(chr_at(10, 12)) == 8'h3E) &&
                        (base_chr(chr_at(10, 25)) == 8'h3C) &&
                        (base_chr(chr_at(8, 13)) == 8'h20) &&
                        (base_chr(chr_at(8, 23)) == 8'h20) &&
                        (base_chr(chr_at(12, 15)) == 8'h20) &&
                        (base_chr(chr_at(12, 22)) == 8'h20)) begin
                        hit = 1'b1;
                        i = max_cycles;
                    end
                end else begin
                    if ((base_chr(chr_at(12, 15)) == 8'h3E) &&
                        (base_chr(chr_at(12, 22)) == 8'h3C) &&
                        (base_chr(chr_at(8, 13)) == 8'h20) &&
                        (base_chr(chr_at(8, 23)) == 8'h20) &&
                        (base_chr(chr_at(10, 12)) == 8'h20) &&
                        (base_chr(chr_at(10, 25)) == 8'h20)) begin
                        hit = 1'b1;
                        i = max_cycles;
                    end
                end
                @(posedge clk);
            end

            if (hit)
                pass_msg(tag);
            else begin
                $display("[INFO] over markers restart(8,13/23)=%02h/%02h menu(10,12/25)=%02h/%02h exit(12,15/22)=%02h/%02h",
                         chr_at(8,13), chr_at(8,23), chr_at(10,12), chr_at(10,25), chr_at(12,15), chr_at(12,22));
                fail_msg({tag, " visual mismatch"});
            end
        end
    endtask

    task expect_final_score_display_within;
        input integer expected_score;
        input integer max_cycles;
        input [8*80-1:0] tag;
        integer h;
        integer t;
        integer o;
        integer i;
        reg hit;
        begin
            h = (expected_score / 100) % 10;
            t = (expected_score / 10) % 10;
            o = expected_score % 10;
            hit = 1'b0;

            for (i = 0; i < max_cycles; i = i + 1) begin
                if ((base_chr(chr_at(4, 24)) == (8'h30 + h[7:0])) &&
                    (base_chr(chr_at(4, 25)) == (8'h30 + t[7:0])) &&
                    (base_chr(chr_at(4, 26)) == (8'h30 + o[7:0]))) begin
                    hit = 1'b1;
                    i = max_cycles;
                end
                @(posedge clk);
            end

            if (hit)
                pass_msg(tag);
            else begin
                $display("[INFO] score chars hex=%02h %02h %02h", chr_at(4,24), chr_at(4,25), chr_at(4,26));
                fail_msg({tag, " score display mismatch"});
            end
        end
    endtask

    task force_eat_setup;
        input [31:0] score_val;
        reg [31:0] fx;
        begin
            // Keep current geometry and score; only ensure rightward direction and place food ahead.
            UUT.U_DM.RAM[3] = 32'd1;
            fx = {24'h0, (head_x() + 8'd4)};
            if (fx[7:0] > 8'd34)
                fx = 32'd34;
            UUT.U_DM.RAM[0] = fx;
            UUT.U_DM.RAM[1] = {24'h0, head_y()};
            $display("[INFO] force eat setup score=%0d head=(%0d,%0d) food=(%0d,%0d)",
                     score_word(), head_x(), head_y(), UUT.U_DM.RAM[0][7:0], UUT.U_DM.RAM[1][7:0]);
        end
    endtask

    task expect_eat_growth_within;
        input integer max_cycles;
        input [8*80-1:0] tag;
        integer i;
        reg hit;
        reg [31:0] s0;
        reg [31:0] l0;
        begin
            hit = 1'b0;
            s0 = score_word();
            l0 = snake_len();

            for (i = 0; i < max_cycles; i = i + 1) begin
                if ((score_word() == (s0 + 1)) && (snake_len() == (l0 + 1))) begin
                    hit = 1'b1;
                    i = max_cycles;
                end
                @(posedge clk);
            end

            if (hit)
                pass_msg(tag);
            else begin
                $display("[INFO] eat fail head=(%0d,%0d) food=(%0d,%0d) score=%0d len=%0d",
                         head_x(), head_y(), UUT.U_DM.RAM[0][7:0], UUT.U_DM.RAM[1][7:0], score_word(), snake_len());
                fail_msg({tag, " no score/len increment"});
            end
        end
    endtask

    task force_wall_death_setup;
        begin
            UUT.U_DM.RAM[2] = 32'd5; // len
            UUT.U_DM.RAM[3] = 32'd1; // dir right

            // x: 35,34,33,32,31
            UUT.U_DM.RAM[64][7:0]   = 8'd35;
            UUT.U_DM.RAM[64][15:8]  = 8'd34;
            UUT.U_DM.RAM[64][23:16] = 8'd33;
            UUT.U_DM.RAM[64][31:24] = 8'd32;
            UUT.U_DM.RAM[65][7:0]   = 8'd31;

            // y: 6,6,6,6,6
            UUT.U_DM.RAM[96][7:0]   = 8'd6;
            UUT.U_DM.RAM[96][15:8]  = 8'd6;
            UUT.U_DM.RAM[96][23:16] = 8'd6;
            UUT.U_DM.RAM[96][31:24] = 8'd6;
            UUT.U_DM.RAM[97][7:0]   = 8'd6;

            $display("[INFO] force wall-death setup keep score=%0d", score_word());
        end
    endtask

    task force_self_death_setup;
        input [31:0] score_val;
        begin
            UUT.U_DM.RAM[4] = score_val;
            UUT.U_DM.RAM[2] = 32'd5; // len
            UUT.U_DM.RAM[3] = 32'd2; // dir down

            // shape to self-hit after one step:
            // (10,6)->(9,6)->(9,7)->(10,7)->(11,7)
            UUT.U_DM.RAM[64][7:0]   = 8'd10;
            UUT.U_DM.RAM[64][15:8]  = 8'd9;
            UUT.U_DM.RAM[64][23:16] = 8'd9;
            UUT.U_DM.RAM[64][31:24] = 8'd10;
            UUT.U_DM.RAM[65][7:0]   = 8'd11;

            UUT.U_DM.RAM[96][7:0]   = 8'd6;
            UUT.U_DM.RAM[96][15:8]  = 8'd6;
            UUT.U_DM.RAM[96][23:16] = 8'd7;
            UUT.U_DM.RAM[96][31:24] = 8'd7;
            UUT.U_DM.RAM[97][7:0]   = 8'd7;

            $display("[INFO] force self-death setup score=%0d", score_val);
        end
    endtask

    initial begin
        $dumpfile("tb_snake_gameplay_full.vcd");
        $dumpvars(0, tb_snake_gameplay_full);

        $readmemh("D:/FileDownload/Projects/CPU/pipeline-cpu/inst.txt", UUT.U_IM.ROM);
        $readmemh("D:/FileDownload/Projects/CPU/pipeline-cpu/fpga/font_data.mem", UUT.U_VGA.font_mem);

        wait_cycles(10);
        rstn = 1'b1;

        // Enter from start menu
        expect_menu_sel_within(2'd0, 800000, "boot menu ready");
        $display("[INFO] press Enter to start game");
        ps2_send_make(8'h5A);
        expect_game_init_within(1800000, "game init after enter");
        expect_head_xy_within(8'd21, 8'd6, 300000, "first move after init");

        // Eat food: score+len should increase.
        force_eat_setup(32'd0);
        expect_eat_growth_within(350000, "eat food increases score and length");

        // Wall death and final score display.
        wall_score_expected = score_word();
        force_wall_death_setup();
        expect_game_over_banner_within(250000, "wall hit enters game over");
        expect_final_score_display_within(wall_score_expected, 250000, "game over final score displayed");

        // Over-menu selection by W/S and arrows; check no position drift.
        expect_menu_sel_within(2'd0, 250000, "over menu default restart");
        expect_over_layout_invariant_within(250000, "over layout invariant default");
        expect_over_selected_visual_within(2'd0, 250000, "over restart selected visual");

        $display("[INFO] over menu press S -> START MENU");
        ps2_send_make(8'h1B);
        expect_menu_sel_within(2'd1, 250000, "over menu S moves to start menu");
        expect_over_layout_invariant_within(250000, "over layout invariant after S");
        expect_over_selected_visual_within(2'd1, 250000, "over start menu selected visual");

        $display("[INFO] over menu press S -> EXIT");
        ps2_send_make(8'h1B);
        expect_menu_sel_within(2'd2, 250000, "over menu S moves to exit");
        expect_over_layout_invariant_within(250000, "over layout invariant after S2");
        expect_over_selected_visual_within(2'd2, 250000, "over exit selected visual");

        $display("[INFO] over menu press W -> START MENU");
        ps2_send_make(8'h1D);
        expect_menu_sel_within(2'd1, 250000, "over menu W moves back to start menu");
        expect_over_layout_invariant_within(250000, "over layout invariant after W");
        expect_over_selected_visual_within(2'd1, 250000, "over start menu selected visual 2");

        $display("[INFO] over menu press ArrowUp -> RESTART");
        ps2_send_ext_make(8'h75);
        expect_menu_sel_within(2'd0, 250000, "over menu up moves to restart");
        expect_over_layout_invariant_within(250000, "over layout invariant after up");
        expect_over_selected_visual_within(2'd0, 250000, "over restart selected visual 2");

        $display("[INFO] over menu press ArrowDown -> START MENU");
        ps2_send_ext_make(8'h72);
        expect_menu_sel_within(2'd1, 250000, "over menu down moves to start menu");
        expect_over_layout_invariant_within(250000, "over layout invariant after down");
        expect_over_selected_visual_within(2'd1, 250000, "over start menu selected visual 3");

        // Choose START MENU and verify back to start screen.
        $display("[INFO] over menu press Enter (start menu)");
        ps2_send_make(8'h5A);
        expect_start_screen_within(300000, "start menu option returns to start screen");
        expect_menu_sel_within(2'd0, 250000, "start menu selection default after return");

        // Start game again from start menu.
        $display("[INFO] press Enter to start game second round");
        ps2_send_make(8'h5A);
        expect_game_init_within(1800000, "second round game init");

        // Self death and final score display.
        force_self_death_setup(32'd12);
        expect_game_over_banner_within(250000, "self hit enters game over");
        expect_final_score_display_within(12, 250000, "self death final score displayed");

        // Choose RESTART and verify direct game start (not start screen).
        $display("[INFO] over menu press Enter (restart direct)");
        ps2_send_make(8'h5A);
        expect_game_init_within(1800000, "restart directly enters game");

        // Trigger one more game over to validate EXIT branch in 3-option menu.
        wall_score_expected = score_word();
        force_wall_death_setup();
        expect_game_over_banner_within(250000, "third round wall hit enters game over");

        // Choose exit and verify BYE.
        $display("[INFO] over menu press S,S then Enter (exit)");
        ps2_send_make(8'h1B);
        expect_menu_sel_within(2'd1, 250000, "over menu move to start menu before exit");
        ps2_send_make(8'h1B);
        expect_menu_sel_within(2'd2, 250000, "over menu move to exit before confirm");
        expect_over_selected_visual_within(2'd2, 250000, "over exit selected visual before confirm");
        ps2_send_make(8'h5A);
        expect_bye_within(300000, "exit shows BYE");

        $display("[SUMMARY] pass=%0d fail=%0d", pass_count, fail_count);
        if (fail_count == 0)
            $display("[RESULT] snake gameplay full test PASSED");
        else
            $display("[RESULT] snake gameplay full test FAILED");

        $finish;
    end
endmodule
