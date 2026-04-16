`timescale 1ns / 1ps

// Verify snake really starts moving after Enter and still accepts WASD in game loop.
module tb_snake_enter_move;
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

    localparam integer HEAD_X_WORD = 64; // 0x0300 byte0
    localparam integer HEAD_Y_WORD = 96; // 0x0380 byte0
    localparam integer ROM_IDX_JAL_FLUSH = 15;

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
        sw_i = 16'h0001; // non-zero switch bypasses delay_tick; SW15 still 0
        ps2_clk = 1'b1;
        ps2_data = 1'b1;
        pass_count = 0;
        fail_count = 0;
    end

    always #5 clk = ~clk;

    function [7:0] head_x;
        begin
            head_x = UUT.U_DM.RAM[HEAD_X_WORD][7:0];
        end
    endfunction

    function [7:0] head_y;
        begin
            head_y = UUT.U_DM.RAM[HEAD_Y_WORD][7:0];
        end
    endfunction

    function [31:0] dir_word;
        begin
            dir_word = UUT.U_DM.RAM[3]; // direction at 12(x18)
        end
    endfunction

    function menu_sel;
        begin
            menu_sel = UUT.U_DM.RAM[10][0]; // menu_sel at 40(x18)
        end
    endfunction

    function [7:0] vga_char_at;
        input integer col;
        input integer row;
        integer idx;
        begin
            idx = row * 80 + col;
            vga_char_at = UUT.U_VGA.chr_mem[idx];
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

    task ps2_send_make_break;
        input [7:0] code;
        begin
            ps2_send_byte(code);
            ps2_send_byte(8'hF0);
            ps2_send_byte(code);
        end
    endtask

    task expect_menu_boot;
        input integer max_cycles;
        integer i;
        reg hit;
        begin
            hit = 1'b0;
            for (i = 0; i < max_cycles; i = i + 1) begin
                if (menu_sel() === 1'b0) begin
                    hit = 1'b1;
                    i = max_cycles;
                end
                @(posedge clk);
            end

            if (hit) begin
                pass_count = pass_count + 1;
                $display("[PASS] boot menu ready menu_sel=%0d", menu_sel());
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] boot menu not ready in %0d cycles", max_cycles);
            end
        end
    endtask

    task expect_game_init;
        input integer max_cycles;
        integer i;
        reg hit;
        begin
            hit = 1'b0;
            for (i = 0; i < max_cycles; i = i + 1) begin
                // snake_len at 8(x18) => RAM[2], direction at RAM[3]
                if ((UUT.U_DM.RAM[2] == 32'd5) && (dir_word() == 32'd1)) begin
                    hit = 1'b1;
                    i = max_cycles;
                end
                @(posedge clk);
            end

            if (hit) begin
                pass_count = pass_count + 1;
                $display("[PASS] game initialized len=%0d dir=%0d", UUT.U_DM.RAM[2], dir_word());
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] game init timeout len=%0d dir=%0d", UUT.U_DM.RAM[2], dir_word());
            end
        end
    endtask

    task expect_head_move;
        input integer max_cycles;
        input [7:0] expected_x;
        input [7:0] expected_y;
        integer i;
        reg moved;
        reg go_seen;
        reg [7:0] x1;
        reg [7:0] y1;
        begin
            moved = 1'b0;
            go_seen = 1'b0;

            for (i = 0; i < max_cycles; i = i + 1) begin
                @(posedge clk);
                x1 = head_x();
                y1 = head_y();

                if (!go_seen &&
                    (vga_char_at(14, 2) == 8'h47) &&
                    (vga_char_at(15, 2) == 8'h41) &&
                    (vga_char_at(16, 2) == 8'h4D) &&
                    (vga_char_at(17, 2) == 8'h45)) begin
                    go_seen = 1'b1;
                    $display("[INFO] GAME OVER observed during move window at cycle=%0d head=(%0d,%0d) dir=%0d",
                             i, x1, y1, dir_word());
                end

                if ((x1 != expected_x) || (y1 != expected_y)) begin
                    moved = 1'b1;
                    $display("[INFO] head moved at cycle=%0d from (%0d,%0d) to (%0d,%0d)", i, expected_x, expected_y, x1, y1);
                    i = max_cycles;
                end
            end

            if (moved) begin
                pass_count = pass_count + 1;
                $display("[PASS] snake moves after Enter");
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] snake head did not move within %0d cycles (still (%0d,%0d))", max_cycles, expected_x, expected_y);
            end
        end
    endtask

    task expect_head_init_xy;
        input [7:0] expected_x;
        input [7:0] expected_y;
        input integer max_cycles;
        integer i;
        reg hit;
        begin
            hit = 1'b0;
            for (i = 0; i < max_cycles; i = i + 1) begin
                if ((head_x() == expected_x) && (head_y() == expected_y)) begin
                    hit = 1'b1;
                    i = max_cycles;
                end
                @(posedge clk);
            end

            if (hit) begin
                pass_count = pass_count + 1;
                $display("[PASS] head initialized at (%0d,%0d)", expected_x, expected_y);
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] head init timeout expected (%0d,%0d) got (%0d,%0d)", expected_x, expected_y, head_x(), head_y());
            end
        end
    endtask

    task expect_direction;
        input [31:0] expected;
        input integer max_cycles;
        input [8*32-1:0] tag;
        integer i;
        reg hit;
        begin
            hit = 1'b0;
            for (i = 0; i < max_cycles; i = i + 1) begin
                if (dir_word() == expected) begin
                    hit = 1'b1;
                    i = max_cycles;
                end
                @(posedge clk);
            end

            if (hit) begin
                pass_count = pass_count + 1;
                $display("[PASS] %0s direction=%0d", tag, expected);
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] %0s expected direction=%0d got=%0d", tag, expected, dir_word());
            end
        end
    endtask

    task detect_game_over_banner;
        input integer max_cycles;
        integer i;
        reg hit;
        begin
            hit = 1'b0;
            for (i = 0; i < max_cycles; i = i + 1) begin
                @(posedge clk);
                if ((vga_char_at(14, 2) == 8'h47) &&
                    (vga_char_at(15, 2) == 8'h41) &&
                    (vga_char_at(16, 2) == 8'h4D) &&
                    (vga_char_at(17, 2) == 8'h45)) begin
                    hit = 1'b1;
                    $display("[INFO] GAME OVER banner detected at cycle=%0d head=(%0d,%0d) dir=%0d key_ready=%0d ack=%0d",
                             i, head_x(), head_y(), dir_word(), UUT.U_MIO.key_ready, UUT.U_MIO.key_read_acknowledge);
                    i = max_cycles;
                end
            end

            if (!hit) begin
                $display("[INFO] GAME OVER banner not detected in %0d cycles", max_cycles);
            end
        end
    endtask

    initial begin
        $dumpfile("tb_snake_enter_move.vcd");
        $dumpvars(0, tb_snake_enter_move);

        $readmemh("D:/FileDownload/Projects/CPU/pipeline-cpu/inst.txt", UUT.U_IM.ROM);
        $readmemh("D:/FileDownload/Projects/CPU/pipeline-cpu/fpga/font_data.mem", UUT.U_VGA.font_mem);

        // Temporary diagnosis: bypass flush_kbd_buffer call at start_game.
        // If movement recovers, root cause is inside flush path.
        UUT.U_IM.ROM[ROM_IDX_JAL_FLUSH] = 32'h00000013; // nop
        $display("[INFO] diag patch: ROM[%0d]=NOP (bypass flush_kbd_buffer)", ROM_IDX_JAL_FLUSH);

        wait_cycles(10);
        rstn = 1'b1;

        expect_menu_boot(800000);

        $display("[INFO] send Enter make (0x5A)");
        ps2_send_byte(8'h5A);

        expect_game_init(300000);
        expect_head_init_xy(8'd20, 8'd6, 150000);
        detect_game_over_banner(50000);
        expect_head_move(50000, 8'd20, 8'd6);

        $display("[INFO] send W make (0x1D)");
        ps2_send_byte(8'h1D);
        expect_direction(32'd0, 50000, "after_W");

        $display("[SUMMARY] pass=%0d fail=%0d", pass_count, fail_count);
        if (fail_count == 0)
            $display("[RESULT] snake enter->move test PASSED");
        else
            $display("[RESULT] snake enter->move test FAILED");

        $finish;
    end
endmodule
