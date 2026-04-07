`timescale 1ns / 1ps
`define DMEM_INIT

module system_full_tb();

    reg clk;
    reg rstn;
    reg [15:0] sw_i;
    reg ps2_clk;
    reg ps2_data;
    
    wire [7:0] disp_seg_o, disp_an_o;
    wire [3:0] vga_r, vga_g, vga_b;
    wire vga_hsync, vga_vsync;
    
    // 实例化系统顶层
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
    
    // 100MHz时钟
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // PS/2发送任务
    task send_bit;
        input b;
        begin
            ps2_data = b;
            #40000;
            ps2_clk = 0;
            #40000;
            ps2_clk = 1;
        end
    endtask
    
    task send_ps2_code;
        input [7:0] code;
        reg p;
        begin
            p = ~(code[0]^code[1]^code[2]^code[3]^code[4]^code[5]^code[6]^code[7]);
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
            send_bit(p);
            send_bit(1);
            #40000;
        end
    endtask
    
    // 主测试
    initial begin
        $display("========================================");
        $display("System Full Test");
        $display("========================================");
        
        // 初始化
        $display("[%0t] Starting reset...", $time);
        rstn = 0;
        sw_i = 16'h0000;
        ps2_clk = 1;
        ps2_data = 1;
        
        $display("[%0t] Waiting 1000...", $time);
        #1000;
        $display("[%0t] Releasing reset...", $time);
        rstn = 1;
        $display("[%0t] Reset released, rstn=%b", $time, rstn);
        #10000;
        
        $display("\n[%0t] Checking initial state...", $time);
        $display("  PC = 0x%h", uut.PC);
        $display("  Instr = 0x%h", uut.instr);
        
        // 等待CPU初始化转换表
        #100000;
        $display("\n[%0t] After init, PC = 0x%h", $time, uut.PC);
        
        // 发送键盘按键 'h' (0x33)
        $display("\n[%0t] Sending 'h' (scan code 0x33)", $time);
        send_ps2_code(8'h33);
        #200000;
        
        $display("  key_ready = %b", uut.key_ready);
        $display("  key_code = 0x%h", uut.key_code);
        $display("  PC = 0x%h", uut.PC);
        
        // 发送 'e' (0x24)
        $display("\n[%0t] Sending 'e' (scan code 0x24)", $time);
        send_ps2_code(8'h24);
        #200000;
        
        // 发送 'l' (0x4B)
        $display("\n[%0t] Sending 'l' (scan code 0x4B)", $time);
        send_ps2_code(8'h4B);
        #200000;
        
        // 发送 'l' (0x4B)
        $display("\n[%0t] Sending 'l' (scan code 0x4B)", $time);
        send_ps2_code(8'h4B);
        #200000;
        
        // 发送 'o' (0x44)
        $display("\n[%0t] Sending 'o' (scan code 0x44)", $time);
        send_ps2_code(8'h44);
        #200000;
        
        // 检查VGA显示
        $display("\n========================================");
        $display("VGA Display Check:");
        $display("========================================");
        check_vga_display();
        
        $display("\n========================================");
        $display("Test Complete!");
        $display("========================================");
        
        $finish;
    end
    
    // 检查VGA显示内容
    task check_vga_display;
        integer i;
        begin
            $write("  VGA[0:15]: ");
            for (i = 0; i < 16; i = i + 1) begin
                if (uut.U_VGA.chr_mem[i] >= 8'h20 && uut.U_VGA.chr_mem[i] <= 8'h7E)
                    $write("%c", uut.U_VGA.chr_mem[i]);
                else
                    $write(".");
            end
            $display("");
        end
    endtask
    
    // 监控CPU读取
    always @(posedge clk) begin
        $display("[%0t] rstn=%b, rst=%b, PC=0x%h", $time, rstn, uut.rst, uut.PC);
    end

endmodule
