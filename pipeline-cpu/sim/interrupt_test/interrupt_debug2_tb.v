`timescale 1ns / 1ps
`include "soc_top.v"

module interrupt_debug_tb();
    reg          clk;
    reg          rstn;
    reg          ext_interrupt;
    
    integer errors = 0;
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
    wire [31:0] mcause      = U_SOC.U_CPU.mcause;
    wire        int_taken   = U_SOC.U_CPU.interrupt_taken;
    wire        flush       = U_SOC.U_CPU.Flush_IFID;
    wire [31:0] NPC         = U_SOC.U_CPU.u_IF_stage.NPC_addr;
    wire        ID_allowin  = U_SOC.U_CPU.ID_allowin;
    
    // 时钟
    initial clk = 0;
    always #5 clk = ~clk;
    
    // 每个周期打印状态
    always @(posedge clk) begin
        if (rstn) begin
            cycle = cycle + 1;
            $display("CYCLE %0d: PC=0x%h NPC=0x%h mie=%b mip=%b mstatus=%b int_taken=%b flush=%b ID_allowin=%b", 
                     cycle, PC, NPC, mie_csr[11], mip[11], mstatus[3], int_taken, flush, ID_allowin);
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
            $display("=== mstatus[3]=1 at cycle %0d ===", cycle);
        end
        
        // 触发中断
        @(posedge clk);
        ext_interrupt = 1;
        @(posedge clk);
        ext_interrupt = 0;
        
        // 等待几个周期观察
        repeat(10) @(posedge clk);
        
        $finish;
    end
    
endmodule
