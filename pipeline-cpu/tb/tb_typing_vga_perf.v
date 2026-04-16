`timescale 1ns / 1ps

module tb_typing_vga_perf;
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

    integer ack_cnt;
    integer vga_char_cnt;
    integer overflow_cnt;

    reg key_ack_d1;
    reg vga_we_d1;

    time t_make_a;
    time t_vga_a;
    reg  a_latency_captured;

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
    `ifdef SLOW_CPU
        sw_i = 16'h8000; // SW15=1, slow debug CPU clock path
    `else
        sw_i = 16'h0000; // SW15=0, fast CPU clock path
    `endif
        ps2_clk = 1'b1;
        ps2_data = 1'b1;
        ack_cnt = 0;
        vga_char_cnt = 0;
        overflow_cnt = 0;
        key_ack_d1 = 1'b0;
        vga_we_d1 = 1'b0;
        t_make_a = 0;
        t_vga_a = 0;
        a_latency_captured = 1'b0;
    end

    always #5 clk = ~clk; // 100MHz

    // Count keyboard acknowledge pulses (edge count)
    always @(posedge clk) begin
        key_ack_d1 <= UUT.key_read_acknowledge;
        if (!key_ack_d1 && UUT.key_read_acknowledge)
            ack_cnt <= ack_cnt + 1;
    end

    // Count VGA writes from CPU side (edge count)
    always @(posedge clk) begin
        vga_we_d1 <= UUT.vga_write_enable;
        if (!vga_we_d1 && UUT.vga_write_enable) begin
            vga_char_cnt <= vga_char_cnt + 1;
            // capture first visible write for 'a' / 'A' after make code sent
            if (!a_latency_captured && (UUT.vga_write_data == 8'h61 || UUT.vga_write_data == 8'h41)) begin
                t_vga_a <= $time;
                a_latency_captured <= 1'b1;
            end
        end
    end

    // Count FIFO overflow events
    reg overflow_d1;
    initial overflow_d1 = 1'b0;
    always @(posedge clk) begin
        overflow_d1 <= UUT.overflow;
        if (!overflow_d1 && UUT.overflow)
            overflow_cnt <= overflow_cnt + 1;
    end

    task wait_clk_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                @(posedge clk);
            end
        end
    endtask

    // PS/2 set-2 frame sender, realistic-ish timing (~12.5kHz)
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
                #40000 ps2_clk = 1'b0;
                #40000 ps2_clk = 1'b1;
            end

            ps2_data = 1'b1;
            #80000;
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

    initial begin
        $dumpfile("tb_typing_vga_perf.vcd");
        $dumpvars(0, tb_typing_vga_perf.clk, tb_typing_vga_perf.rstn);
        $dumpvars(0, tb_typing_vga_perf.UUT.key_ready, tb_typing_vga_perf.UUT.key_code, tb_typing_vga_perf.UUT.key_read_acknowledge);
        $dumpvars(0, tb_typing_vga_perf.UUT.vga_write_enable, tb_typing_vga_perf.UUT.vga_write_data, tb_typing_vga_perf.UUT.vga_write_addr);

        // Load typing program image (readmemh-compatible)
        $readmemh("../coe/typing_vga.mem", UUT.U_IM.ROM);
        $readmemh("../fpga/font_data.mem", UUT.U_VGA.font_mem);

        $display("[PERF] SW15=%0d (0=fast CPU, 1=slow debug CPU)", sw_i[15]);

        wait_clk_cycles(80);
        rstn = 1'b1;
        wait_clk_cycles(4000);

        // Single-key latency probe: 'a' make/break (0x1C)
        t_make_a = $time;
        ps2_send_make_break(8'h1C);

        // Typing burst: a s d f j k l ;
        ps2_send_make_break(8'h1C); // a
        ps2_send_make_break(8'h1B); // s
        ps2_send_make_break(8'h23); // d
        ps2_send_make_break(8'h2B); // f
        ps2_send_make_break(8'h3B); // j
        ps2_send_make_break(8'h42); // k
        ps2_send_make_break(8'h4B); // l
        ps2_send_make_break(8'h4C); // ;

        wait_clk_cycles(200000);

        $display("[PERF] ack_cnt=%0d, vga_char_cnt=%0d, overflow_cnt=%0d", ack_cnt, vga_char_cnt, overflow_cnt);
        if (a_latency_captured)
            $display("[PERF] A-key latency make->vga = %0t ns", (t_vga_a - t_make_a));
        else
            $display("[PERF] A-key latency NOT captured (no a/A write seen)");

        $finish;
    end
endmodule
