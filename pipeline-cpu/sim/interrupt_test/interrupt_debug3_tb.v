`timescale 1ns / 1ps
`include "soc_top.v"

module interrupt_debug3_tb();
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
    wire [31:0] mip         = U_SOC.U_CPU.mip;
    wire [31:0] mepc        = U_SOC.U_CPU.mepc;
    wire [31:0] mcause      = U_SOC.U_CPU.mcause;
    wire        int_taken   = U_SOC.U_CPU.interrupt_taken;
    wire        mret_tk     = U_SOC.U_CPU.mret_taken;
    wire        flush       = U_SOC.U_CPU.Flush_IFID;
    
    // 时钟
    initial clk = 0;
    always #5 clk = ~clk;
    
    // 监控关键事件
    always @(posedge clk) begin
        if (rstn) begin
            cycle = cycle + 1;
            $display("CYCLE %0d: PC=0x%h int_taken=%b mret=%b mepc=0x%h", cycle, PC, int_taken, mret_tk, mepc);
            if (int_taken)
                $display("  -> INTERRUPT TAKEN");
            if (mret_tk)
                $display("  -> MRET TAKEN");
            if (cycle >= TIMEOUT_CYCLES) begin
                $display("TIMEOUT");
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
            $display("=== Setup done at cycle %0d, mstatus=0x%h mie=0x%h ===", cycle, mstatus, mie_csr);
        end
        
        // 触发中断
        @(posedge clk);
        ext_interrupt = 1;
        @(posedge clk);
        ext_interrupt = 0;
        
        // 等待 mret
        begin : wait_mret
            integer cnt;
            cnt = 0;
            while (mret_tk != 1 && cnt < 50) begin
                @(posedge clk);
                cnt = cnt + 1;
            end
            if (mret_tk == 1)
                $display("=== MRET detected at cycle %0d ===", cycle);
            else
                $display("=== MRET not detected ===");
        end
        
        repeat(5) @(posedge clk);
        
        $display("Final: PC=0x%h mepc=0x%h mcause=0x%h mstatus=0x%h", PC, mepc, mcause, mstatus);
        $finish;
    end
    
endmodule
