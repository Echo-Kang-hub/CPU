`timescale 1ns / 1ps

// 直接测试键盘->转换表->VGA显示
module keyboard_vga_direct_tb();

    reg clk;
    reg reset;
    reg ps2_clk;
    reg ps2_data;
    
    // PS/2键盘
    wire [7:0] key_code;
    wire key_ready;
    reg key_read;
    
    ps2_keyboard U_KBD (
        .clk                  (clk),
        .reset                (reset),
        .ps2_clk              (ps2_clk),
        .ps2_data             (ps2_data),
        .key_read_acknowledge (key_read),
        .key_code             (key_code),
        .key_ready            (key_ready)
    );
    
    // 扫描码->ASCII转换表 (256字节)
    reg [7:0] scan2ascii [0:255];
    initial begin
        $readmemh("scan2ascii.hex", scan2ascii);
    end
    
    // VGA显示
    reg [12:0] vga_addr;
    reg [7:0]  vga_char;
    reg        vga_we;
    
    vga_display U_VGA (
        .clk       (clk),
        .reset     (reset),
        .cpu_addr  (vga_addr),
        .cpu_char  (vga_char),
        .cpu_we    (vga_we),
        .vga_r     (),
        .vga_g     (),
        .vga_b     (),
        .vga_hsync (),
        .vga_vsync ()
    );
    
    // 系统时钟
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // PS/2手动发送任务
    task send_bit;
        input bit_val;
        begin
            ps2_data = bit_val;
            #40000;
            ps2_clk = 0;
            #40000;
            ps2_clk = 1;
        end
    endtask
    
    task send_ps2_code;
        input [7:0] code;
        reg parity;
        begin
            parity = ~(code[0] ^ code[1] ^ code[2] ^ code[3] ^ 
                       code[4] ^ code[5] ^ code[6] ^ code[7]);
            
            #1000;
            send_bit(0);           // 起始位
            send_bit(code[0]);     // D0
            send_bit(code[1]);     // D1
            send_bit(code[2]);     // D2
            send_bit(code[3]);     // D3
            send_bit(code[4]);     // D4
            send_bit(code[5]);     // D5
            send_bit(code[6]);     // D6
            send_bit(code[7]);     // D7
            send_bit(parity);      // 校验位
            send_bit(1);           // 停止位
            #40000;
        end
    endtask
    
    // 模拟CPU读取键盘并写入VGA
    reg [7:0] display_pos;
    
    always @(posedge clk) begin
        if (reset) begin
            display_pos <= 0;
            key_read <= 0;
            vga_we <= 0;
            vga_addr <= 0;
            vga_char <= 0;
        end else begin
            // 默认值
            key_read <= 0;
            vga_we <= 0;
            
            // 如果有按键
            if (key_ready && !key_read) begin
                // 读取扫描码
                key_read <= 1;
                
                // 查表转换为ASCII
                vga_addr <= display_pos;
                vga_char <= scan2ascii[key_code];
                vga_we <= 1;
                
                $display("[%0t] Key pressed: scan=0x%h, ascii=0x%h ('%c'), pos=%0d", 
                         $time, key_code, scan2ascii[key_code], scan2ascii[key_code], display_pos);
                
                // 更新显示位置
                display_pos <= display_pos + 1;
            end
        end
    end
    
    // 主测试
    initial begin
        $display("========================================");
        $display("Keyboard VGA Direct Test");
        $display("========================================");
        
        // 初始化
        reset = 1;
        ps2_clk = 1;
        ps2_data = 1;
        
        #1000;
        reset = 0;
        
        #5000;
        
        // 测试1: 'h' (0x33)
        $display("\n[%0t] Test 1: Sending 'h' (0x33)", $time);
        send_ps2_code(8'h33);
        #200000;
        
        // 测试2: 'e' (0x24)
        $display("\n[%0t] Test 2: Sending 'e' (0x24)", $time);
        send_ps2_code(8'h24);
        #200000;
        
        // 测试3: 'l' (0x4B)
        $display("\n[%0t] Test 3: Sending 'l' (0x4B)", $time);
        send_ps2_code(8'h4B);
        #200000;
        
        // 测试4: 'l' (0x4B)
        $display("\n[%0t] Test 4: Sending 'l' (0x4B)", $time);
        send_ps2_code(8'h4B);
        #200000;
        
        // 测试5: 'o' (0x44)
        $display("\n[%0t] Test 5: Sending 'o' (0x44)", $time);
        send_ps2_code(8'h44);
        #200000;
        
        // 测试6: 空格 (0x29)
        $display("\n[%0t] Test 6: Sending SPACE (0x29)", $time);
        send_ps2_code(8'h29);
        #200000;
        
        // 测试7: 'W' (0x1D)
        $display("\n[%0t] Test 7: Sending 'w' (0x1D)", $time);
        send_ps2_code(8'h1D);
        #200000;
        
        // 测试8: 'o' (0x44)
        $display("\n[%0t] Test 8: Sending 'o' (0x44)", $time);
        send_ps2_code(8'h44);
        #200000;
        
        // 测试9: 'r' (0x2D)
        $display("\n[%0t] Test 9: Sending 'r' (0x2D)", $time);
        send_ps2_code(8'h2D);
        #200000;
        
        // 测试10: 'l' (0x4B)
        $display("\n[%0t] Test 10: Sending 'l' (0x4B)", $time);
        send_ps2_code(8'h4B);
        #200000;
        
        // 测试11: 'd' (0x23)
        $display("\n[%0t] Test 11: Sending 'd' (0x23)", $time);
        send_ps2_code(8'h23);
        #200000;
        
        // 显示最终结果
        $display("\n========================================");
        $display("Final VGA Display Content:");
        $display("========================================");
        print_vga_content(11);
        
        // 验证
        $display("\n========================================");
        $display("Verification:");
        $display("========================================");
        check_vga(0, "h", "h");
        check_vga(1, "e", "e");
        check_vga(2, "l", "l");
        check_vga(3, "l", "l");
        check_vga(4, "o", "o");
        check_vga(5, " ", "space");
        check_vga(6, "w", "w");
        check_vga(7, "o", "o");
        check_vga(8, "r", "r");
        check_vga(9, "l", "l");
        check_vga(10, "d", "d");
        
        $display("\n========================================");
        $display("Test Complete!");
        $display("========================================");
        
        $finish;
    end
    
    // 打印VGA内容
    task print_vga_content;
        input [7:0] count;
        integer i;
        begin
            $write("  ");
            for (i = 0; i < count; i = i + 1) begin
                if (U_VGA.chr_mem[i] >= 8'h20 && U_VGA.chr_mem[i] <= 8'h7E) begin
                    $write("%c", U_VGA.chr_mem[i]);
                end else begin
                    $write(".");
                end
            end
            $display("");
        end
    endtask
    
    // 检查VGA内容
    task check_vga;
        input [7:0] pos;
        input [7:0] expected;
        input [7:0] name;
        begin
            if (U_VGA.chr_mem[pos] == expected) begin
                $display("  ✓ VGA[%0d] = '%c' - CORRECT", pos, expected);
            end else begin
                $display("  ✗ VGA[%0d] = 0x%h ('%c'), Expected: '%c' - FAILED", 
                         pos, U_VGA.chr_mem[pos], U_VGA.chr_mem[pos], expected);
            end
        end
    endtask

endmodule
