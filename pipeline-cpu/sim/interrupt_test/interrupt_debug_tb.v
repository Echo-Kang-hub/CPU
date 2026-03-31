`timescale 1ns / 1ps
`include "soc_top.v"

module interrupt_debug_tb();
    reg          clk;
    reg          rstn;
    reg          ext_interrupt;
    reg  [4:0]   reg_sel;
    wire [31:0]  reg_data;
    
    integer cycle = 0;
    
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
    wire [31:0] NPC         = U_SOC.U_CPU.u_IF_stage.NPC_addr;
    wire [31:0] csr_rdata   = U_SOC.U_CPU.csr_read_data;
    wire [11:0] csr_addr    = U_SOC.U_CPU.csr_addr;
    wire        id_valid    = U_SOC.U_CPU.u_ID_stage.ID_valid;
    wire        mie_bit     = U_SOC.U_CPU.global_interrupt_enable;
    
    // 时钟
    initial clk = 0;
    always #50 clk = ~clk;
    
    // 复位和测试流程
    initial begin
        $dumpfile("interrupt_debug.vcd");
        $dumpvars(0, interrupt_debug_tb);
        
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
        $display("  Interrupt Debug Test Start");
        $display("========================================");
        
        // 运行 50 个周期观察行为
        repeat(50) @(posedge clk);
        
        $display("========================================");
        $display("  Test Complete");
        $display("========================================");
        
        #200;
        $finish;
    end
    
    // 每周期打印详细信息
    always @(posedge clk) begin
        if (rstn) begin
            cycle = cycle + 1;
            $display("------------------------------------------------------");
            $display("CYCLE=%0d: PC=0x%h instr=0x%h", cycle, PC, instr);
            $display("  NPC=0x%h id_valid=%b flush=%b", NPC, id_valid, flush);
            $display("  mret_tk=%b int_taken=%b mie=%b", mret_tk, int_taken, mie_bit);
            $display("  mepc=0x%h mcause=0x%h mstatus=0x%h", mepc, mcause, mstatus);
            $display("  csr_addr=0x%h csr_rdata=0x%h", csr_addr, csr_rdata);
            $display("  mie_csr=0x%h mip=0x%h", mie_csr, mip);
            
            if (int_taken)
                $display("  >>> INTERRUPT TAKEN! <<<");
            if (mret_tk)
                $display("  >>> MRET TAKEN! <<<");
            if (flush)
                $display("  >>> FLUSH! <<<");
        end
    end
    
endmodule
