// todo：有符号数和无符号数的区分

// 立即数扩展
`define EXT_CTRL_ITYPE_SHAMT 6'b100000
`define EXT_CTRL_ITYPE 6'b010000
`define EXT_CTRL_STYPE 6'b001000
`define EXT_CTRL_BTYPE 6'b000100
`define EXT_CTRL_UTYPE 6'b000010
`define EXT_CTRL_JTYPE 6'b000001

module EXT(
    input [31:0] instr,
    output reg [31:0] immout
);
    wire [4:0]  iimm_shamt = instr[24:20]; // slli/srli/srai
    wire [11:0] iimm       = instr[31:20]; // addi/slti/sltiu/xori/ori/andi + lb/lh/lw/lbu/lhu + jalr
    wire [11:0] simm       = {instr[31:25], instr[11:7]}; // sb/sh/sw
    wire [11:0] bimm       = {instr[31], instr[7], instr[30:25], instr[11:8]}; // beq/bne/blt/bge/bltu/bgeu
    wire [19:0] uimm       = instr[31:12]; // lui/auipc
    wire [19:0] jimm       = {instr[31], instr[19:12], instr[20], instr[30:21]}; // jal

    // 译码指令类型
    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];

    wire itype_shamt = (opcode == 7'b0010011) && (funct3 == 3'b001 || funct3 == 3'b101); // slli/srli/srai
    wire itype_r     = (opcode == 7'b0010011) && !(funct3 == 3'b001 || funct3 == 3'b101); // 其余 OP-IMM
    wire itype_l     = (opcode == 7'b0000011); // LOAD
    wire i_jalr      = (opcode == 7'b1100111); // JALR
    wire stype       = (opcode == 7'b0100011); // STORE
    wire btype       = (opcode == 7'b1100011); // BRANCH
    wire i_lui       = (opcode == 7'b0110111); // LUI
    wire i_auipc     = (opcode == 7'b0010111); // AUIPC
    wire i_jal       = (opcode == 7'b1101111); // JAL

    // EXTOp one-hot: [5]=ITYPE_SHAMT, [4]=ITYPE, [3]=STYPE, [2]=BTYPE, [1]=UTYPE, [0]=JTYPE
    wire [5:0] EXTOp;
    assign EXTOp[5] = itype_shamt;
    assign EXTOp[4] = itype_l | itype_r | i_jalr;
    assign EXTOp[3] = stype;
    assign EXTOp[2] = btype;
    assign EXTOp[1] = i_lui | i_auipc;
    assign EXTOp[0] = i_jal;

    always @(*) begin
        case (EXTOp)
            `EXT_CTRL_ITYPE_SHAMT: immout = {27'b0, iimm_shamt[4:0]}; // I-type 立即数 (用于 slli/srli/srai)
            `EXT_CTRL_ITYPE:       immout = {{20{iimm[11]}}, iimm[11:0]}; // I-type 立即数 (用于 addi, lw, jalr 等)
            `EXT_CTRL_STYPE:       immout = {{20{simm[11]}}, simm[11:0]}; // S-type 立即数 (用于 sw 等)
            `EXT_CTRL_BTYPE:       immout = {{19{bimm[11]}}, bimm[11:0], 1'b0}; // B-type 立即数 (用于 beq 等)
            `EXT_CTRL_UTYPE:       immout = {uimm[19:0], 12'b0}; // U-type 立即数 (用于 lui, auipc)
            `EXT_CTRL_JTYPE:       immout = {{11{jimm[19]}}, jimm[19:0], 1'b0}; // J-type 立即数 (用于 jal)
            default:               immout = 32'b0;
        endcase
    end

endmodule