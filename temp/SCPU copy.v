module SCPU(
    input  clk,
    input  reset,
    input  [31:0] inst_in,
    input  [31:0] Data_in,
    output mem_w,
    output [31:0] PC_out,
    output [31:0] Addr_out,
    output [31:0] Data_out,
    input  [4:0]  reg_sel,    // 调试用：选择要读的寄存器（sccomp外部输入）
    output [31:0] reg_data    // 调试用：输出所选寄存器值
);

    // ---- 指令解码 ----
    wire [31:0] instr = inst_in;          // 供TB通过 U_SCPU.instr 访问
    wire [6:0]  Op         = instr[6:0];
    wire [6:0]  Funct7     = instr[31:25];
    wire [2:0]  Funct3     = instr[14:12];
    wire [4:0]  rs1        = instr[19:15];
    wire [4:0]  rs2        = instr[24:20];
    wire [4:0]  rd         = instr[11:7];
    wire [4:0]  iimm_shamt = instr[24:20];
    wire [11:0] iimm       = instr[31:20];
    wire [11:0] simm       = {instr[31:25], instr[11:7]};
    wire [11:0] bimm       = {instr[31], instr[7], instr[30:25], instr[11:8]};
    wire [19:0] uimm       = instr[31:12];
    wire [19:0] jimm       = {instr[31], instr[19:12], instr[20], instr[30:21]};

    // ---- 控制信号 ----
    wire        RegWrite, MemWrite, ALUSrc, ALUSrcA, Zero;
    wire [2:0]  NPCOp;
    wire [4:0]  ALUOp;
    wire [5:0]  EXTOp;
    wire [2:0]  DMType;
    wire [1:0]  WDSel;

    ctrl u_ctrl(
        .Op(Op), .Funct7(Funct7), .Funct3(Funct3), .Zero(Zero),
        .RegWrite(RegWrite), .MemWrite(MemWrite),
        .EXTOp(EXTOp), .ALUOp(ALUOp), .ALUSrc(ALUSrc), .ALUSrcA(ALUSrcA),
        .NPCOp(NPCOp), .DMType(DMType), .WDSel(WDSel)
    );

    // ---- PC / NPC ----
    wire [31:0] PC, NPC;

    PC_Unit U_PC(
        .clk(clk), .rst(reset),    // reset 高电平有效（sccomp 已取反 rstn）
        .NPC(NPC), .PCwr(1'b1),    // 单周期 CPU，每拍必须更新 PC
        .PC(PC)
    );
    assign PC_out = PC;             // 供 sccomp 及 TB 访问

    // ---- 立即数扩展 ----
    wire [31:0] immout;

    EXT U_EXT(
        .iimm_shamt(iimm_shamt), .iimm(iimm), .simm(simm),
        .bimm(bimm), .uimm(uimm), .jimm(jimm),
        .EXTOp(EXTOp), .immout(immout)
    );

    // ---- NPC 计算 ----
    wire [31:0] aluout;  // 提前声明供 NPC_Unit 使用

    NPC_Unit U_NPC(
        .PC(PC), .NPCOp(NPCOp), .IMM(immout), .aluout(aluout),
        .NPC(NPC)
    );

    // ---- 寄存器堆 ----
    wire [31:0] RD1, RD2, WD;

    RF U_RF(
        .clk(clk), .rstn(~reset),
        .RFWr(RegWrite), .sw_i(16'b0),  // sw_i=0：使能正常写入
        .A1(rs1), .A2(rs2), .A3(rd),
        .WD(WD), .RD1(RD1), .RD2(RD2)
    );

    // 调试读端口：直接访问 RF 内部数组（仿真可用）
    assign reg_data = (reg_sel == 5'b0) ? 32'b0 : U_RF.rf[reg_sel];

    // ---- ALU ----
    wire [31:0] A = ALUSrcA ? PC     : RD1;  // auipc 时 A=PC
    wire [31:0] B = ALUSrc  ? immout : RD2;

    alu U_alu(
        .A(A), .B(B), .ALUOp(ALUOp),
        .C(aluout), .Zero(Zero)
    );

    // ---- load 数据对齐（字节/半字符号/无符号扩展）----
    wire [1:0] dm_byte_sel = aluout[1:0];
    reg  [31:0] load_data;
    always @(*) begin
        case (DMType[1:0])
            2'b00: begin // 字节
                case (dm_byte_sel)
                    2'b00: load_data = DMType[2] ? {24'b0, Data_in[7:0]}    : {{24{Data_in[7]}},  Data_in[7:0]};
                    2'b01: load_data = DMType[2] ? {24'b0, Data_in[15:8]}   : {{24{Data_in[15]}}, Data_in[15:8]};
                    2'b10: load_data = DMType[2] ? {24'b0, Data_in[23:16]}  : {{24{Data_in[23]}}, Data_in[23:16]};
                    default: load_data = DMType[2] ? {24'b0, Data_in[31:24]} : {{24{Data_in[31]}}, Data_in[31:24]};
                endcase
            end
            2'b01: begin // 半字
                load_data = dm_byte_sel[1]
                    ? (DMType[2] ? {16'b0, Data_in[31:16]} : {{16{Data_in[31]}}, Data_in[31:16]})
                    : (DMType[2] ? {16'b0, Data_in[15:0]}  : {{16{Data_in[15]}}, Data_in[15:0]});
            end
            default: load_data = Data_in; // 字（lw）
        endcase
    end

    // ---- 写回选择 ----
    // WDSel: 00=aluout, 01=load_data, 10=PC+4(jal/jalr), 11=immout(lui)
    assign WD = (WDSel == 2'b11) ? immout
              : (WDSel == 2'b10) ? (PC + 32'd4)
              : (WDSel == 2'b01) ? load_data
              :                    aluout;

    // ---- 对外输出 ----
    assign mem_w    = MemWrite;
    assign Addr_out = aluout;    // 内存地址（ALU结果）
    assign Data_out = RD2;       // 写内存数据（store 时为 rs2）

endmodule