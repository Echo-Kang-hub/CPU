`timescale 1ns / 1ps
`include "soc_top.v"

module bus_debug_tb();
    reg clk, rstn;
    integer cycle = 0;
    
    soc_top U_SOC(.clk(clk), .rstn(rstn), .reg_sel(0), .reg_data());
    
    // EX_to_MA_bus 原始值
    wire [152:0] ex_to_ma_bus = U_SOC.U_CPU.u_EX_stage.EX_to_MA_bus;
    wire [152:0] ex_to_ma_reg = U_SOC.U_CPU.u_MA_stage.EX_to_MA_bus_reg;
    
    // 解包值
    wire        ma_csr_we   = U_SOC.U_CPU.u_MA_stage.MA_csr_we;
    wire [11:0] ma_csr_addr = U_SOC.U_CPU.u_MA_stage.MA_csr_addr;
    wire [31:0] ma_csr_wdata = U_SOC.U_CPU.u_MA_stage.MA_csr_write_data;
    
    // EX 阶段值
    wire        ex_csr_we   = U_SOC.U_CPU.u_EX_stage.EX_csr_we;
    wire [11:0] ex_csr_addr = U_SOC.U_CPU.u_EX_stage.EX_csr_addr;
    wire [31:0] ex_csr_wdata = U_SOC.U_CPU.u_EX_stage.EX_csr_write_data;
    
    wire [31:0] PC = U_SOC.U_CPU.instr_addr;
    wire [31:0] mstatus = U_SOC.U_CPU.mstatus;
    wire [31:0] mie_csr = U_SOC.U_CPU.mie;
    
    initial begin clk = 0; rstn = 1; #25 rstn = 0; #100 rstn = 1; end
    always #50 clk = ~clk;
    
    initial begin
        repeat(30) @(posedge clk);
        $finish;
    end
    
    always @(posedge clk) begin
        if (rstn) begin
            cycle = cycle + 1;
            if (cycle >= 3 && cycle <= 12) begin
                $display("CYCLE=%0d: PC=0x%h", cycle, PC);
                $display("  EX: we=%b addr=0x%h wdata=0x%h", ex_csr_we, ex_csr_addr, ex_csr_wdata);
                $display("  MA: we=%b addr=0x%h wdata=0x%h", ma_csr_we, ma_csr_addr, ma_csr_wdata);
                $display("  CSR: mstatus=0x%h mie=0x%h", mstatus, mie_csr);
                $display("  EX_to_MA_bus[44:0]=0x%h", ex_to_ma_bus[44:0]);
                $display("  EX_to_MA_reg[44:0]=0x%h", ex_to_ma_reg[44:0]);
                // 手动解包
                $display("  Manual unpack: we=%b addr=0x%h wdata=0x%h", 
                         ex_to_ma_reg[44], ex_to_ma_reg[43:32], ex_to_ma_reg[31:0]);
                $display("");
            end
        end
    end
endmodule
