`timescale 1ns / 1ps
`include "soc_top.v"

module interrupt_check_tb();
    reg          clk;
    reg          rstn;
    reg          ext_interrupt;
    
    integer cycle = 0;
    
    parameter TIMEOUT_CYCLES = 100;
    
    // DUT
    soc_top U_SOC(
        .clk      (clk), 
        .rstn     (rstn), 
        .reg_sel  (5'b0), 
        .reg_data () 
    );
    
    // 关键信号
    wire [31:0] PC          = U_SOC.U_CPU.instr_addr;
    wire [31:0] mstatus     = U_SOC.U_CPU.mstatus;
    wire [31:0] mie_csr     = U_SOC.U_CPU.mie;
    wire        int_taken   = U_SOC.U_CPU.interrupt_taken;
    
    // 时钟
    initial clk = 0;
    always #5 clk = ~clk;
    
    // 监控 mstatus 变化
    always @(posedge clk) begin
        if (rstn) begin
            cycle = cycle + 1;
            $display("CYCLE %0d: mstatus=0x%h int_taken=%b", cycle, mstatus, int_taken);
            if (cycle >= TIMEOUT_CYCLES) begin
                $finish;
            end
        end
    end
    
    initial begin
        rstn = 1;
        ext_interrupt = 0;
        
        #10 rstn = 0;
        #20 rstn = 1;
        
        force U_SOC.U_CPU.ext_interrupt = ext_interrupt;
        
        // 等待 mstatus[3]=1
        begin : wait_mie
            integer cnt;
            cnt = 0;
            while (mstatus[3] != 1 && cnt < 50) begin
                @(posedge clk);
                cnt = cnt + 1;
            end
            $display("=== mstatus[3]=1 at cycle %0d ===", cycle);
        end
        
        // 触发中断
        @(posedge clk);
        ext_interrupt = 1;
        @(posedge clk);
        ext_interrupt = 0;
        
        // 等待中断响应
        begin : wait_int
            integer cnt;
            cnt = 0;
            while (int_taken != 1 && cnt < 30) begin
                @(posedge clk);
                cnt = cnt + 1;
            end
        end
        
        // 等待几个周期观察 mstatus
        repeat(10) @(posedge clk);
        
        $finish;
    end
    
endmodule
