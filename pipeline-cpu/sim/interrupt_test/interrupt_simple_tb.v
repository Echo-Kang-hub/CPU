`timescale 1ns / 1ps
`include "soc_top.v"

module interrupt_simple_tb();
    reg          clk;
    reg          rstn;
    reg          ext_interrupt;
    
    integer errors = 0;
    integer cycle = 0;
    
    // 超时设置 - 500个周期，防止无限运行
    parameter TIMEOUT_CYCLES = 500;
    
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
    wire [31:0] mcause      = U_SOC.U_CPU.mcause;
    wire [31:0] mepc        = U_SOC.U_CPU.mepc;
    wire        int_taken   = U_SOC.U_CPU.interrupt_taken;
    wire        mret_tk     = U_SOC.U_CPU.mret_taken;
    
    // t2 寄存器 - 中断处理计数器
    wire [31:0] t2 = U_SOC.U_CPU.u_ID_stage.U_RF.regfile[7];
    
    // 时钟 10ns 周期
    initial clk = 0;
    always #5 clk = ~clk;
    
    // 超时监控
    always @(posedge clk) begin
        if (rstn) begin
            cycle = cycle + 1;
            if (cycle >= TIMEOUT_CYCLES) begin
                $display("TIMEOUT: Test exceeded %0d cycles", TIMEOUT_CYCLES);
                $display("  PC=0x%h, mstatus=0x%h, mcause=0x%h", PC, mstatus, mcause);
                $finish;
            end
        end
    end
    
    // 测试流程
    initial begin
        $dumpfile("interrupt_simple.vcd");
        $dumpvars(0, interrupt_simple_tb);
        
        // 初始化
        rstn = 1;
        ext_interrupt = 0;
        
        // 复位
        #10 rstn = 0;
        #20 rstn = 1;
        
        // force 中断信号
        force U_SOC.U_CPU.ext_interrupt = ext_interrupt;
        
        $display("Test Start");
        
        // 等待中断使能 (mstatus[3]=1)
        begin : wait_enable
            integer cnt;
            cnt = 0;
            while (mstatus[3] != 1 && cnt < 100) begin
                @(posedge clk);
                cnt = cnt + 1;
            end
            if (mstatus[3] != 1) begin
                $display("FAIL: Interrupt not enabled");
                $finish;
            end
        end
        
        // 等几个周期
        repeat(5) @(posedge clk);
        
        // 触发中断
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
                $finish;
            end
        end
        
        // 等待进入处理程序 (PC=0x100)
        begin : wait_handler
            integer cnt;
            cnt = 0;
            while (PC != 32'h100 && cnt < 50) begin
                @(posedge clk);
                cnt = cnt + 1;
            end
            if (PC != 32'h100) begin
                $display("FAIL: Not in handler, PC=0x%h", PC);
                $finish;
            end
        end
        
        // 等待处理程序执行
        repeat(10) @(posedge clk);
        
        // 检查关键状态
        if (mcause !== 32'h8000_000B) begin
            $display("FAIL: mcause=0x%h, expected 0x8000000B", mcause);
            errors = errors + 1;
        end
        
        if (mstatus[3] !== 1'b0) begin
            $display("FAIL: MIE should be 0");
            errors = errors + 1;
        end
        
        if (t2 < 1) begin
            $display("FAIL: Handler counter t2=%0d, expected >=1", t2);
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
                $finish;
            end
        end
        
        // 等待返回主程序
        repeat(10) @(posedge clk);
        
        // 检查 mret 后状态
        if (mstatus[3] !== 1'b1) begin
            $display("FAIL: MIE not restored after mret");
            errors = errors + 1;
        end
        
        // 最终结果
        if (errors == 0)
            $display("PASS: Interrupt test completed successfully");
        else
            $display("FAIL: %0d errors detected", errors);
        
        #20;
        $finish;
    end
    
endmodule