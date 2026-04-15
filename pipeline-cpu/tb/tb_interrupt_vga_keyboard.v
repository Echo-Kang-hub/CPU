// tb_interrupt_vga_keyboard.v
// 流水线CPU中断 / VGA / 键盘顶层仿真
// 说明：
// 1) 这个 testbench 会加载 ../inst.txt 和 ../font_data.mem
// 2) 会自动写入一行 VGA 标题，方便你在波形里确认显示链路
// 3) 会发送 PS/2 扫描码，并强制打开键盘中断使能，便于观察中断进入
`timescale 1ns / 1ps

module tb_interrupt_vga_keyboard;
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

    integer cycle;

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
        sw_i = 16'h0000;
        ps2_clk = 1'b1;
        ps2_data = 1'b1;
        cycle = 0;
    end

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (rstn) begin
            cycle <= cycle + 1;
        end
    end

    task wait_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                @(posedge clk);
            end
        end
    endtask

    task write_vga_char;
        input integer index;
        input [7:0] ch;
        begin
            UUT.U_VGA.chr_mem[index] = ch;
        end
    endtask

    task write_vga_string;
        input integer row;
        input integer col;
        input integer length;
        input [8*64-1:0] text;
        integer i;
        begin
            for (i = 0; i < length; i = i + 1) begin
                write_vga_char(row * 80 + col + i, text[8*(length - 1 - i) +: 8]);
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

    task show_banner;
        begin
            write_vga_string(0, 0, 19, "INT + VGA + KBD SIM");
            write_vga_string(1, 0, 39, "watch interrupt_taken and key_interrupt");
            write_vga_string(2, 0, 27, "send scan code 1C for key A");
        end
    endtask

    always @(posedge clk) begin
        if (rstn) begin
            if (UUT.U_MIO.vga_write_enable) begin
                $display("[%0t] VGA write addr=%0d data=0x%02h", $time, UUT.U_MIO.vga_write_addr, UUT.U_MIO.vga_write_data);
            end

            if (UUT.U_MIO.key_interrupt) begin
                $display("[%0t] key_interrupt=1 key_ready=%b key_code=0x%02h", $time, UUT.U_MIO.key_ready, UUT.U_MIO.key_code);
            end

            if (UUT.U_CPU.interrupt_taken) begin
                $display("[%0t] interrupt_taken=1 PC=0x%08h mtvec=0x%08h mepc=0x%08h mcause=0x%08h mstatus=0x%08h",
                         $time,
                         UUT.U_CPU.current_PC,
                         UUT.U_CPU.mtvec,
                         UUT.U_CPU.mepc,
                         UUT.U_CPU.mcause,
                         UUT.U_CPU.mstatus);
            end
        end
    end

    initial begin
        $dumpfile("tb_interrupt_vga_keyboard.vcd");
        $dumpvars(0, tb_interrupt_vga_keyboard);

        $readmemh("../inst.txt", UUT.U_IM.ROM);
        $readmemh("../font_data.mem", UUT.U_VGA.font_mem);

        wait_cycles(5);
        rstn = 1'b1;
        wait_cycles(5);

        show_banner();

        force UUT.U_MIO.key_interrupt_enable = 1'b1;

        wait_cycles(20);

        $display("[%0t] send keyboard make/break: A (scan code 0x1C)", $time);
        ps2_send_make_break(8'h1C);

        wait_cycles(40);

        $display("[%0t] send keyboard make/break: Enter (scan code 0x5A)", $time);
        ps2_send_make_break(8'h5A);

        wait_cycles(400);

        release UUT.U_MIO.key_interrupt_enable;
        $display("Simulation finished at cycle %0d", cycle);
        $finish;
    end
endmodule
