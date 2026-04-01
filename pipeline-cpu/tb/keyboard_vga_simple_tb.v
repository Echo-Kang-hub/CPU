`timescale 1ns / 1ps
`define DMEM_INIT

// 简化的键盘VGA测试 - 直接测试核心功能
module keyboard_vga_simple_tb();

    // 时钟和复位
    reg         clk;
    reg         rstn;
    
    // 键盘模拟信号
    reg         ps2_clk;
    reg         ps2_data;
    
    // 直接访问信号
    wire [31:0] pc;
    wire [31:0] instr;
    wire [31:0] dm_addr;
    wire [31:0] dm_wdata;
    wire        dm_we;
    
    // I/O 信号
    wire [7:0]  key_code;
    wire        key_ready;
    reg         key_read;
    
    reg  [12:0] vga_addr;
    reg  [7:0]  vga_char;
    reg         vga_we;
    
    // 数据存储器输出
    wire [31:0] dm_rdata_ram;
    
    // I/O 地址解码
    reg [31:0] dm_rdata;
    always @(*) begin
        dm_rdata = 32'h0;
        key_read = 1'b0;
        vga_we = 1'b0;
        vga_addr = 13'h0;
        vga_char = 8'h0;
        
        case (dm_addr[31:0])
            32'hffff_0010: begin  // 键盘数据
                dm_rdata = {24'h0, key_code};
                key_read = dm_we;
            end
            32'hffff_0014: begin  // 键盘状态
                dm_rdata = {31'h0, key_ready};
            end
            32'hffff_0020: begin  // VGA
                vga_we = dm_we;
                vga_addr = dm_addr[12:2];
                vga_char = dm_wdata[7:0];
            end
            default: begin
                dm_rdata = dm_rdata_ram;
            end
        endcase
    end
    
    // 时钟生成 (10ns周期)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // PS/2时钟生成 (约12.5kHz，周期80us)
    initial begin
        ps2_clk = 1;
        forever begin
            #40000 ps2_clk = 0;  // 40us低电平
            #40000 ps2_clk = 1;  // 40us高电平
        end
    end
    
    // 发送PS/2扫描码
    task send_ps2_code;
        input [7:0] code;
        integer i;
        reg parity;
        begin
            parity = ~(code[0] ^ code[1] ^ code[2] ^ code[3] ^ 
                       code[4] ^ code[5] ^ code[6] ^ code[7]);
            
            @(negedge ps2_clk);
            ps2_data = 0;  // 起始位
            @(negedge ps2_clk);
            
            for (i = 0; i < 8; i = i + 1) begin
                ps2_data = code[i];
                @(negedge ps2_clk);
            end
            
            ps2_data = parity;  // 校验位
            @(negedge ps2_clk);
            ps2_data = 1;  // 停止位
            @(negedge ps2_clk);
            ps2_data = 1;
        end
    endtask
    
    // 主测试
    initial begin
        $display("=== Keyboard VGA Test Start ===");
        
        // 初始化
        rstn = 1;
        ps2_data = 1;
        
        // 复位
        #100;
        rstn = 0;
        #200;
        rstn = 1;
        
        // 等待CPU初始化
        #10000;
        
        // 测试1: 发送 'a' (0x1C)
        $display("[%0t] Sending 'a' (0x1C)", $time);
        #100000;
        send_ps2_code(8'h1C);
        #200000;
        
        // 测试2: 发送 'b' (0x32)
        $display("[%0t] Sending 'b' (0x32)", $time);
        #100000;
        send_ps2_code(8'h32);
        #200000;
        
        // 测试3: 发送 'c' (0x21)
        $display("[%0t] Sending 'c' (0x21)", $time);
        #100000;
        send_ps2_code(8'h21);
        #200000;
        
        // 测试4: 发送空格 (0x29)
        $display("[%0t] Sending SPACE (0x29)", $time);
        #100000;
        send_ps2_code(8'h29);
        #200000;
        
        // 最终结果
        $display("=== Test Complete ===");
        
        $finish;
    end
    
    // 监控CPU执行
    always @(posedge clk) begin
        if (dm_we) begin
            $display("[%0t] CPU Write: addr=0x%h, data=0x%h", $time, dm_addr, dm_wdata);
        end
    end
    
    // 监控VGA写入
    always @(posedge clk) begin
        if (vga_we) begin
            $display("[%0t] VGA Write: addr=%0d, char=0x%h ('%c')", 
                     $time, vga_addr, vga_char, vga_char);
        end
    end
    
    // 监控键盘
    always @(posedge clk) begin
        if (key_ready) begin
            $display("[%0t] Key Ready: code=0x%h", $time, key_code);
        end
    end

endmodule
