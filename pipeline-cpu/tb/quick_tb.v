`timescale 1ns / 1ps

module keyboard_vga_quick_tb();

    reg clk, rstn;
    reg ps2_clk, ps2_data;
    wire [7:0] disp_seg_o, disp_an_o;
    wire [3:0] vga_r, vga_g, vga_b;
    wire vga_hsync, vga_vsync;
    
    // 实例化系统
    xgriscv_fpga_top uut (
        .clk(clk), .rstn(rstn), .sw_i(16'h0000),
        .disp_seg_o(disp_seg_o), .disp_an_o(disp_an_o),
        .ps2_clk(ps2_clk), .ps2_data(ps2_data),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b),
        .vga_hsync(vga_hsync), .vga_vsync(vga_vsync)
    );
    
    // 100MHz时钟
    initial begin clk=0; forever #5 clk=~clk; end
    
    // PS/2发送
    task send_code;
        input [7:0] code;
        integer i;
        reg parity;
        begin
            parity = ~(^code);
            // 起始位
            ps2_data=0; #40000; ps2_clk=0; #40000; ps2_clk=1;
            // 数据位
            for(i=0;i<8;i=i+1) begin
                ps2_data=code[i]; #40000; ps2_clk=0; #40000; ps2_clk=1;
            end
            // 校验位
            ps2_data=parity; #40000; ps2_clk=0; #40000; ps2_clk=1;
            // 停止位
            ps2_data=1; #40000; ps2_clk=0; #40000; ps2_clk=1;
            #40000;
        end
    endtask
    
    // 主测试
    initial begin
        $display("=== Quick Test ===");
        
        // 初始化
        rstn = 0;
        ps2_clk = 1;
        ps2_data = 1;
        
        // 复位
        repeat(10) @(posedge clk);
        rstn = 1;
        repeat(10) @(posedge clk);
        
        $display("[%0t] Reset released, PC=0x%h", $time, uut.PC);
        
        // 等待CPU执行
        repeat(100) @(posedge clk);
        $display("[%0t] PC=0x%h, Instr=0x%h", $time, uut.PC, uut.instr);
        
        // 发送按键
        $display("\n--- Sending 'h' ---");
        send_code(8'h33);
        repeat(1000) @(posedge clk);
        
        $display("--- Sending 'e' ---");
        send_code(8'h24);
        repeat(1000) @(posedge clk);
        
        $display("--- Sending 'l' ---");
        send_code(8'h4B);
        repeat(1000) @(posedge clk);
        
        // 检查VGA
        $display("\n=== VGA Check ===");
        $display("VGA[0]=0x%h ('%c')", uut.U_VGA.chr_mem[0], uut.U_VGA.chr_mem[0]);
        $display("VGA[1]=0x%h ('%c')", uut.U_VGA.chr_mem[1], uut.U_VGA.chr_mem[1]);
        $display("VGA[2]=0x%h ('%c')", uut.U_VGA.chr_mem[2], uut.U_VGA.chr_mem[2]);
        
        $finish;
    end
    
    // 监控CPU执行
    reg [31:0] prev_pc;
    always @(posedge clk) begin
        if (uut.PC != prev_pc) begin
            $display("[%0t] PC=0x%h", $time, uut.PC);
            prev_pc <= uut.PC;
        end
    end

endmodule
