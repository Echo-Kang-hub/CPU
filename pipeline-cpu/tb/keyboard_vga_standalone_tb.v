`timescale 1ns / 1ps

module keyboard_vga_simple_tb();

    reg clk;
    reg reset;
    reg ps2_clk;
    reg ps2_data;
    
    // Keyboard
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
    
    // VGA
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
    
    // 时钟
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // PS/2发送任务
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
            send_bit(0);
            send_bit(code[0]);
            send_bit(code[1]);
            send_bit(code[2]);
            send_bit(code[3]);
            send_bit(code[4]);
            send_bit(code[5]);
            send_bit(code[6]);
            send_bit(code[7]);
            send_bit(parity);
            send_bit(1);
            #40000;
        end
    endtask
    
    // 测试
    reg [7:0] test_count;
    
    initial begin
        $display("========================================");
        $display("Simple Keyboard VGA Test");
        $display("========================================");
        
        reset = 1;
        ps2_clk = 1;
        ps2_data = 1;
        key_read = 1;
        vga_we = 0;
        vga_addr = 0;
        vga_char = 0;
        test_count = 0;
        
        #1000;
        reset = 0;
        #1000;
        
        // 测试1: 发送 'A' (0x1c)
        $display("\n[%0t] Test 1: Sending 'A' (scan code 0x1c)", $time);
        send_ps2_code(8'h1c);
        
        // 等待key_ready
        @(posedge key_ready);
        #100;
        $display("Key Ready: code=0x%h", key_code);
        
        // 写入VGA
        vga_we = 1;
        vga_addr = 0;
        vga_char = key_code;
        #10;
        vga_we = 0;
        
        // 等待并检查
        #10000;
        $display("VGA[0] = 0x%h", U_VGA.chr_mem[0]);
        
        // 读取确认
        key_read = 0;
        #100;
        key_read = 1;
        
        $display("\n========================================");
        $display("Test Complete!");
        $display("========================================");
        $finish;
    end

endmodule
