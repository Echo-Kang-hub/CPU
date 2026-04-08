`timescale 1ns / 1ps
`define DMEM_INIT

module system_full_tb();

    reg clk;
    reg rstn;
    reg [15:0] sw_i;
    reg ps2_clk;
    reg ps2_data;
    integer cycle_count;
    integer stable_pc_count;
    reg [31:0] last_pc;
    integer vga_write_count;
    integer key_event_count;
    localparam integer MAX_CYCLES = 900000;
    localparam integer MAX_STABLE_PC = 200000;
    
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

    // 全局超时保护，防止测试平台无限运行
    initial begin
        #(20_000_000); // 20ms
        $display("\n[TB-TIMEOUT] Simulation exceeded 20ms, force stop.");
        $finish;
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
        cycle_count = 0;
        stable_pc_count = 0;
        last_pc = 32'hFFFF_FFFF;
        vga_write_count = 0;
        key_event_count = 0;
        
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
        $display("  IMEM signature: %h %h %h %h", uut.U_IM.ROM[0], uut.U_IM.ROM[1], uut.U_IM.ROM[2], uut.U_IM.ROM[3]);
        
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

        if (key_event_count == 0) begin
            $display("[TB-FAIL] No keyboard event observed by top-level.");
        end
        if (vga_write_count == 0) begin
            $display("[TB-FAIL] No VGA write observed on U_VGA.cpu_we.");
        end
        
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
        cycle_count = cycle_count + 1;

        if (uut.PC == last_pc) begin
            stable_pc_count = stable_pc_count + 1;
        end else begin
            stable_pc_count = 0;
            last_pc = uut.PC;
        end

        if ((cycle_count % 20000) == 0) begin
            $display("[%0t] cycle=%0d, PC=0x%h, rstn=%b", $time, cycle_count, uut.PC, rstn);
        end

        if (cycle_count >= MAX_CYCLES) begin
            $display("\n[TB-WATCHDOG] Reached MAX_CYCLES=%0d, force stop.", MAX_CYCLES);
            $finish;
        end

        if (stable_pc_count >= MAX_STABLE_PC) begin
            $display("\n[TB-WATCHDOG] PC stayed at 0x%h for %0d cycles, force stop.", uut.PC, stable_pc_count);
            $finish;
        end

    end

    always @(posedge clk) begin
        if (uut.key_ready) begin
            key_event_count = key_event_count + 1;
        end
    end

    always @(posedge uut.clk_vga) begin
        if (uut.U_VGA.cpu_we) begin
            vga_write_count = vga_write_count + 1;
            if (vga_write_count <= 8) begin
                $display("[%0t] VGA write #%0d addr=%0d char=0x%h", $time, vga_write_count, uut.U_VGA.cpu_addr, uut.U_VGA.cpu_char);
            end
        end
    end

endmodule
