// tb_polling_keyboard.v
// 轮询式键盘读取 + VGA 写入仿真
// 说明：
// 1) 加载 polling_test.txt（13 条轮询程序）和 ../font_data.mem
// 2) 不强制中断使能，CPU 通过轮询读取键盘状态
// 3) 发送单个 PS/2 扫描码，观察 CPU 轮询 → 读取 → 写 VGA 的完整过程
`timescale 1ns / 1ps

module tb_polling_keyboard_vga;
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

    // 100MHz clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    task ps2_send_byte;
        input [7:0] code;
        integer i;
        reg [10:0] frame;
        begin
            frame[0] = 1'b0;            // start bit
            frame[8:1] = code;          // data bits
            frame[9] = ~(^code);        // odd parity
            frame[10] = 1'b1;           // stop bit

            for (i = 0; i < 11; i = i + 1) begin
                ps2_data = frame[i];
                #40 ps2_clk = 1'b0;
                #40 ps2_clk = 1'b1;
            end

            ps2_data = 1'b1;
            #160;
        end
    endtask

    // Monitor VGA writes
    always @(posedge clk) begin
        if (rstn && UUT.vga_write_enable)
            $display("[%0t] VGA write addr=%0d data=0x%02h",
                     $time, UUT.vga_write_addr, UUT.vga_write_data);
    end

    // Monitor keyboard ready rising edge
    reg key_ready_d;
    always @(posedge clk) key_ready_d <= UUT.key_ready;
    wire key_ready_rise = UUT.key_ready & ~key_ready_d;
    always @(posedge clk) begin
        if (rstn && key_ready_rise)
            $display("[%0t] key_ready rose, key_code=0x%02h",
                     $time, UUT.key_code_sync1);
    end

    initial begin
        $dumpfile("tb_polling_keyboard_vga.vcd");
        $dumpvars(0, tb_polling_keyboard_vga);

        $readmemh("polling_test.txt", UUT.U_IM.ROM);
        $readmemh("../font_data.mem", UUT.U_VGA.font_mem);

        // Init
        rstn = 1'b0;
        ps2_clk = 1'b1;
        ps2_data = 1'b1;
        sw_i = 16'h0000;

        // Release reset
        #50 rstn = 1'b1;

        // Send PS/2 scan code 0x1C ('A') - start early so VGA write lands ~1800ns
        #100;
        $display("[%0t] === Sending PS/2 scan code 0x1C (A) ===", $time);
        ps2_send_byte(8'h1C);

        // Wait for CPU to complete poll → read → store → VGA write
        #1500;

        $display("[%0t] === Simulation finished ===", $time);
        $finish;
    end
endmodule
