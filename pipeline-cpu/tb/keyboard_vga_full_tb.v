`timescale 1ns / 1ps
`define DMEM_INIT

module keyboard_vga_full_tb();

    reg clk;
    reg reset;
    reg ps2_clk;
    reg ps2_data;
    
    // 实例化CPU
    wire [31:0] pc, instr, dm_addr, dm_wdata;
    wire dm_we;
    reg [31:0] dm_rdata;
    
    pipeline_top U_CPU (
        .clk             (clk),
        .reset           (reset),
        .instr_addr      (pc),
        .instr           (instr),
        .DM_write_addr   (dm_addr),
        .DM_write_data   (dm_wdata),
        .DM_write_enable (dm_we),
        .DM_Type         (),
        .DM_read_data    (dm_rdata)
    );
    
    // 指令存储器
    imem U_IM (
        .a    (pc[8:2]),
        .spo  (instr)
    );
    
    // 数据存储器
    wire [31:0] dm_rdata_ram;
    dmem U_DM (
        .clk    (clk),
        .DMWr   (dm_we & (dm_addr[31:16] != 16'hffff)),
        .DMType (3'b010),
        .addr   (dm_addr),
        .din    (dm_wdata),
        .dout   (dm_rdata_ram)
    );
    
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
    
    // I/O 地址解码
    always @(*) begin
        dm_rdata = 32'h0;
        key_read = 1'b0;
        vga_we = 1'b0;
        vga_addr = 13'h0;
        vga_char = 8'h0;
        
        case (dm_addr[31:0])
            32'hffff_0010: begin
                dm_rdata = {24'h0, key_code};
                key_read = dm_we;
            end
            32'hffff_0014: begin
                dm_rdata = {31'h0, key_ready};
            end
            32'hffff_0020: begin
                vga_we = dm_we;
                vga_addr = dm_addr[12:2];
                vga_char = dm_wdata[7:0];
            end
            default: begin
                dm_rdata = dm_rdata_ram;
            end
        endcase
    end
    
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
    
    // 主测试
    initial begin
        $display("========================================");
        $display("Keyboard VGA Full Test");
        $display("========================================");
        
        // 初始化
        reset = 1;
        ps2_clk = 1;
        ps2_data = 1;
        
        #1000;
        reset = 0;
        
        // 等待CPU初始化
        #5000;
        
        // 测试1: 发送 'H' (0x33 - PS/2扫描码)
        $display("\n[%0t] Test 1: Sending 'h' (scan code 0x33)", $time);
        send_ps2_code(8'h33);
        #100000;
        check_vga(0, "h");
        
        // 测试2: 发送 'e' (0x24)
        $display("\n[%0t] Test 2: Sending 'e' (scan code 0x24)", $time);
        send_ps2_code(8'h24);
        #100000;
        check_vga(1, "e");
        
        // 测试3: 发送 'l' (0x4B)
        $display("\n[%0t] Test 3: Sending 'l' (scan code 0x4B)", $time);
        send_ps2_code(8'h4B);
        #100000;
        check_vga(2, "l");
        
        // 测试4: 发送 'l' (0x4B)
        $display("\n[%0t] Test 4: Sending 'l' (scan code 0x4B)", $time);
        send_ps2_code(8'h4B);
        #100000;
        check_vga(3, "l");
        
        // 测试5: 发送 'o' (0x44)
        $display("\n[%0t] Test 5: Sending 'o' (scan code 0x44)", $time);
        send_ps2_code(8'h44);
        #100000;
        check_vga(4, "o");
        
        // 测试6: 发送空格 (0x29)
        $display("\n[%0t] Test 6: Sending SPACE (scan code 0x29)", $time);
        send_ps2_code(8'h29);
        #100000;
        check_vga(5, " ");
        
        // 测试7: 发送 'W' (0x1D - w)
        $display("\n[%0t] Test 7: Sending 'w' (scan code 0x1D)", $time);
        send_ps2_code(8'h1D);
        #100000;
        check_vga(6, "w");
        
        // 测试8: 发送 'o' (0x44)
        $display("\n[%0t] Test 8: Sending 'o' (scan code 0x44)", $time);
        send_ps2_code(8'h44);
        #100000;
        check_vga(7, "o");
        
        // 测试9: 发送 'r' (0x2D)
        $display("\n[%0t] Test 9: Sending 'r' (scan code 0x2D)", $time);
        send_ps2_code(8'h2D);
        #100000;
        check_vga(8, "r");
        
        // 测试10: 发送 'l' (0x4B)
        $display("\n[%0t] Test 10: Sending 'l' (scan code 0x4B)", $time);
        send_ps2_code(8'h4B);
        #100000;
        check_vga(9, "l");
        
        // 测试11: 发送 'd' (0x23)
        $display("\n[%0t] Test 11: Sending 'd' (scan code 0x23)", $time);
        send_ps2_code(8'h23);
        #100000;
        check_vga(10, "d");
        
        // 测试12: 发送 '!' (0x16 - 数字1，用于测试)
        $display("\n[%0t] Test 12: Sending '1' (scan code 0x16)", $time);
        send_ps2_code(8'h16);
        #100000;
        check_vga(11, "1");
        
        // 显示最终结果
        $display("\n========================================");
        $display("Final VGA Display Content:");
        $display("========================================");
        print_vga_content(12);
        
        $display("\n========================================");
        $display("Test Complete!");
        $display("========================================");
        
        $finish;
    end
    
    // 检查VGA内容
    task check_vga;
        input [7:0] pos;
        input [7:0] expected_char;
        begin
            #100;  // 等待写入完成
            if (U_VGA.chr_mem[pos] == expected_char) begin
                $display("  ✓ VGA[%0d] = 0x%h ('%c') - CORRECT", 
                         pos, U_VGA.chr_mem[pos], U_VGA.chr_mem[pos]);
            end else begin
                $display("  ✗ VGA[%0d] = 0x%h ('%c'), Expected: 0x%h ('%c') - FAILED", 
                         pos, U_VGA.chr_mem[pos], U_VGA.chr_mem[pos],
                         expected_char, expected_char);
            end
        end
    endtask
    
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
    
    // 监控关键信号
    always @(posedge clk) begin
        if (key_ready) begin
            $display("  [%0t] Key Ready: scan_code=0x%h", $time, key_code);
        end
        if (vga_we) begin
            $display("  [%0t] VGA Write: pos=%0d, char=0x%h ('%c')", 
                     $time, vga_addr, vga_char, vga_char);
        end
    end

endmodule
