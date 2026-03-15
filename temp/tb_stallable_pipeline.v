`timescale 1ns / 1ps
`include "definition.vh"

// ============================================================
// 测试 I0 和 I3 指令（无数据冒险序列）
// datain[31:0]  = RISC-V 32位指令
// datain[63:32] = 当前指令的 PC 值（用于 AUIPC）
// dataout[31:0] = WB 写回值
// dataout[36:32]= rd（目标寄存器）
// dataout[37]   = RegWrite（写回有效）
//
// 指令编码说明（RISC-V）：
//   LUI   rd, imm   : {imm[31:12], rd, 7'b0110111}
//   AUIPC rd, imm   : {imm[31:12], rd, 7'b0010111}
//   ADDI  rd,rs1,imm: {imm[11:0], rs1, 3'b000, rd, 7'b0010011}
//   SLTI  rd,rs1,imm: {imm[11:0], rs1, 3'b010, rd, 7'b0010011}
//   SLTIU rd,rs1,imm: {imm[11:0], rs1, 3'b011, rd, 7'b0010011}
//   XORI  rd,rs1,imm: {imm[11:0], rs1, 3'b100, rd, 7'b0010011}
//   ORI   rd,rs1,imm: {imm[11:0], rs1, 3'b110, rd, 7'b0010011}
//   ANDI  rd,rs1,imm: {imm[11:0], rs1, 3'b111, rd, 7'b0010011}
//   SLLI  rd,rs1,shamt: {7'b0000000, shamt, rs1, 3'b001, rd, 7'b0010011}
//   SRLI  rd,rs1,shamt: {7'b0000000, shamt, rs1, 3'b101, rd, 7'b0010011}
//   SRAI  rd,rs1,shamt: {7'b0100000, shamt, rs1, 3'b101, rd, 7'b0010011}
// ============================================================
module tb_stallable_pipeline;

    // 参数声明
    parameter WIDTH = `PR_DATA_WIDTH;

    // 信号声明
    reg         	clk;
    reg         	rst;
    reg         	validin;
    reg [WIDTH-1:0] 	datain;
    reg         	out_allow;
    wire        	validout;
    wire [WIDTH-1:0] 	dataout;

    // 拆解输出字段
    wire [31:0] wb_result   = dataout[31:0];
    wire [4:0]  wb_rd       = dataout[36:32];
    wire        wb_regwrite = dataout[37];

    //---------------------------------------------------------------------
    // 实例化被测模块
    //---------------------------------------------------------------------
    stallable_pipeline sp(
        .clk(clk),
        .rst(rst),
        .validin(validin),
        .datain(datain),
        .out_allow(out_allow),
        .validout(validout),
        .dataout(dataout)
    );

    always begin
    	forever #5 clk = ~clk;
        if (clk == 1)
        begin
            counter = counter + 1;
        end
    end

    integer counter = 0;

    // 辅助任务：发送一条指令
    task send_instr;
        input [31:0] instr;
        input [31:0] pc;
        begin
            datain   = {{(WIDTH-64){1'b0}}, pc, instr};
            validin  = 1'b1;
            #10;
            validin  = 1'b0;
        end
    endtask

    initial begin
        // 初始化信号
        clk      = 0;
        rst      = 1'b1;
        validin  = 1'b0;
        datain   = {WIDTH{1'b0}};
        out_allow = 1'b1;

	    // 打开 VCD 波形记录
        $dumpfile("sp.vcd");
        $dumpvars(0, tb_stallable_pipeline);

        #10;
        rst = 1'b0; // 释放复位

        //--------------------------------------------------
        // 场景一：I0 指令 — LUI 和 AUIPC（无冒险）
        //--------------------------------------------------
        $display("=== 场景一：I0 指令（LUI / AUIPC）===");

        // LUI x1, 0xABCDE  => x1 = 0xABCDE000
        // 编码: {20'hABCDE, 5'd1, 7'b0110111}
        send_instr({20'hABCDE, 5'd1, 7'b0110111}, 32'h00000000);
        #40; // 等待流水线完成，再发下一条（无冒险）

        // AUIPC x2, 0x10   => x2 = PC(0x100) + 0x10000 = 0x10100
        // 编码: {20'h00010, 5'd2, 7'b0010111}
        send_instr({20'h00010, 5'd2, 7'b0010111}, 32'h00000100);
        #40;

        //--------------------------------------------------
        // 场景二：I3 指令 — 算术/逻辑/移位立即数（无冒险）
        //--------------------------------------------------
        $display("=== 场景二：I3 指令（ADDI/SLTI/SLTIU/XORI/ORI/ANDI）===");

        // ADDI x3, x0, 100  => x3 = 0 + 100 = 100 = 0x64
        // 编码: {12'd100, 5'd0, 3'b000, 5'd3, 7'b0010011}
        send_instr({12'd100, 5'd0, 3'b000, 5'd3, 7'b0010011}, 32'h00000200);
        #40;

        // SLTI x4, x0, 5    => x4 = (0 < 5) = 1
        // 编码: {12'd5, 5'd0, 3'b010, 5'd4, 7'b0010011}
        send_instr({12'd5, 5'd0, 3'b010, 5'd4, 7'b0010011}, 32'h00000204);
        #40;

        // SLTIU x5, x0, 1   => x5 = (0 <u 1) = 1
        // 编码: {12'd1, 5'd0, 3'b011, 5'd5, 7'b0010011}
        send_instr({12'd1, 5'd0, 3'b011, 5'd5, 7'b0010011}, 32'h00000208);
        #40;

        // XORI x6, x0, 12'hFFF  => x6 = 0 ^ 0xFFFFFFFF = 0xFFFFFFFF
        // 编码: {12'hFFF, 5'd0, 3'b100, 5'd6, 7'b0010011}
        send_instr({12'hFFF, 5'd0, 3'b100, 5'd6, 7'b0010011}, 32'h0000020C);
        #40;

        // ORI  x7, x0, 12'hA5   => x7 = 0 | 0xA5 = 0xA5
        // 编码: {12'hA5, 5'd0, 3'b110, 5'd7, 7'b0010011}
        send_instr({12'hA5, 5'd0, 3'b110, 5'd7, 7'b0010011}, 32'h00000210);
        #40;

        // ANDI x8, x0, 12'hFF   => x8 = 0 & 0xFF = 0
        // 编码: {12'hFF, 5'd0, 3'b111, 5'd8, 7'b0010011}
        send_instr({12'hFF, 5'd0, 3'b111, 5'd8, 7'b0010011}, 32'h00000214);
        #40;

        $display("=== 场景三：I3 移位指令（SLLI/SRLI/SRAI）===");

        // SLLI x9, x0, 4   => x9 = 0 << 4 = 0（使用 x0 结果平凡，只验证控制路径）
        // 编码: {7'b0000000, 5'd4, 5'd0, 3'b001, 5'd9, 7'b0010011}
        send_instr({7'b0000000, 5'd4, 5'd0, 3'b001, 5'd9, 7'b0010011}, 32'h00000218);
        #40;

        // SRLI x10, x0, 2  => x10 = 0 >> 2 = 0
        // 编码: {7'b0000000, 5'd2, 5'd0, 3'b101, 5'd10, 7'b0010011}
        send_instr({7'b0000000, 5'd2, 5'd0, 3'b101, 5'd10, 7'b0010011}, 32'h0000021C);
        #40;

        // SRAI x11, x0, 1  => x11 = 0 >>> 1 = 0
        // 编码: {7'b0100000, 5'd1, 5'd0, 3'b101, 5'd11, 7'b0010011}
        send_instr({7'b0100000, 5'd1, 5'd0, 3'b101, 5'd11, 7'b0010011}, 32'h00000220);
        #40;

        //--------------------------------------------------
        // 场景四：out_allow 被拉低（阻塞 WB 级），观察流水线暂停
        //--------------------------------------------------
        $display("=== 场景四：out_allow=0 阻塞 WB 级 ===");

        send_instr({20'h12345, 5'd12, 7'b0110111}, 32'h00000300); // LUI x12, 0x12345
        out_allow = 1'b0;
        #40;
        $display("Resuming: out_allow=1");
        out_allow = 1'b1;
        #50;

        //--------------------------------------------------
        // 场景五：复位清空流水线
        //--------------------------------------------------
        $display("=== 场景五：复位 ===");
        rst = 1'b1;
        #20;
        rst = 1'b0;
        #50;

        $finish;
    end

    // 监视 WB 输出
    always @(posedge clk) begin
        if (validout && wb_regwrite)
            $display("[WB] t=%0t  rd=x%0d  result=0x%08h", $time, wb_rd, wb_result);
    end

endmodule