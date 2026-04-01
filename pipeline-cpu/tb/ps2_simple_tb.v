`timescale 1ns / 1ps

module ps2_simple_tb();

    reg clk;
    reg reset;
    reg ps2_clk;
    reg ps2_data;
    reg key_read_acknowledge;
    wire [7:0] key_code;
    wire key_ready;
    
    // 实例化PS/2键盘控制器
    ps2_keyboard U_KBD (
        .clk                  (clk),
        .reset                (reset),
        .ps2_clk              (ps2_clk),
        .ps2_data             (ps2_data),
        .key_read_acknowledge (key_read_acknowledge),
        .key_code             (key_code),
        .key_ready            (key_ready)
    );
    
    // 系统时钟 100MHz (10ns周期)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // 发送PS/2扫描码任务 - 使用时钟生成方式
    reg [10:0] ps2_frame;
    integer bit_index;
    
    task send_ps2_code;
        input [7:0] code;
        begin
            $display("[%0t] Sending code 0x%h", $time, code);
            
            // 构建PS/2帧: [停止位, 校验位, D7..D0, 起始位]
            ps2_frame[0] = 0;  // 起始位
            ps2_frame[8:1] = code;  // 数据位
            ps2_frame[9] = ~(code[0] ^ code[1] ^ code[2] ^ code[3] ^ 
                             code[4] ^ code[5] ^ code[6] ^ code[7]);  // 校验位
            ps2_frame[10] = 1;  // 停止位
            
            $display("[%0t] Frame = 0x%h", $time, ps2_frame);
            
            // 等待posedge开始发送
            @(posedge ps2_clk);
            
            // 逐位发送
            for (bit_index = 0; bit_index <= 10; bit_index = bit_index + 1) begin
                ps2_data = ps2_frame[bit_index];
                $display("[%0t] Sending bit %0d = %b", $time, bit_index, ps2_frame[bit_index]);
                @(posedge ps2_clk);
            end
            
            ps2_data = 1;
            
            $display("[%0t] Send complete", $time);
        end
    endtask
    
    // PS/2时钟生成 - 初始为0，确保posedge在0时刻触发
    initial begin
        ps2_clk = 0;
        forever begin
            #40000 ps2_clk = 1;  // 40us高
            #40000 ps2_clk = 0;  // 40us低
        end
    end
    
    // 主测试
    initial begin
        $display("=== PS/2 Keyboard Simple Test ===");
        
        // 初始化
        reset = 1;
        ps2_data = 1;
        key_read_acknowledge = 0;
        
        // 在0时刻就开始发送，不等待posedge
        fork
            begin
                // 等待一小段时间后释放复位
                #100;
                reset = 0;
                $display("[%0t] Reset released", $time);
            end
            begin
                // 直接开始发送，不等待posedge
                #1;
                $display("[%0t] Sending 'a' (0x1C)", $time);
                send_ps2_code(8'h1C);
            end
        join
        
        // 等待接收完成
        #500000;
        
        // 检查结果
        $display("[%0t] Final: key_ready=%b, key_code=0x%h", $time, key_ready, key_code);
        
        if (key_ready && key_code == 8'h1C) begin
            $display("TEST PASSED!");
        end else begin
            $display("TEST FAILED!");
        end
        
        $finish;
    end
    
    // 监控关键信号
    always @(posedge clk) begin
        if (U_KBD.ps2_clk_fall) begin
            $display("[%0t] PS2_CLK_FALL, bit_cnt=%0d -> %0d, ps2_data=%b, shift_reg=0x%h", 
                     $time, U_KBD.bit_cnt, U_KBD.bit_cnt + 1, ps2_data, U_KBD.shift_reg);
        end
        if (key_ready) begin
            $display("[%0t] KEY_READY=1, KEY_CODE=0x%h", $time, key_code);
        end
        // 监控bit_cnt变化
        if (U_KBD.bit_cnt != U_KBD.bit_cnt) begin
            $display("[%0t] bit_cnt changed to %0d", $time, U_KBD.bit_cnt);
        end
    end
    
    // 额外监控
    reg [3:0] prev_bit_cnt;
    always @(posedge clk) begin
        if (U_KBD.bit_cnt != prev_bit_cnt) begin
            $display("[%0t] bit_cnt: %0d -> %0d, ps2_data=%b, ps2_clk=%b", 
                     $time, prev_bit_cnt, U_KBD.bit_cnt, ps2_data, ps2_clk);
            prev_bit_cnt <= U_KBD.bit_cnt;
        end
    end

endmodule
