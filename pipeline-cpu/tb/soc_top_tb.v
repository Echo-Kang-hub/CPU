`timescale 1ns / 1ps
`include "soc_top.v" 

// 名字改为 tb_soc_top
module tb_soc_top();
    
    reg         clk;
    reg         rstn;  
    reg  [4:0]  reg_sel;
    wire [31:0] reg_data;
    
    soc_top U_SOC(
        .clk      (clk), 
        .rstn     (rstn), 
        .reg_sel  (reg_sel), 
        .reg_data (reg_data) 
    );

    integer foutput;
    integer counter = 0;
   
    initial begin
        foutput = $fopen("results.txt", "w");
        if (foutput == 0) begin
            $display("Error: Could not open results.txt");
            $finish;
        end
        $fdisplay(foutput, "========== RISC-V Pipeline Simulation ==========\n");

        $readmemh("inst.txt", U_SOC.U_IM.ROM); 
        
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_soc_top); 

        clk = 1;
        rstn = 1;
        #5;
        rstn = 0; 
        #20;
        rstn = 1; 
        
        reg_sel = 7; 
    end
   
    always begin
        #50 clk = ~clk;
    end
   
    always @(posedge clk) begin
        if (rstn == 1'b1) begin 
            counter = counter + 1;
            
            wire [31:0] current_pc    = U_SOC.U_CPU.instr_addr;
            wire [31:0] current_instr = U_SOC.U_CPU.instr;
            
            $fdisplay(foutput, "Time: %0t | Cycle: %0d | PC: %h | Instr: %h", $time, counter, current_pc, current_instr);
            $display("Cycle: %0d | PC: %h | Instr: %h", counter, current_pc, current_instr);
            
            if ((counter == 1000) || (current_pc === 32'hxxxxxxxx) || (current_instr == 32'h0000006f)) begin
                
                $fdisplay(foutput, "\n========== SIMULATION FINISHED ==========");
                if (current_instr == 32'h0000006f)
                    $fdisplay(foutput, "Reason: Infinite Loop Detected (jal x0, 0) at PC = %h", current_pc);
                else if (counter == 1000)
                    $fdisplay(foutput, "Reason: Timeout (1000 cycles)");
                else
                    $fdisplay(foutput, "Reason: PC goes to X state!");

                $fdisplay(foutput, "\n---------- Final Register File Snapshot ----------");
                
                $fdisplay(foutput, "rf00-03:\t %h %h %h %h", 0, 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[1], 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[2], 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[3]);
                $fdisplay(foutput, "rf04-07:\t %h %h %h %h", 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[4], 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[5], 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[6], 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[7]);
                $fdisplay(foutput, "rf08-11:\t %h %h %h %h", 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[8], 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[9], 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[10], 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[11]);
                $fdisplay(foutput, "rf12-15:\t %h %h %h %h", 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[12], 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[13], 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[14], 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[15]);
                $fdisplay(foutput, "rf16-19:\t %h %h %h %h", 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[16], 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[17], 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[18], 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[19]);
                $fdisplay(foutput, "rf20-23:\t %h %h %h %h", 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[20], 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[21], 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[22], 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[23]);
                $fdisplay(foutput, "rf24-27:\t %h %h %h %h", 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[24], 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[25], 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[26], 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[27]);
                $fdisplay(foutput, "rf28-31:\t %h %h %h %h", 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[28], 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[29], 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[30], 
                    U_SOC.U_CPU.u_ID_stage.U_RF.regfile[31]);
                
                $fclose(foutput);
                $stop;
            end
        end
    end 
   
endmodule