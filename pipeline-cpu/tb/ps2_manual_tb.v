`timescale 1ns / 1ps

module ps2_manual_tb();

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
    
    // 系统时钟 100MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // 手动发送PS/2帧
    task send_bit;
        input bit_val;
        begin
            ps2_data = bit_val;
            // 产生一个ps2_clk周期
            #40000;
            ps2_clk = 0;  // 下降沿
            #40000;
            ps2_clk = 1;  // 恢复高
        end
    endtask
    
    task send_ps2_code;
        input [7:0] code;
        reg parity;
        begin
            parity = ~(code[0] ^ code[1] ^ code[2] ^ code[3] ^ 
                       code[4] ^ code[5] ^ code[6] ^ code[7]);
            
            $display("[%0t] Sending code 0x%h, parity=%b", $time, code, parity);
            
            // 等待控制器稳定
            #1000;
            
            // 起始位
            send_bit(0);
            $display("[%0t] Sent start bit", $time);
            
            // 数据位 (LSB先)
            send_bit(code[0]);
            send_bit(code[1]);
            send_bit(code[2]);
            send_bit(code[3]);
            send_bit(code[4]);
            send_bit(code[5]);
            send_bit(code[6]);
            send_bit(code[7]);
            $display("[%0t] Sent data bits", $time);
            
            // 校验位
            send_bit(parity);
            $display("[%0t] Sent parity bit", $time);
            
            // 停止位
            send_bit(1);
            $display("[%0t] Sent stop bit", $time);
            
            // 额外等待
            #40000;
            
            $display("[%0t] Send complete", $time);
        end
    endtask
    
    // 主测试
    initial begin
        $display("=== PS/2 Manual Test ===");
        
        // 初始化
        reset = 1;
        ps2_clk = 1;
        ps2_data = 1;
        key_read_acknowledge = 0;
        
        #1000;
        reset = 0;
        $display("[%0t] Reset released", $time);
        
        #1000;
        
        // 发送 'a' (0x1C)
        send_ps2_code(8'h1C);
        
        // 等待
        #100000;
        
        // 检查结果
        $display("[%0t] Final: key_ready=%b, key_code=0x%h", $time, key_ready, key_code);
        
        if (key_ready && key_code == 8'h1C) begin
            $display("TEST PASSED!");
        end else begin
            $display("TEST FAILED!");
        end
        
        $finish;
    end
    
    // 监控
    always @(posedge clk) begin
        if (U_KBD.ps2_clk_fall) begin
            $display("[%0t] PS2_CLK_FALL, bit_cnt=%0d, ps2_data=%b, shift_reg=%b%b%b%b%b%b%b%b%b%b%b, check=%b", 
                     $time, U_KBD.bit_cnt, ps2_data,
                     U_KBD.shift_reg[10], U_KBD.shift_reg[9], U_KBD.shift_reg[8],
                     U_KBD.shift_reg[7], U_KBD.shift_reg[6], U_KBD.shift_reg[5],
                     U_KBD.shift_reg[4], U_KBD.shift_reg[3], U_KBD.shift_reg[2],
                     U_KBD.shift_reg[1], U_KBD.shift_reg[0],
                     (ps2_data && ^U_KBD.shift_reg[9:1]));
        end
        if (key_ready) begin
            $display("[%0t] KEY_READY=1, KEY_CODE=0x%h", $time, key_code);
        end
    end

endmodule
