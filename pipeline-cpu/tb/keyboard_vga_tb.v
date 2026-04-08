`timescale 1ns / 1ps
`include "xgriscv_fpga_top.v"

module keyboard_vga_tb();

    // 时钟和复位
    reg         clk;
    reg         rstn;
    
    // 开关输入
    reg  [15:0] sw_i;
    
    // 七段显示
    wire [7:0]  disp_seg_o;
    wire [7:0]  disp_an_o;
    
    // PS/2键盘接口
    reg         ps2_clk;
    reg         ps2_data;
    
    // VGA输出
    wire [3:0]  vga_r, vga_g, vga_b;
    wire        vga_hsync, vga_vsync;
    integer     cycle_count;
    reg         prev_key_ready;
    reg         prev_vga_we;
    localparam integer MAX_CYCLES = 10_000_000; // 50MHz下约200ms
    
    // 实例化FPGA顶层模块
    xgriscv_fpga_top uut (
        .clk         (clk),
        .rstn        (rstn),
        .sw_i        (sw_i),
        .disp_seg_o  (disp_seg_o),
        .disp_an_o   (disp_an_o),
        .ps2_clk     (ps2_clk),
        .ps2_data    (ps2_data),
        .vga_r       (vga_r),
        .vga_g       (vga_g),
        .vga_b       (vga_b),
        .vga_hsync   (vga_hsync),
        .vga_vsync   (vga_vsync)
    );
    
    // 时钟生成 (50MHz)
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 50MHz
    end

    // 全局超时保护，防止测试平台异常卡住
    initial begin
        #(200_000_000); // 200ms
        $display("\n[TB-TIMEOUT] Keyboard VGA test exceeded 200ms, force stop.");
        $finish;
    end
    
    // PS/2时钟生成 (约12.5kHz)
    reg [15:0] ps2_clk_cnt;
    initial begin
        ps2_clk = 1;
        ps2_clk_cnt = 0;
    end
    
    always @(posedge clk) begin
        if (ps2_clk_cnt >= 2000) begin // 50MHz / 4000 = 12.5kHz
            ps2_clk <= ~ps2_clk;
            ps2_clk_cnt <= 0;
        end else begin
            ps2_clk_cnt <= ps2_clk_cnt + 1;
        end
    end
    
    // 发送PS/2扫描码任务
    task send_ps2_code;
        input [7:0] code;
        integer i;
        reg parity;
        begin
            // 计算校验位 (奇校验)
            parity = ~(code[0] ^ code[1] ^ code[2] ^ code[3] ^ 
                       code[4] ^ code[5] ^ code[6] ^ code[7]);
            
            // 等待PS/2时钟下降沿
            @(negedge ps2_clk);
            
            // 发送起始位 (0)
            ps2_data = 0;
            @(negedge ps2_clk);
            
            // 发送8位数据 (LSB先)
            for (i = 0; i < 8; i = i + 1) begin
                ps2_data = code[i];
                @(negedge ps2_clk);
            end
            
            // 发送校验位
            ps2_data = parity;
            @(negedge ps2_clk);
            
            // 发送停止位 (1)
            ps2_data = 1;
            @(negedge ps2_clk);
            
            // 释放数据线
            ps2_data = 1;
        end
    endtask
    
    // 等待指定毫秒数
    task wait_ms;
        input [31:0] ms;
        begin
            #(ms * 1000000); // 转换为纳秒
        end
    endtask
    
    // 主测试流程
    initial begin
        // 初始化信号
        rstn = 1;
        sw_i = 16'h0000;
        ps2_data = 1;
        cycle_count = 0;
        prev_key_ready = 0;
        prev_vga_we = 0;
        
        // 复位
        #100;
        rstn = 0;
        #200;
        rstn = 1;
        
        // 等待系统初始化
        wait_ms(10);
        
        $display("========================================");
        $display("Keyboard VGA Test Start");
        $display("========================================");
        
        // 测试1: 发送 'a' (扫描码 0x1C)
        $display("[%0t] Test 1: Sending 'a' (scan code 0x1C)", $time);
        wait_ms(5);
        send_ps2_code(8'h1C);
        wait_ms(10);
        
        // 检查VGA字符内存位置0
        $display("[%0t] VGA char[0] = 0x%h (expect 0x61='a')", 
                 $time, uut.U_VGA.chr_mem[0]);
        
        // 测试2: 发送 'b' (扫描码 0x32)
        $display("[%0t] Test 2: Sending 'b' (scan code 0x32)", $time);
        wait_ms(5);
        send_ps2_code(8'h32);
        wait_ms(10);
        
        // 检查VGA字符内存位置1
        $display("[%0t] VGA char[1] = 0x%h (expect 0x62='b')", 
                 $time, uut.U_VGA.chr_mem[1]);
        
        // 测试3: 发送 'c' (扫描码 0x21)
        $display("[%0t] Test 3: Sending 'c' (scan code 0x21)", $time);
        wait_ms(5);
        send_ps2_code(8'h21);
        wait_ms(10);
        
        // 检查VGA字符内存位置2
        $display("[%0t] VGA char[2] = 0x%h (expect 0x63='c')", 
                 $time, uut.U_VGA.chr_mem[2]);
        
        // 测试4: 发送空格 (扫描码 0x29)
        $display("[%0t] Test 4: Sending SPACE (scan code 0x29)", $time);
        wait_ms(5);
        send_ps2_code(8'h29);
        wait_ms(10);
        
        // 检查VGA字符内存位置3
        $display("[%0t] VGA char[3] = 0x%h (expect 0x20=' ')", 
                 $time, uut.U_VGA.chr_mem[3]);
        
        // 测试5: 发送 '1' (扫描码 0x16)
        $display("[%0t] Test 5: Sending '1' (scan code 0x16)", $time);
        wait_ms(5);
        send_ps2_code(8'h16);
        wait_ms(10);
        
        // 检查VGA字符内存位置4
        $display("[%0t] VGA char[4] = 0x%h (expect 0x31='1')", 
                 $time, uut.U_VGA.chr_mem[4]);
        
        // 测试6: 发送 'H' - 需要先发Shift (0x12) 再发 'h' (0x33)
        // 注意: 本程序不处理Shift，所以会显示小写 'h'
        $display("[%0t] Test 6: Sending 'h' (scan code 0x33)", $time);
        wait_ms(5);
        send_ps2_code(8'h33);
        wait_ms(10);
        
        // 检查VGA字符内存位置5
        $display("[%0t] VGA char[5] = 0x%h (expect 0x68='h')", 
                 $time, uut.U_VGA.chr_mem[5]);
        
        // 测试7: 发送 'i' (扫描码 0x43)
        $display("[%0t] Test 7: Sending 'i' (scan code 0x43)", $time);
        wait_ms(5);
        send_ps2_code(8'h43);
        wait_ms(10);
        
        // 检查VGA字符内存位置6
        $display("[%0t] VGA char[6] = 0x%h (expect 0x69='i')", 
                 $time, uut.U_VGA.chr_mem[6]);
        
        // 显示最终结果
        $display("========================================");
        $display("Test Complete - VGA Display Content:");
        $display("========================================");
        $display("Position 0: 0x%h ('%c')", uut.U_VGA.chr_mem[0], uut.U_VGA.chr_mem[0]);
        $display("Position 1: 0x%h ('%c')", uut.U_VGA.chr_mem[1], uut.U_VGA.chr_mem[1]);
        $display("Position 2: 0x%h ('%c')", uut.U_VGA.chr_mem[2], uut.U_VGA.chr_mem[2]);
        $display("Position 3: 0x%h ('%c')", uut.U_VGA.chr_mem[3], uut.U_VGA.chr_mem[3]);
        $display("Position 4: 0x%h ('%c')", uut.U_VGA.chr_mem[4], uut.U_VGA.chr_mem[4]);
        $display("Position 5: 0x%h ('%c')", uut.U_VGA.chr_mem[5], uut.U_VGA.chr_mem[5]);
        $display("Position 6: 0x%h ('%c')", uut.U_VGA.chr_mem[6], uut.U_VGA.chr_mem[6]);
        $display("========================================");
        
        // 验证结果
        if (uut.U_VGA.chr_mem[0] == 8'h61 &&
            uut.U_VGA.chr_mem[1] == 8'h62 &&
            uut.U_VGA.chr_mem[2] == 8'h63 &&
            uut.U_VGA.chr_mem[3] == 8'h20 &&
            uut.U_VGA.chr_mem[4] == 8'h31 &&
            uut.U_VGA.chr_mem[5] == 8'h68 &&
            uut.U_VGA.chr_mem[6] == 8'h69) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("SOME TESTS FAILED!");
        end
        
        $finish;
    end
    
    // 监控CPU执行
    always @(posedge clk) begin
        if (uut.U_CPU.u_MA_stage.MA_csr_we) begin
            $display("[%0t] CSR Write: addr=0x%h, data=0x%h", 
                     $time, uut.U_CPU.u_MA_stage.MA_csr_addr, 
                     uut.U_CPU.u_MA_stage.MA_csr_write_data);
        end
    end
    
    // 监控键盘读取
    always @(posedge clk) begin
        if (uut.U_KBD.key_ready && !prev_key_ready) begin
            $display("[%0t] Key Ready: code=0x%h", $time, uut.U_KBD.key_code);
        end
        prev_key_ready <= uut.U_KBD.key_ready;
    end
    
    // 监控VGA写入
    always @(posedge clk) begin
        if (uut.U_VGA.cpu_we && !prev_vga_we) begin
            $display("[%0t] VGA Write: addr=%0d, char=0x%h ('%c')", 
                     $time, uut.U_VGA.cpu_addr, uut.U_VGA.cpu_char, 
                     uut.U_VGA.cpu_char);
        end
        prev_vga_we <= uut.U_VGA.cpu_we;
    end

    // 周期watchdog，防止异常路径无限运行
    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
        if (cycle_count >= MAX_CYCLES) begin
            $display("\n[TB-WATCHDOG] Keyboard VGA reached MAX_CYCLES=%0d, force stop.", MAX_CYCLES);
            $finish;
        end
    end

endmodule
