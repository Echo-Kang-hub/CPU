`timescale 1ns / 1ps
`include "soc_top.v"

module soc_top_tb();
    
    reg          clk;
    reg          rstn;
    reg  [4:0]   reg_sel;
    wire [31:0]  reg_data;
    
    // 实例化 SOC Top
    soc_top U_SOC_TOP(
        .clk      (clk), 
        .rstn     (rstn), 
        .reg_sel  (reg_sel), 
        .reg_data (reg_data) 
    );

    integer foutput;
    integer counter = 0;
    reg     stop_flag = 0; // 新增：用于延迟退出，确保最后一条指令写回
    
    wire [31:0] current_pc    = U_SOC_TOP.U_CPU.instr_addr; 
    wire [31:0] current_instr = U_SOC_TOP.U_CPU.instr;  

    initial begin
        $readmemh("inst.txt", U_SOC_TOP.U_IM.ROM); 
        $monitor("Time: %0t | PC = 0x%8X | instr = 0x%8X", $time, current_pc, current_instr);
        
        foutput = $fopen("results.txt", "w");
        clk = 1;
        rstn = 1;
        #5 rstn = 0;
        #20 rstn = 1;
        reg_sel = 7;
    end
    
    always #50 clk = ~clk;

    // 仿真监控逻辑
    always @(posedge clk) begin
        if (rstn == 1'b1) begin
            counter = counter + 1;

            // 打印实时进度到控制台
            if (current_pc !== 32'hxxxxxxxx) begin
                $display("Cycle: %0d | PC: %h | Instr: %h", counter, current_pc, current_instr);
            end

            // 停止逻辑：如果 PC 变成 X，或者达到最大安全周期
            if (current_pc === 32'hxxxxxxxx || counter >= 2000) begin
                if (stop_flag < 5) begin
                    stop_flag <= stop_flag + 1;
                end
                else begin
                    $display("--- Simulation End: Saving Results ---");
                    
                    // 1. 打印最终状态头信息
                    $fdisplay(foutput, "Final State at Cycle %0d:", counter);
                    $fdisplay(foutput, "PC: %h", current_pc);
                    
                    // 2. 打印全部 32 个寄存器 (分 8 行打印，每行 4 个)
                    $fdisplay(foutput, "rf00-03: %h %h %h %h", 32'h0, 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[1], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[2], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[3]);
                    $fdisplay(foutput, "rf04-07: %h %h %h %h", 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[4], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[5], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[6], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[7]);
                    $fdisplay(foutput, "rf08-11: %h %h %h %h", 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[8], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[9], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[10], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[11]);
                    $fdisplay(foutput, "rf12-15: %h %h %h %h", 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[12], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[13], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[14], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[15]);
                    $fdisplay(foutput, "rf16-19: %h %h %h %h", 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[16], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[17], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[18], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[19]);
                    $fdisplay(foutput, "rf20-23: %h %h %h %h", 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[20], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[21], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[22], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[23]);
                    $fdisplay(foutput, "rf24-27: %h %h %h %h", 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[24], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[25], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[26], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[27]);
                    $fdisplay(foutput, "rf28-31: %h %h %h %h", 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[28], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[29], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[30], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[31]);

                    $fclose(foutput);
                    $stop;
                end
            end
        end
    end

endmodule