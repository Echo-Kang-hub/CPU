`timescale 1ns / 1ps

module vga_standalone_tb();

    reg clk;
    reg reset;
    
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
    
    initial begin
        $display("VGA Test");
        
        reset = 1;
        vga_we = 0;
        vga_addr = 0;
        vga_char = 0;
        
        #1000;
        reset = 0;
        #1000;
        
        // 测试写入
        $display("Writing 0x41 to VGA[0]...");
        vga_we = 1;
        vga_addr = 0;
        vga_char = 8'h41;  // 'A'
        #10;
        vga_we = 0;
        
        // 等待
        #10000;
        
        $display("VGA[0] = 0x%h", U_VGA.chr_mem[0]);
        $display("VGA[1] = 0x%h", U_VGA.chr_mem[1]);
        
        $display("Test done");
        $finish;
    end

endmodule
