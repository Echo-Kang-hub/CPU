`timescale 1ns / 1ps

`include "pipeline_top.v"

module tb;
    reg         clk;
    reg         reset;

    wire [31:0] instr_addr;
    wire [31:0] instr;
    wire [31:0] DM_write_addr;
    wire [31:0] DM_write_data;
    wire        DM_write_enable;
    wire [31:0] DM_read_data;


    pipeline_top u_cpu(
        .clk              (clk),
        .reset            (reset),
        .instr_addr       (instr_addr),
        .instr            (instr),
        .DM_write_addr    (DM_write_addr), 
        .DM_write_data    (DM_write_data),
        .DM_write_enable  (DM_write_enable),
        .DM_read_data     (DM_read_data)
    );
    

    reg [31:0] imem [0:255]; 
    wire [29:0] word_addr = instr_addr[31:2]; 
    assign instr = imem[word_addr];

    reg [31:0] dmem [0:255]; 
    wire [29:0] dmem_word_addr = DM_write_addr[31:2];
    assign DM_read_data = dmem[dmem_word_addr]; 

    initial begin: MEM_INIT
        integer i;
        for (i = 0; i < 256; i = i + 1) imem[i] = 32'h0;
        $readmemh("inst.txt", imem); 
    end

    always @(posedge clk) begin
        if (DM_write_enable) begin
            dmem[dmem_word_addr] <= DM_write_data; 
        end
    end

    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    integer f_out;

    initial begin
        f_out = $fopen("result.txt", "w");
        if (f_out == 0) begin
            $display("Error: Could not open result.txt");
            $finish;
        end
        $fdisplay(f_out, "========== RISC-V Pipeline X-Ray Debug Log ==========");
        $dumpfile("wave.vcd");
        $dumpvars(0, tb);

        reset = 1;
        repeat(3) @(negedge clk); 
        reset = 0; 
        
        repeat(300) @(posedge clk); 
        
        // 4. 安全退出
        $fdisplay(f_out, "========== Simulation Timeout / Finished ==========");
        $fclose(f_out);
        $finish;
    end

    always @(posedge clk) begin
        if (!reset) begin
            $fdisplay(f_out, "================= Time: %0t =================", $time);
            
            // [IF]
            $fdisplay(f_out, "[IF] PC = 0x%08h | Instr = 0x%08h", instr_addr, instr);

            // [ID]
            $fdisplay(f_out, "[ID] PC = 0x%08h | RD1 = 0x%08h | RD2 = 0x%08h | Imm = 0x%08h", 
                      u_cpu.u_ID_stage.PC_addr, u_cpu.u_ID_stage.RD1, u_cpu.u_ID_stage.RD2, u_cpu.u_ID_stage.immout);
            $fdisplay(f_out, "     Branch_taken = %b | Jal_taken = %b | Jalr_taken = %b", 
                      u_cpu.u_ID_stage.Branch_taken, u_cpu.u_ID_stage.Jal_taken, u_cpu.u_ID_stage.Jalr_taken);

            // [EX]
            $fdisplay(f_out, "[EX] PC = 0x%08h | ALU_A = 0x%08h | ALU_B = 0x%08h | ALU_Out = 0x%08h", 
                      u_cpu.u_EX_stage.PC_addr, u_cpu.u_EX_stage.A, u_cpu.u_EX_stage.B, u_cpu.u_EX_stage.aluout);

            // [MA]
            if (DM_write_enable) begin
                $fdisplay(f_out, "[MA] WRITE MEM: Addr = 0x%08h, Data = 0x%08h", DM_write_addr, DM_write_data);
                $display("Time: %0t | [MEM] WRITE Addr = 0x%08h, Data = 0x%08h", $time, DM_write_addr, DM_write_data); 
            end

            // [WB]
            if (u_cpu.RF_write_enable && u_cpu.RF_write_addr != 0) begin
                $fdisplay(f_out, "[WB] WRITE REG: x%0d = 0x%08h", u_cpu.RF_write_addr, u_cpu.RF_write_data);
            end
            
            $fdisplay(f_out, ""); // 空行分隔
        end
    end

endmodule