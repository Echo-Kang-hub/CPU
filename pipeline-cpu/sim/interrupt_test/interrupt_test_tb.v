`timescale 1ns / 1ps
`include "soc_top.v"

module interrupt_test_tb();
    reg          clk;
    reg          rstn;
    reg          ext_interrupt;
    reg  [4:0]   reg_sel;
    wire [31:0]  reg_data;
    
    integer cycle = 0;
    integer errors = 0;
    
    // DUT
    soc_top U_SOC(
        .clk      (clk), 
        .rstn     (rstn), 
        .reg_sel  (reg_sel), 
        .reg_data (reg_data) 
    );
    
    // 信号别名
    wire [31:0] PC          = U_SOC.U_CPU.instr_addr;
    wire [31:0] instr       = U_SOC.U_CPU.instr;
    wire [31:0] mstatus     = U_SOC.U_CPU.mstatus;
    wire [31:0] mie_csr     = U_SOC.U_CPU.mie;
    wire [31:0] mip         = U_SOC.U_CPU.mip;
    wire [31:0] mepc        = U_SOC.U_CPU.mepc;
    wire [31:0] mcause      = U_SOC.U_CPU.mcause;
    wire        int_taken   = U_SOC.U_CPU.interrupt_taken;
    wire        mret_tk     = U_SOC.U_CPU.mret_taken;
    wire        flush       = U_SOC.U_CPU.Flush_IFID;
    
    // 寄存器别名
    wire [31:0] t1 = U_SOC.U_CPU.u_ID_stage.U_RF.regfile[6];  // x6 = t1
    wire [31:0] t2 = U_SOC.U_CPU.u_ID_stage.U_RF.regfile[7];  // x7 = t2
    
    // 时钟
    initial clk = 0;
    always #50 clk = ~clk;
    
    // 超时机制
    integer timeout_cycles = 10000;
    integer timeout_counter = 0;
    always @(posedge clk) begin
        if (rstn) begin
            timeout_counter <= timeout_counter + 1;
            if (timeout_counter >= timeout_cycles) begin
                $display("========================================");
                $display("ERROR: Test timeout after %0d cycles!", timeout_counter);
                $display("  PC = 0x%h", PC);
                $display("  mepc = 0x%h", mepc);
                $display("  mcause = 0x%h", mcause);
                $display("  mstatus = 0x%h", mstatus);
                $display("  t1 = %0d", t1);
                $display("  t2 = %0d", t2);
                $display("  int_taken = %b", int_taken);
                $display("  mret_tk = %b", mret_tk);
                $display("========================================");
                $finish;
            end
        end
    end
    
    // 复位和测试流程
    initial begin
        $dumpfile("interrupt_test.vcd");
        $dumpvars(0, interrupt_test_tb);
        
        // 初始化
        rstn = 1;
        ext_interrupt = 0;
        reg_sel = 0;
        
        // 复位
        #25 rstn = 0;
        #100 rstn = 1;
        
        // force ext_interrupt 到 CPU 内部
        force U_SOC.U_CPU.ext_interrupt = ext_interrupt;
        
        $display("========================================");
        $display("  Interrupt Test Start");
        $display("========================================");
        $display("[%0t] Waiting for global interrupt enable (mstatus[3]=1)...", $time);
        $display("[%0t] Current mstatus = 0x%h, PC = 0x%h", $time, mstatus, PC);
        
        // 等待程序开启中断 (mstatus[3] = 1)，最多等待100个周期
        begin : wait_mie
            integer wait_cnt = 0;
            $display("[%0t] Entering wait loop...", $time);
            while (mstatus[3] != 1'b1 && wait_cnt < 100) begin
                @(posedge clk);
                wait_cnt = wait_cnt + 1;
                if (wait_cnt % 10 == 0) begin
                    $display("[%0t] Waiting for MIE: cnt=%0d, mstatus=0x%h, PC=0x%h", $time, wait_cnt, mstatus, PC);
                end
            end
            $display("[%0t] Exited wait loop. mstatus[3]=%b, wait_cnt=%0d", $time, mstatus[3], wait_cnt);
            if (mstatus[3] == 1'b1) begin
                $display("[%0t] Global interrupt enabled (MIE=1) after %0d cycles", $time, wait_cnt);
            end else begin
                $display("[%0t] ERROR: MIE not enabled after %0d cycles! mstatus = 0x%h, PC = 0x%h", $time, wait_cnt, mstatus, PC);
                $finish;
            end
        end
        
        // 再等几个周期让几条指令执行
        repeat(3) @(posedge clk);
        
        $display("----------------------------------------");
        $display("[%0t] Triggering external interrupt...", $time);
        
        // 触发外部中断
        @(posedge clk);
        ext_interrupt = 1;
        @(posedge clk);
        ext_interrupt = 0;
        
        // 等待中断响应
        wait(int_taken == 1'b1);
        $display("[%0t] >>> interrupt_taken asserted <<<", $time);
        $display("    mepc (will be) = 0x%h", PC);
        
        // 等待进入中断处理程序
        wait(PC == 32'h0000_0100);
        $display("[%0t] >>> Entered interrupt handler (PC=0x100) <<<", $time);
        
        // 等几个周期
        repeat(3) @(posedge clk);
        
        // 检查 CSR 状态
        $display("----------------------------------------");
        $display("CSR Check after interrupt:");
        $display("  mepc   = 0x%h (expect: 0x2C-0x3C)", mepc);
        $display("  mcause = 0x%h (expect: 0x8000000B)", mcause);
        $display("  mstatus= 0x%h (expect: bit[3]=0, bit[7]=1)", mstatus);
        $display("  t1     = %0d (counter before interrupt)", t1);
        $display("  t2     = %0d (handler counter, expect: 1)", t2);
        
        // 自动检查
        if (mcause !== 32'h8000_000B) begin
            $display("ERROR: mcause wrong!");
            errors = errors + 1;
        end
        if (mstatus[3] !== 1'b0) begin
            $display("ERROR: MIE should be 0 after interrupt!");
            errors = errors + 1;
        end
        if (mstatus[7] !== 1'b1) begin
            $display("ERROR: MPIE should be 1 after interrupt!");
            errors = errors + 1;
        end
        if (t2 !== 32'd1) begin
            $display("ERROR: handler counter should be 1!");
            errors = errors + 1;
        end
        
        $display("----------------------------------------");
        $display("[%0t] Waiting for mret...", $time);
        
        // 等待 mret
        wait(mret_tk == 1'b1);
        $display("[%0t] >>> mret detected <<<", $time);
        
        // 等待返回主程序
        wait(PC != 32'h0000_0100 && PC != 32'h0000_0104);
        repeat(2) @(posedge clk);
        
        $display("----------------------------------------");
        $display("CSR Check after mret:");
        $display("  PC     = 0x%h (should be mepc)", PC);
        $display("  mstatus= 0x%h (expect: bit[3]=1, bit[7]=1)", mstatus);
        $display("  t1     = %0d (should continue)", t1);
        $display("  t2     = %0d", t2);
        
        // 检查 mret 后状态
        if (mstatus[3] !== 1'b1) begin
            $display("ERROR: MIE should be restored to 1 after mret!");
            errors = errors + 1;
        end
        
        // 等几周期看是否继续执行
        repeat(5) @(posedge clk);
        $display("  t1 after 5 cycles = %0d (should increase)", t1);
        
        $display("========================================");
        if (errors == 0)
            $display("  ALL TESTS PASSED!");
        else
            $display("  TEST FAILED with %0d errors", errors);
        $display("========================================");
        
        #200;
        $finish;
    end
    
    // 监控关键事件
    always @(posedge clk) begin
        if (rstn) begin
            cycle = cycle + 1;
            if (int_taken)
                $display("[%0t] CYCLE=%0d: interrupt_taken! PC=0x%h", $time, cycle, PC);
            if (mret_tk)
                $display("[%0t] CYCLE=%0d: mret_taken! PC=0x%h", $time, cycle, PC);
            if (flush && !int_taken && !mret_tk)
                $display("[%0t] CYCLE=%0d: FLUSH (branch/jal) PC=0x%h", $time, cycle, PC);
        end
    end
    
endmodule
