`timescale 1ns / 1ps

`include "PC_Unit.v"
`include "NPC_Unit.v"
`include "RF.v"
`include "EXT.v"
`include "ctrl.v"
`include "alu.v"

// 37条指令
// I0: LUI/AUIPC 2 
// I3: ADDI/SLTI/SLTIU/XORI/ORI/ANDI/SLLI/SRLI/SRAI 9
// I4: ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND 10
// I1: JAL/JALR/BEQ/BNE/BLT/BGE/BLTU/BGEU 8
// I2：LB/LH/LW/LBU/LHU/SB/SH/SW 8
module SCPU(
    input  clk,
    input  reset,
    input  [31:0] inst_in,
    input  [31:0] Data_in,
    output mem_w,
    output [31:0] PC_out,
    output [31:0] Addr_out,
    output [31:0] Data_out,
    input  [4:0]  reg_sel,
    output [31:0] reg_data
);
    wire [31:0] instr = inst_in;

    // PC
    wire [31:0] PC;
    wire [31:0] NPC;
    wire PCwr = 1'b1;
    
    // 例化PC_Unit module 时序逻辑
    PC_Unit U_PC(.clk(clk),.rst(reset),.NPC(NPC),.PCwr(PCwr),.PC(PC));

    // 例化NPC_Unit module 组合逻辑
    NPC_Unit U_NPC(.PC(PC),.NPCOp(NPCOp),.IMM(immout),.aluout(aluout),.NPC(NPC));

    //Decode
    wire [6:0]  Op        = instr[6:0];
    wire [6:0]  Funct7    = instr[31:25];
    wire [2:0]  Funct3    = instr[14:12];
    wire [4:0]  rs1       = instr[19:15];
    wire [4:0]  rs2       = instr[24:20];
    wire [4:0]  rd        = instr[11:7];
    wire [4:0]  iimm_shamt= instr[24:20];
    wire [11:0] iimm      = instr[31:20]; // jalr, load, itype
    wire [11:0] simm      = {instr[31:25],instr[11:7]};
    wire [11:0] bimm      = {instr[31],instr[7],instr[30:25],instr[11:8]};
    wire [19:0] uimm      = instr[31:12]; // lui, auipc
    wire [19:0] jimm      = {instr[31],instr[19:12],instr[20],instr[30:21]}; // jal

    wire [31:0] WD;
    wire [31:0] RD1,RD2;

    RF U_RF(
        .clk(clk),
        .rstn(reset),
        .RFWr(RegWrite),
        .A1(rs1),
        .A2(rs2),
        .A3(rd),
        .WD(WD),
        .RD1(RD1),
        .RD2(RD2)
    );

    wire [31:0] immout;

    EXT U_EXT(
        .iimm_shamt(iimm_shamt),
        .iimm(iimm),
        .simm(simm),
        .bimm(bimm),
        .uimm(uimm),
        .jimm(jimm),
        .EXTOp(EXTOp),
        .immout(immout)
    );

    // 控制信号
    wire        RegWrite, MemWrite, ALUSrc, ALUSrcA, Zero;
    wire [1:0]  NPCOp;
    wire [4:0]  ALUOp;
    wire [2:0]  EXTOp;
    wire [2:0]  DMType;
    wire [2:0]  WDSel;

    // 例化ctrl模块 组合逻辑
    ctrl u_ctrl(
        .Op(Op),
        .Funct7(Funct7),
        .Funct3(Funct3),
        .Zero(Zero),
        .RegWrite(RegWrite),
        .MemWrite(MemWrite),
        .NPCOp(NPCOp),
        .EXTOp(EXTOp),
        .ALUSrc(ALUSrc),
        .ALUOp(ALUOp),
        .DMType(DMType),
        .WDSel(WDSel)
    );

    // RF->ALU ALU_A_B
    assign A = RD1;
    assign B = (ALUSrc == 1'b0)? RD2 : immout;

    // ALU->DM DM_addr_din
    assign dm_addr = aluout;
    assign dm_din = RD2;

    wire [31:0] A,B;
    wire [31:0] aluout;
    // 例化alu模块 组合逻辑
    alu U_alu(
        .A(A),
        .B(B),
        .ALUOp(ALUOp),
        .C(aluout),
        .Zero(Zero)
    );

    reg [31:0] load_data;
    wire [7:0]  selected_byte;
    wire [15:0] selected_half;

    assign selected_byte = Data_in >> (aluout[1:0] * 8);
    assign selected_half = aluout[1] ? Data_in[31:16] : Data_in[15:0];

    always @(*) begin
        case (DMType)
            `DM_BYTE:  load_data = {{24{selected_byte[7]}}, selected_byte}; // LB (符号扩展)
            `DM_BYTEU: load_data = {24'b0, selected_byte};                 // LBU (零扩展)
            `DM_HALF:  load_data = {{16{selected_half[15]}}, selected_half}; // LH (符号扩展)
            `DM_HALFU: load_data = {16'b0, selected_half};                 // LHU (零扩展)
            `DM_WORD:  load_data = Data_in;                                // LW
            default:   load_data = Data_in;
        endcase
    end

    assign WD = (WDSel == `WD_ALU) ? aluout : // slti/sltiu/addi/add/sub/sll/slt/sltu/xor/srl/sra/or/and
                (WDSel == `WD_MEM) ? load_data : // load
                (WDSel == `WD_PC4) ? (PC + 4) : // jal/jalr
                (WDSel == `WD_IMM) ? immout : // lui
                (WDSel == `WD_PCIMM) ? (PC + immout) : // auipc
                32'h00000000;

    assign PC_out = PC;
    assign mem_w    = MemWrite;
    assign Addr_out = aluout;    // 内存地址（ALU结果）
    assign Data_out = RD2;       // 写内存数据（store 时为 rs2）
    assign reg_data = (reg_sel == 5'b0) ? 32'b0 : U_RF.rf[reg_sel];

endmodule 