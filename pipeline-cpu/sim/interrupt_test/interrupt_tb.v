`timescale 1ns / 1ps
`include "soc_top.v"

module interrupt_full_tb();
    reg          clk;
    reg          rstn;
    reg          ext_interrupt;
    
    integer errors = 0;
    integer cycle = 0;
    
    parameter TIMEOUT_CYCLES = 300;
    
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
    wire [31:0] mepc        = U_SOC.U_CPU.mepc;
    wire        int_taken   = U_SOC.U_CPU.interrupt_taken;
    wire        mret_tk     = U_SOC.U_CPU.mret_taken;
    
    wire [31:0] t2 = U_SOC.U_CPU.u_ID_stage.U_RF.regfile[7];
    
    // 时钟
    initial clk = 0;
    always #5 clk = ~clk;
    
    // 超时
    always @(posedge clk) begin
        if (rstn) begin
            cycle = cycle + 1;
            if (cycle >= TIMEOUT_CYCLES) begin
                $display("TIMEOUT at cycle %0d", cycle);
                $display("  PC=0x%h mstatus=0x%h mie=0x%h", PC, mstatus, mie_csr);
                $finish;
            end
        end
    end
    
    initial begin
        $dumpfile("interrupt_full.vcd");
        $dumpvars(0, interrupt_full_tb);
        
        rstn = 1;
        ext_interrupt = 0;
        
        #10 rstn = 0;
        #20 rstn = 1;
        
        force U_SOC.U_CPU.ext_interrupt = ext_interrupt;
        
        $display("=== Full Interrupt Test (no force on CSR) ===");
        
        // 等待程序设置中断使能 (mstatus[3]=1)
        begin : wait_enable
            integer cnt;
            cnt = 0;
            while (mstatus[3] != 1 && cnt < 100) begin
                @(posedge clk);
                cnt = cnt + 1;
            end
            if (mstatus[3] != 1) begin
                $display("FAIL: Interrupt not enabled, mstatus=0x%h", mstatus);
                $finish;
            end
            $display("OK: Interrupt enabled at cycle %0d, mstatus=0x%h mie=0x%h", cycle, mstatus, mie_csr);
        end
        
        // 等几个周期
        repeat(5) @(posedge clk);
        
        // 触发外部中断
        @(posedge clk);
        ext_interrupt = 1;
        @(posedge clk);
        ext_interrupt = 0;
        
        // 等待中断响应
        begin : wait_int
            integer cnt;
            cnt = 0;
            while (int_taken != 1 && cnt < 50) begin
                @(posedge clk);
                cnt = cnt + 1;
            end
            if (int_taken != 1) begin
                $display("FAIL: Interrupt not taken");
                errors = errors + 1;
            end else begin
                $display("OK: Interrupt taken at cycle %0d", cycle);
            end
        end
        
        // 等待进入处理程序
        begin : wait_handler
            integer cnt;
            cnt = 0;
            while (PC != 32'h100 && cnt < 30) begin
                @(posedge clk);
                cnt = cnt + 1;
            end
            if (PC != 32'h100) begin
                $display("FAIL: Not in handler, PC=0x%h", PC);
                errors = errors + 1;
            end else begin
                $display("OK: In handler at PC=0x100");
            end
        end
        
        // 检查中断后的 CSR 状态 - 立即检查，不要等太多周期
        @(posedge clk);
        $display("CSR after interrupt: mcause=0x%h mstatus=0x%h", mcause, mstatus);
        
        if (mcause !== 32'h8000_000B) begin
            $display("FAIL: mcause wrong, expected 0x8000000B");
            errors = errors + 1;
        end
        
        if (mstatus[3] !== 1'b0) begin
            $display("FAIL: MIE should be 0 after interrupt");
            errors = errors + 1;
        end
        
        // 等待 mret
        begin : wait_mret
            integer cnt;
            cnt = 0;
            while (mret_tk != 1 && cnt < 100) begin
                @(posedge clk);
                cnt = cnt + 1;
            end
            if (mret_tk != 1) begin
                $display("FAIL: mret not detected");
                errors = errors + 1;
            end else begin
                $display("OK: mret detected at cycle %0d", cycle);
            end
        end
        
        // 等待返回主程序
        repeat(10) @(posedge clk);
        
        // 检查 mret 后的状态
        if (mstatus[3] !== 1'b1) begin
            $display("FAIL: MIE not restored after mret, mstatus=0x%h", mstatus);
            errors = errors + 1;
        end else begin
            $display("OK: MIE restored after mret");
        end
        
        if (errors == 0)
            $display("PASS: Full interrupt test OK");
        else
            $display("FAIL: %0d errors", errors);
        
        #20;
        $finish;
    end
    
endmodule
