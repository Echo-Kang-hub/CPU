`timescale 1ns / 1ps
`include "soc_top.v"

module csr_write_debug_tb();
    reg clk, rstn;
    integer cycle = 0;
    
    soc_top U_SOC(.clk(clk), .rstn(rstn), .reg_sel(0), .reg_data());
    
    // CSR signals
    wire        csr_we    = U_SOC.U_CPU.MA_csr_we;
    wire [11:0] csr_addr  = U_SOC.U_CPU.MA_csr_addr;
    wire [31:0] csr_wdata = U_SOC.U_CPU.MA_csr_write_data;
    wire        mret_tk   = U_SOC.U_CPU.mret_taken;
    wire        int_tk    = U_SOC.U_CPU.interrupt_taken;
    wire [31:0] mstatus   = U_SOC.U_CPU.mstatus;
    wire [31:0] mie_csr   = U_SOC.U_CPU.mie;
    wire [31:0] mepc      = U_SOC.U_CPU.mepc;
    wire [31:0] PC        = U_SOC.U_CPU.instr_addr;
    
    // csr_regs 内部信号 (需要直接访问)
    wire [31:0] mstatus_reg = U_SOC.U_CPU.U_CSR.mstatus_reg;
    wire [31:0] mie_reg     = U_SOC.U_CPU.U_CSR.mie_reg;
    
    initial begin clk = 0; rstn = 1; #25 rstn = 0; #100 rstn = 1; end
    always #50 clk = ~clk;
    
    initial begin
        repeat(25) @(posedge clk);
        $finish;
    end
    
    always @(posedge clk) begin
        if (rstn) begin
            cycle = cycle + 1;
            $display("CYCLE=%0d: PC=0x%h", cycle, PC);
            $display("  csr: we=%b addr=0x%h wdata=0x%h", csr_we, csr_addr, csr_wdata);
            $display("  flags: mret=%b int=%b", mret_tk, int_tk);
            $display("  mstatus_reg=0x%h mie_reg=0x%h", mstatus_reg, mie_reg);
            $display("  mstatus=0x%h mie=0x%h mepc=0x%h", mstatus, mie_csr, mepc);
            if (csr_we && csr_addr == 12'h300)
                $display("  >>> WRITING MSTATUS! <<<");
            if (csr_we && csr_addr == 12'h304)
                $display("  >>> WRITING MIE! <<<");
            $display("");
        end
    end
endmodule
