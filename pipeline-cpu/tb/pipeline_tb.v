// `timescale 1ns / 1ps
// `include "pipeline_top.v"

// module tb;
//     reg         clk;
//     reg         reset;

//     wire [31:0] instr_addr;
//     wire [31:0] instr;
//     wire [31:0] DM_write_addr;
//     wire [31:0] DM_write_data;
//     wire        DM_write_enable;
//     wire [31:0] DM_read_data;

//     pipeline_top u_cpu(
//         .clk              (clk),
//         .reset            (reset),
//         .instr_addr       (instr_addr),
//         .instr            (instr),
//         .DM_write_addr    (DM_write_addr),
//         .DM_write_data    (DM_write_data),
//         .DM_write_enable  (DM_write_enable),
//         .DM_read_data     (DM_read_data)
//     );
    

//     reg [31:0] imem [0:255]; 
//     wire [29:0] word_addr = instr_addr[31:2]; 
//     assign instr = imem[word_addr];

//     reg [31:0] dmem [0:255]; 
//     wire [29:0] dmem_word_addr = DM_write_addr[31:2];
//     assign DM_read_data = dmem[dmem_word_addr]; 

//     initial begin
//         $readmemh("inst.txt", imem); 
//     end

//     always @(posedge clk) begin
//         if (DM_write_enable) begin
//             dmem[dmem_word_addr] <= DM_write_data; 
//         end
//     end


//     initial begin
//         clk = 0;
//         forever #5 clk = ~clk; 
//     end


//     integer f_out;

//     initial begin
//         // 打开日志文件
//         f_out = $fopen("result.txt", "w");
//         if (f_out == 0) begin
//             $display("Error: Could not open result.txt");
//             $finish;
//         end
//         $fdisplay(f_out, "========== RISC-V Pipeline Simulation Log ==========");

//         // 导出波形图（可选，使用 gtkwave 查看）
//         $dumpfile("wave.vcd");
//         $dumpvars(0, tb);

//         reset = 1;
//         #15;       
//         reset = 0; 
        
//         #1000; // 设置仿真超时时间 (1000ns = 100个时钟周期)
//         $fdisplay(f_out, "========== Simulation Timeout / Finished ==========");
//         $fclose(f_out);
//         $finish;
//     end


//     always @(posedge clk) begin
//         if (!reset) begin
//             // 1. 记录 IF 阶段取指
//             $fdisplay(f_out, "Time: %4t | [IF]  Fetch PC = 0x%08h, Instr = 0x%08h", $time, instr_addr, instr);

//             // 2. 记录 MA 阶段写内存
//             if (DM_write_enable) begin
//                 $fdisplay(f_out, "Time: %4t | [MEM] WRITE Addr = 0x%08h, Data = 0x%08h", $time, DM_write_addr, DM_write_data);
//                 $display("Time: %4t | [MEM] WRITE Addr = 0x%08h, Data = 0x%08h", $time, DM_write_addr, DM_write_data); // 也在终端打一份
//             end

//             // 3. 记录 WB 阶段写寄存器 (通过探测顶层模块内部信号)
//             // 注意：x0 寄存器硬件上不能写入，所以我们过滤掉 write_addr == 0 的情况
//             if (u_cpu.RF_write_enable && u_cpu.RF_write_addr != 0) begin
//                 $fdisplay(f_out, "Time: %4t | [WB]  WRITE Reg[x%0d] = 0x%08h", $time, u_cpu.RF_write_addr, u_cpu.RF_write_data);
//             end
            
//             $fdisplay(f_out, "----------------------------------------------------");
//         end
//     end

// endmodule

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
    
    // ==========================================
    // IMEM & DMEM
    // ==========================================
    reg [31:0] imem [0:255]; 
    wire [29:0] word_addr = instr_addr[31:2]; 
    assign instr = imem[word_addr];

    reg [31:0] dmem [0:255]; 
    wire [29:0] dmem_word_addr = DM_write_addr[31:2];
    assign DM_read_data = dmem[dmem_word_addr]; 

    initial begin:MEM_INIT
        // 初始化内存为0，消除没写满导致的 "Not enough words" 警告
        integer i;
        for (i=0; i<256; i=i+1) imem[i] = 32'h0;
        
        $readmemh("inst.txt", imem); 
    end

    always @(posedge clk) begin
        if (DM_write_enable) begin
            dmem[dmem_word_addr] <= DM_write_data; 
        end
    end

    // ==========================================
    // 时钟与复位生成
    // ==========================================
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
        // 【关键修复】：把 #15 改成 #18，错开时钟上升沿，防止复位竞争产生 X 态！
        #18;       
        reset = 0; 
        
        #1000; 
        $fdisplay(f_out, "========== Simulation Timeout / Finished ==========");
        
        // 【关键修复】：增加 #1 延时，防止 finish 杀掉文件句柄引发 WARNING
        #1; 
        $fclose(f_out);
        $finish;
    end

    // ==========================================
    // 核心探针：全景记录流水线各级状态
    // ==========================================
    always @(posedge clk) begin
        if (!reset) begin
            $fdisplay(f_out, "================= Time: %0t =================", $time);
            
            // 1. IF 阶段探针
            $fdisplay(f_out, "[IF] PC = 0x%08h | Instr = 0x%08h", instr_addr, instr);

            // 2. ID 阶段探针 (探测译码和寄存器读出结果)
            $fdisplay(f_out, "[ID] PC = 0x%08h | RD1 = 0x%08h | RD2 = 0x%08h | Imm = 0x%08h", 
                      u_cpu.u_ID_stage.PC_addr, u_cpu.u_ID_stage.RD1, u_cpu.u_ID_stage.RD2, u_cpu.u_ID_stage.immout);
            $fdisplay(f_out, "     Branch_taken = %b | Jal_taken = %b | Jalr_taken = %b", 
                      u_cpu.u_ID_stage.Branch_taken, u_cpu.u_ID_stage.Jal_taken, u_cpu.u_ID_stage.Jalr_taken);

            // 3. EX 阶段探针 (探测 ALU 计算结果)
            $fdisplay(f_out, "[EX] PC = 0x%08h | ALU_A = 0x%08h | ALU_B = 0x%08h | ALU_Out = 0x%08h", 
                      u_cpu.u_EX_stage.PC_addr, u_cpu.u_EX_stage.A, u_cpu.u_EX_stage.B, u_cpu.u_EX_stage.aluout);

            // 4. MA 阶段探针
            if (DM_write_enable) begin
                $fdisplay(f_out, "[MA] WRITE MEM: Addr = 0x%08h, Data = 0x%08h", DM_write_addr, DM_write_data);
                $display("Time: %0t | [MEM] WRITE Addr = 0x%08h, Data = 0x%08h", $time, DM_write_addr, DM_write_data); 
            end

            // 5. WB 阶段探针
            if (u_cpu.RF_write_enable && u_cpu.RF_write_addr != 0) begin
                $fdisplay(f_out, "[WB] WRITE REG: x%0d = 0x%08h", u_cpu.RF_write_addr, u_cpu.RF_write_data);
            end
            
            $fdisplay(f_out, ""); // 留一个空行，方便阅读
        end
    end

endmodule