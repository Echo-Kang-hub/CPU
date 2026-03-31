`timescale 1ns / 1ps
`include "soc_top.v"

module csr_debug_tb();
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
    
    // CSR 相关信号
    wire        csr_we      = U_SOC.U_CPU.MA_csr_we;
    wire [11:0] csr_addr    = U_SOC.U_CPU.csr_addr;
    wire [31:0] csr_wdata   = U_SOC.U_CPU.MA_csr_write_data;
    wire [31:0] mstatus     = U_SOC.U_CPU.mstatus;
    wire [31:0] mie_csr     = U_SOC.U_CPU.mie;
    wire [31:0] mepc        = U_SOC.U_CPU.mepc;
    wire [31:0] mcause      = U_SOC.U_CPU.mcause;
    wire [31:0] PC          = U_SOC.U_CPU.instr_addr;
    wire [31:0] instr       = U_SOC.U_CPU.instr;
    wire        int_taken   = U_SOC.U_CPU.interrupt_taken;
    wire        mret_tk     = U_SOC.U_CPU.mret_taken;
    
    // 流水线 valid 信号
    wire        ex_valid    = U_SOC.U_CPU.u_EX_stage.EX_valid;
    wire        ma_valid    = U_SOC.U_CPU.u_MA_stage.MA_valid;
    wire        wb_valid    = U_SOC.U_CPU.u_WB_stage.WB_valid;
    wire        id_valid    = U_SOC.U_CPU.u_ID_stage.ID_valid;
    
    // ID 阶段 CSR 信号
    wire        id_is_csr   = U_SOC.U_CPU.u_ID_stage.is_csr;
    wire        id_csr_we   = U_SOC.U_CPU.u_ID_stage.csr_we;
    wire [11:0] id_csr_addr = U_SOC.U_CPU.u_ID_stage.csr_addr;
    wire [2:0]  id_funct3   = U_SOC.U_CPU.u_ID_stage.funct3;
    wire [6:0]  id_opcode   = U_SOC.U_CPU.u_ID_stage.opcode;
    
    // EX 阶段 CSR 信号
    wire        ex_csr_we   = U_SOC.U_CPU.u_EX_stage.EX_csr_we;
    wire [11:0] ex_csr_addr = U_SOC.U_CPU.u_EX_stage.EX_csr_addr;
    wire [31:0] ex_csr_wdata = U_SOC.U_CPU.u_EX_stage.EX_csr_write_data;
    
    // MA 阶段 CSR 信号
    wire        ma_csr_we   = U_SOC.U_CPU.u_MA_stage.MA_csr_we;
    wire [11:0] ma_csr_addr = U_SOC.U_CPU.u_MA_stage.MA_csr_addr;
    wire [31:0] ma_csr_wdata = U_SOC.U_CPU.u_MA_stage.MA_csr_write_data;
    
    // 寄存器值
    wire [31:0] t0 = U_SOC.U_CPU.u_ID_stage.U_RF.regfile[5];  // x5 = t0
    wire [31:0] t1 = U_SOC.U_CPU.u_ID_stage.U_RF.regfile[6];  // x6 = t1
    wire [31:0] t2 = U_SOC.U_CPU.u_ID_stage.U_RF.regfile[7];  // x7 = t2
    
    // 时钟
    initial clk = 0;
    always #50 clk = ~clk;
    
    initial begin
        rstn = 1;
        ext_interrupt = 0;
        reg_sel = 0;
        
        #25 rstn = 0;
        #100 rstn = 1;
        
        force U_SOC.U_CPU.ext_interrupt = ext_interrupt;
        
        $display("========================================");
        $display("  CSR Debug Test");
        $display("========================================");
        
        // 运行 40 个周期
        repeat(40) @(posedge clk);
        
        $display("========================================");
        $display("  Test Complete");
        $display("========================================");
        
        #100;
        $finish;
    end
    
    always @(posedge clk) begin
        if (rstn) begin
            cycle = cycle + 1;
            $display("------------------------------------------------------");
            $display("CYCLE=%0d: PC=0x%h instr=0x%h", cycle, PC, instr);
            $display("  Pipeline: ID=%b EX=%b MA=%b WB=%b", id_valid, ex_valid, ma_valid, wb_valid);
            $display("  ID: opcode=0x%h funct3=0x%h is_csr=%b csr_we=%b csr_addr=0x%h", 
                     id_opcode, id_funct3, id_is_csr, id_csr_we, id_csr_addr);
            $display("  EX: csr_we=%b csr_addr=0x%h csr_wdata=0x%h", ex_csr_we, ex_csr_addr, ex_csr_wdata);
            $display("  MA: csr_we=%b csr_addr=0x%h csr_wdata=0x%h", ma_csr_we, ma_csr_addr, ma_csr_wdata);
            $display("  CSR: we=%b addr=0x%h wdata=0x%h", csr_we, csr_addr, csr_wdata);
            $display("  mstatus=0x%h mie=0x%h mepc=0x%h mcause=0x%h", mstatus, mie_csr, mepc, mcause);
            $display("  t0=0x%h t1=0x%h t2=0x%h", t0, t1, t2);
            $display("  int_taken=%b mret_tk=%b", int_taken, mret_tk);
            
            if (csr_we)
                $display("  >>> CSR WRITE: addr=0x%h data=0x%h <<<", csr_addr, csr_wdata);
            if (int_taken)
                $display("  >>> INTERRUPT! <<<");
            if (mret_tk)
                $display("  >>> MRET! <<<");
        end
    end
    
endmodule
