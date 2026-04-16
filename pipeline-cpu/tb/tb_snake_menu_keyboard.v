`timescale 1ns / 1ps

// Focused regression for snake_vga start-menu keyboard navigation.
// Checks whether menu highlight toggles with:
// - W/S (set-2 0x1D / 0x1B)
// - ArrowUp/ArrowDown (set-2 E0 75 / E0 72)
module tb_snake_menu_keyboard;
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
    integer kbd_status_read_edges;
    integer kbd_data_read_edges;
    reg prev_key_ready;
    reg prev_status_read;
    reg prev_data_read;

    localparam integer START_ARROW_ROW = 8;
    localparam integer START_ARROW_COL = 12;
    localparam integer EXIT_ARROW_ROW  = 10;
    localparam integer EXIT_ARROW_COL  = 15;
    localparam [7:0] HIGHLIGHT_GT = 8'hBE; // '>' with highlight bit
    localparam [7:0] SPACE_CHAR   = 8'h20;

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
        sw_i = 16'h0000;   // SW15=0 -> faster CPU clock divider path
        ps2_clk = 1'b1;
        ps2_data = 1'b1;
        pass_count = 0;
        fail_count = 0;
        kbd_status_read_edges = 0;
        kbd_data_read_edges = 0;
        prev_key_ready = 1'b0;
        prev_status_read = 1'b0;
        prev_data_read = 1'b0;
    end

    always #5 clk = ~clk;

    function [7:0] chr_at;
        input integer row;
        input integer col;
        begin
            chr_at = UUT.U_VGA.chr_mem[row * 80 + col];
        end
    endfunction

    task wait_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                @(posedge clk);
            end
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

    task show_kdebug;
        input [8*32-1:0] tag;
        reg [7:0] c0;
        reg [7:0] c1;
        reg [7:0] c2;
        reg [7:0] c3;
        begin
            c0 = chr_at(0, 32);
            c1 = chr_at(0, 33);
            c2 = chr_at(0, 34);
            c3 = chr_at(0, 35);
            $display("[KDBG] %0s chars=%c%c%c%c hex=%02h %02h %02h %02h", tag, c0, c1, c2, c3, c0, c1, c2, c3);
        end
    endtask

    task show_fifo_state;
        input [8*32-1:0] tag;
        begin
            $display("[FIFO] %0s ready=%b key_code=0x%02h w_ptr=%0d r_ptr=%0d overflow=%b break=%0d ext=%0d PC=0x%08h mmio_addr=0x%08h kbd_status_reads=%0d kbd_data_reads=%0d",
                     tag,
                     UUT.U_KBD.ready_reg,
                     UUT.U_KBD.fifo[UUT.U_KBD.r_ptr],
                     UUT.U_KBD.w_ptr,
                     UUT.U_KBD.r_ptr,
                     UUT.U_KBD.overflow_reg,
                     UUT.U_DM.RAM[6][0],
                     UUT.U_DM.RAM[11][0],
                     UUT.PC,
                     UUT.bus_write_addr,
                     kbd_status_read_edges,
                     kbd_data_read_edges);
        end
    endtask

    task expect_char_within;
        input integer row;
        input integer col;
        input [7:0] expected;
        input integer max_cycles;
        input [8*48-1:0] tag;
        integer i;
        reg hit;
        reg [7:0] final_char;
        begin
            hit = 1'b0;
            for (i = 0; i < max_cycles; i = i + 1) begin
                if (chr_at(row, col) == expected) begin
                    hit = 1'b1;
                    i = max_cycles;
                end
                @(posedge clk);
            end

            final_char = chr_at(row, col);
            if (hit) begin
                pass_count = pass_count + 1;
                $display("[PASS] %0s row=%0d col=%0d expected=0x%02h", tag, row, col, expected);
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] %0s row=%0d col=%0d expected=0x%02h got=0x%02h", tag, row, col, expected, final_char);
            end
        end
    endtask

    task expect_menu_sel_within;
        input expected;
        input integer max_cycles;
        input [8*48-1:0] tag;
        integer i;
        reg hit;
        reg final_val;
        begin
            hit = 1'b0;
            for (i = 0; i < max_cycles; i = i + 1) begin
                if (UUT.U_DM.RAM[10][0] === expected) begin
                    hit = 1'b1;
                    i = max_cycles;
                end
                @(posedge clk);
            end

            final_val = UUT.U_DM.RAM[10][0];
            if (hit) begin
                pass_count = pass_count + 1;
                $display("[PASS] %0s menu_sel=%0d", tag, expected);
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] %0s expected menu_sel=%0d got=%0d", tag, expected, final_val);
            end
        end
    endtask

    task expect_start_selected;
        input [8*48-1:0] phase;
        begin
            expect_char_within(START_ARROW_ROW, START_ARROW_COL, HIGHLIGHT_GT, 120000, {phase, " start_arrow"});
            expect_char_within(EXIT_ARROW_ROW, EXIT_ARROW_COL, SPACE_CHAR, 120000, {phase, " exit_arrow"});
        end
    endtask

    always @(posedge UUT.cpu_clk) begin
        if (rstn) begin
            if ((!UUT.bus_write_enable) && (UUT.bus_write_addr == 32'hffff_0014) && !prev_status_read)
                kbd_status_read_edges <= kbd_status_read_edges + 1;
            if ((!UUT.bus_write_enable) && (UUT.bus_write_addr == 32'hffff_0010) && !prev_data_read)
                kbd_data_read_edges <= kbd_data_read_edges + 1;

            if (UUT.U_MIO.key_ready && !prev_key_ready) begin
                $display("[KBD] ready rise key_code=0x%02h", UUT.U_MIO.key_code);
            end
            if (UUT.U_MIO.key_read_acknowledge) begin
                $display("[KBD] read_ack key_code=0x%02h", UUT.U_MIO.key_code);
            end
        end
        prev_key_ready <= UUT.U_MIO.key_ready;
        prev_status_read <= (!UUT.bus_write_enable) && (UUT.bus_write_addr == 32'hffff_0014);
        prev_data_read <= (!UUT.bus_write_enable) && (UUT.bus_write_addr == 32'hffff_0010);
    end

    task expect_exit_selected;
        input [8*48-1:0] phase;
        begin
            expect_char_within(EXIT_ARROW_ROW, EXIT_ARROW_COL, HIGHLIGHT_GT, 120000, {phase, " exit_arrow"});
            expect_char_within(START_ARROW_ROW, START_ARROW_COL, SPACE_CHAR, 120000, {phase, " start_arrow"});
        end
    endtask

    initial begin
        $dumpfile("tb_snake_menu_keyboard.vcd");
        $dumpvars(0, tb_snake_menu_keyboard);

        // Program image should be generated from coe/snake.coe into inst.txt before running.
        $readmemh("D:/FileDownload/Projects/CPU/pipeline-cpu/inst.txt", UUT.U_IM.ROM);
        $readmemh("D:/FileDownload/Projects/CPU/pipeline-cpu/fpga/font_data.mem", UUT.U_VGA.font_mem);

        wait_cycles(10);
        rstn = 1'b1;

        // Core requirement check: W/S and Up/Down can toggle menu selection.
        // Give software enough time to finish drawing and enter menu polling loop.
        expect_menu_sel_within(1'b0, 800000, "boot");
        wait_cycles(300000);

        // S should toggle to EXIT selected (menu_sel=1).
        $display("[INFO] send S make/break (0x1B)");
        ps2_send_make_break(8'h1B);
        show_kdebug("after_S_send");
        show_fifo_state("after_S_send");
        expect_menu_sel_within(1'b1, 800000, "after_S");
        wait_cycles(300000);

        // W should toggle back to START selected (menu_sel=0).
        $display("[INFO] send W make/break (0x1D)");
        ps2_send_make_break(8'h1D);
        show_kdebug("after_W_send");
        show_fifo_state("after_W_send");
        expect_menu_sel_within(1'b0, 800000, "after_W");
        wait_cycles(300000);

        // ArrowDown (E0 72) should toggle to EXIT selected (menu_sel=1).
        $display("[INFO] send ArrowDown ext make/break (E0 72)");
        ps2_send_ext_make_break(8'h72);
        show_kdebug("after_Down_send");
        show_fifo_state("after_Down_send");
        expect_menu_sel_within(1'b1, 800000, "after_Down");
        wait_cycles(300000);

        // ArrowUp (E0 75) should toggle back to START selected (menu_sel=0).
        $display("[INFO] send ArrowUp ext make/break (E0 75)");
        ps2_send_ext_make_break(8'h75);
        show_kdebug("after_Up_send");
        show_fifo_state("after_Up_send");
        expect_menu_sel_within(1'b0, 800000, "after_Up");

        $display("[SUMMARY] pass=%0d fail=%0d", pass_count, fail_count);
        if (fail_count == 0)
            $display("[RESULT] snake menu keyboard navigation PASSED");
        else
            $display("[RESULT] snake menu keyboard navigation FAILED");

        $finish;
    end
endmodule
