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

    initial begin
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
        // 打开日志文件
        f_out = $fopen("result.txt", "w");
        if (f_out == 0) begin
            $display("Error: Could not open result.txt");
            $finish;
        end
        $fdisplay(f_out, "========== RISC-V Pipeline Simulation Log ==========");

        // 导出波形图（可选，使用 gtkwave 查看）
        $dumpfile("wave.vcd");
        $dumpvars(0, tb);

        reset = 1;
        #15;       
        reset = 0; 
        
        #1000; // 设置仿真超时时间 (1000ns = 100个时钟周期)
        $fdisplay(f_out, "========== Simulation Timeout / Finished ==========");
        $fclose(f_out);
        $finish;
    end


    always @(posedge clk) begin
        if (!reset) begin
            // 1. 记录 IF 阶段取指
            $fdisplay(f_out, "Time: %4t | [IF]  Fetch PC = 0x%08h, Instr = 0x%08h", $time, instr_addr, instr);

            // 2. 记录 MA 阶段写内存
            if (DM_write_enable) begin
                $fdisplay(f_out, "Time: %4t | [MEM] WRITE Addr = 0x%08h, Data = 0x%08h", $time, DM_write_addr, DM_write_data);
                $display("Time: %4t | [MEM] WRITE Addr = 0x%08h, Data = 0x%08h", $time, DM_write_addr, DM_write_data); // 也在终端打一份
            end

            // 3. 记录 WB 阶段写寄存器 (通过探测顶层模块内部信号)
            // 注意：x0 寄存器硬件上不能写入，所以我们过滤掉 write_addr == 0 的情况
            if (u_cpu.RF_write_enable && u_cpu.RF_write_addr != 0) begin
                $fdisplay(f_out, "Time: %4t | [WB]  WRITE Reg[x%0d] = 0x%08h", $time, u_cpu.RF_write_addr, u_cpu.RF_write_data);
            end
            
            $fdisplay(f_out, "----------------------------------------------------");
        end
    end

endmodule