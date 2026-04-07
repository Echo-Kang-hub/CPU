`timescale 1ns / 1ps

module cpu_simple_tb();

    reg clk, rstn;
    
    // 实例化系统
    xgriscv_fpga_top uut (
        .clk(clk), .rstn(rstn), .sw_i(16'h0000),
        .disp_seg_o(), .disp_an_o(),
        .ps2_clk(1'b1), .ps2_data(1'b1),
        .vga_r(), .vga_g(), .vga_b(),
        .vga_hsync(), .vga_vsync()
    );
    
    // 100MHz时钟
    initial begin clk=0; forever #5 clk=~clk; end
    
    // 测试
    initial begin
        $display("=== CPU Simple Test ===");
        
        // 复位
        rstn = 0;
        repeat(10) @(posedge clk);
        rstn = 1;
        
        // 运行10000个周期
        repeat(10000) @(posedge clk);
        
        $display("=== Done ===");
        $finish;
    end
    
    // 只在PC变化时打印
    reg [31:0] last_pc = 32'hFFFFFFFF;
    always @(posedge clk) begin
        if (uut.PC != last_pc && uut.PC != 0) begin
            $display("[%0t] PC=0x%h", $time, uut.PC);
            last_pc <= uut.PC;
        end
    end

endmodule
