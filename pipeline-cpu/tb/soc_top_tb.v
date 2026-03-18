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
    
    // 定义内部信号的快捷引用路径（避免 always 块内定义 wire 的报错）
    wire [31:0] current_pc    = U_SOC_TOP.U_CPU.instr_addr; 
    wire [31:0] current_instr = U_SOC_TOP.U_CPU.instr;  

    initial begin
        $readmemh("inst.txt", U_SOC_TOP.U_IM.ROM); 
        
        $monitor("Time: %0t | PC = 0x%8X | instr = 0x%8X", $time, current_pc, current_instr);
        
        foutput = $fopen("results.txt", "w");
        clk = 1;
        rstn = 1;
        #5;
        rstn = 0; // 复位
        #20;
        rstn = 1; // 释放复位
        
        reg_sel = 7;
    end
    
    // 时钟产生
    always begin
        #50 clk = ~clk;
    end

    // 仿真逻辑监控
    always @(posedge clk) begin
        if (rstn == 1'b1) begin
            if ((counter == 1000) || (current_pc === 32'hxxxxxxxx)) begin
                $display("Simulation Stop: Timeout or PC is X.");
                $fclose(foutput);
                $stop;
            end
            else begin
                if (current_pc == 32'h00000048) begin
                    counter = counter + 1;
                    $fdisplay(foutput, "Final PC: %h", current_pc);
                    $fdisplay(foutput, "Final Instr: %h", current_instr);
                    
                    $fdisplay(foutput, "rf00-03:\t %h %h %h %h", 32'h0, 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[1], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[2], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[3]);
                    $fdisplay(foutput, "rf04-07:\t %h %h %h %h", 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[4], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[5], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[6], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[7]);
                    $fdisplay(foutput, "rf08-11:\t %h %h %h %h", 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[8], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[9], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[10], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[11]);
                    $fdisplay(foutput, "rf12-15:\t %h %h %h %h", 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[12], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[13], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[14], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[15]);
                    $fdisplay(foutput, "rf16-19:\t %h %h %h %h", 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[16], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[17], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[18], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[19]);
                    $fdisplay(foutput, "rf20-23:\t %h %h %h %h", 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[20], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[21], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[22], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[23]);
                    $fdisplay(foutput, "rf24-27:\t %h %h %h %h", 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[24], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[25], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[26], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[27]);
                    $fdisplay(foutput, "rf28-31:\t %h %h %h %h", 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[28], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[29], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[30], 
                        U_SOC_TOP.U_CPU.u_ID_stage.U_RF.regfile[31]);
                    
                    $fclose(foutput);
                    $display("Results saved to results.txt. Simulation finished.");
                    $stop;
                end
                else begin
                    counter = counter + 1;
                    $display("Cycle: %0d | PC: %h | Instr: %h", counter, current_pc, current_instr);
                end
            end
        end
    end

endmodule