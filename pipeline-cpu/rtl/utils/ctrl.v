`include "definition.vh"
module ctrl(
    input wire [6:0] Op,
    input wire [6:0] Funct7,
    input wire [2:0] Funct3,
    output wire RegWrite,
    output wire ALUSrc1,
    output wire ALUSrc2,
    output wire MemWrite,
    output wire [2:0] EXTOp,
    output wire [2:0] BranchOp,
    output wire [3:0] ALUOp,
    output wire [2:0] DMType,
    output wire [1:0] MemtoReg 
);
    // R_type 10条
    // I4: ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND 10
    wire rtype = ~Op[6] & Op[5] & Op[4] & ~Op[3] & ~Op[2] & Op[1] & Op[0]; //0110011
    wire i_add = rtype & ~Funct3[2] & ~Funct3[1] & ~Funct3[0] & ~Funct7[5]; // add 0000000 000
    wire i_sub = rtype & ~Funct3[2] & ~Funct3[1] & ~Funct3[0] & Funct7[5]; // sub 0100000 000
    wire i_sll = rtype & ~Funct3[2] & ~Funct3[1] & Funct3[0]; // sll 0000000 001
    wire i_slt = rtype & ~Funct3[2] & Funct3[1] & ~Funct3[0]; // slt 0000000 010
    wire i_sltu = rtype & ~Funct3[2] & Funct3[1] & Funct3[0]; // sltu 0000000 011
    wire i_xor = rtype & Funct3[2] & ~Funct3[1] & ~Funct3[0]; // xor 0000000 100
    wire i_srl = rtype & Funct3[2] & ~Funct3[1] & Funct3[0] & ~Funct7[5]; // srl 0000000 101
    wire i_sra = rtype & Funct3[2] & ~Funct3[1] & Funct3[0] & Funct7[5]; // sra 0100000 101
    wire i_or  = rtype & Funct3[2] & Funct3[1] & ~Funct3[0]; // or 0000000 110
    wire i_and = rtype & Funct3[2] & Funct3[1] & Funct3[0]; // and 0000000 111

    // i_l type load 5条
    // I2：LB/LH/LW/LBU/LHU 5
    wire load = ~Op[6] & ~Op[5] & ~Op[4] & ~Op[3] & ~Op[2] & Op[1] & Op[0]; //0000011
    wire i_lb = load & ~Funct3[2] & ~Funct3[1] & ~Funct3[0]; //lb 000
    wire i_lh = load & ~Funct3[2] & ~Funct3[1] & Funct3[0];  //lh 001
    wire i_lw = load & ~Funct3[2] & Funct3[1] & ~Funct3[0];  //lw 010
    wire i_lbu = load & Funct3[2] & ~Funct3[1] & ~Funct3[0]; //lbu 100
    wire i_lhu = load & Funct3[2] & ~Funct3[1] & Funct3[0];  //lhu 101
    
    // i_r type 涉及Reg与imm运算，ALU with immediate 10条
    // I3: ADDI/SLTI/SLTIU/XORI/ORI/ANDI/SLLI/SRLI/SRAI 9
    wire itype_r = ~Op[6] & ~Op[5] & Op[4] & ~Op[3] & ~Op[2] & Op[1] & Op[0]; //0010011
    wire i_addi = itype_r & ~Funct3[2] & ~Funct3[1] & ~Funct3[0]; // addi 000 func3
    wire i_xori = itype_r & Funct3[2] & ~Funct3[1] & ~Funct3[0]; // xori 100 func3
    wire i_ori = itype_r & Funct3[2] & Funct3[1] & ~Funct3[0]; // ori 110 func3
    wire i_andi = itype_r & Funct3[2] & Funct3[1] & Funct3[0]; // andi 111 func3
    wire i_slti = itype_r & ~Funct3[2] & Funct3[1] & ~Funct3[0]; // slti 010 func3
    wire i_sltiu = itype_r & ~Funct3[2] & Funct3[1] & Funct3[0]; // sltiu 011 func3

    wire i_slli = itype_r & ~Funct3[2] & ~Funct3[1] & Funct3[0]; // slli 001
    wire i_srli = itype_r & Funct3[2] & ~Funct3[1] & Funct3[0] & ~Funct7[5]; // srli 101 0000000
    wire i_srai = itype_r & Funct3[2] & ~Funct3[1] & Funct3[0] & Funct7[5]; // srai 101 0100000
    wire itype_shamt = i_slli | i_srli | i_srai;

    // jalr
    wire i_jalr = Op[6] & Op[5] & ~Op[4] & ~Op[3] & Op[2] & Op[1] & Op[0]; //1100111

    // s format store 3条
    // I2: SB/SH/SW 3
    wire store = ~Op[6] & Op[5] & ~Op[4] & ~Op[3] & ~Op[2] & Op[1] & Op[0];//0100011
    wire i_sb = store & ~Funct3[2] & ~Funct3[1] & ~Funct3[0]; // sb 000
    wire i_sh = store & ~Funct3[2] & ~Funct3[1] & Funct3[0];  // sh 001
    wire i_sw = store & ~Funct3[2] & Funct3[1] & ~Funct3[0];  // sw 010

    // B_type 6条
    // I1: BEQ/BNE/BLT/BGE/BLTU/BGEU 6
    wire branch = Op[6] & Op[5] & ~Op[4] & ~Op[3] & ~Op[2] & Op[1] & Op[0]; //1100011
    wire i_beq = branch & ~Funct3[2] & ~Funct3[1] & ~Funct3[0]; // beq 000
    wire i_bne = branch & ~Funct3[2] & ~Funct3[1] & Funct3[0];  // bne 001
    wire i_blt = branch & Funct3[2] & ~Funct3[1] & ~Funct3[0];  // blt 100
    wire i_bge = branch & Funct3[2] & ~Funct3[1] & Funct3[0];   // bge 101
    wire i_bltu = branch & Funct3[2] & Funct3[1] & ~Funct3[0]; // bltu 110
    wire i_bgeu = branch & Funct3[2] & Funct3[1] & Funct3[0];  // bgeu 111

    // J_type 1条
    wire jtype = Op[6] & Op[5] & ~Op[4] & Op[3] & Op[2] & Op[1] & Op[0]; //1101111
    wire i_jal = jtype; // jal 

    // U_type 2条
    // I0: LUI/AUIPC 2 
    wire utype = ~Op[6] & Op[4] & ~Op[3] & Op[2] & Op[1] & Op[0]; //0X10111
    wire i_lui = utype & Op[5]; // lui 0110111
    wire i_auipc = utype & ~Op[5]; // auipc 0010111

    wire is_csr = (Op == 7'b1110011) && (Funct3 != 3'b000);

    assign RegWrite = rtype | itype_r | load | i_jal | i_jalr | i_lui | i_auipc | is_csr; 
    assign MemWrite = store; 

    reg [2:0] EXTOp_reg;
    reg [2:0] BranchOp_reg;
    reg       ALUSrc1_reg;
    reg       ALUSrc2_reg;
    reg [3:0] ALUOp_reg;
    reg [2:0] DMType_reg;
    reg [1:0] MemtoReg_reg;

    assign EXTOp  = EXTOp_reg;
    assign BranchOp = BranchOp_reg;
    assign ALUSrc1 = ALUSrc1_reg;
    assign ALUSrc2 = ALUSrc2_reg;
    assign ALUOp  = ALUOp_reg;
    assign DMType = DMType_reg;
    assign MemtoReg  = MemtoReg_reg;

    always @(*) begin
        
        EXTOp_reg  = `EXT_ITYPE; // 默认 I 型扩展
        BranchOp_reg = `Branch_NONE; // 默认不比较
        ALUSrc1_reg = 1'b0;  // 默认 ALU A来自寄存器
        ALUSrc2_reg = 1'b0; // 默认 ALU B来自寄存器
        ALUOp_reg  = `ALUOp_add; // 默认ALU做加法
        DMType_reg = `DM_WORD; // 默认32位访存
        MemtoReg_reg  = `MemtoReg_ALU; // 默认写回ALU结果
        
        // EXTOp
        if      (itype_shamt) EXTOp_reg = `EXT_SHAMT;
        else if (store)       EXTOp_reg = `EXT_STYPE;
        else if (branch)      EXTOp_reg = `EXT_BTYPE;
        else if (utype)       EXTOp_reg = `EXT_UTYPE;
        else if (jtype)       EXTOp_reg = `EXT_JTYPE;
        // 其余情况（Load, 算术I型, jalr）默认使用 EXT_ITYPE

        // BranchOp
        if (branch) begin
            if (i_beq)  BranchOp_reg = `Branch_BEQ;
            else if (i_bne)  BranchOp_reg = `Branch_BNE;
            else if (i_blt)  BranchOp_reg = `Branch_BLT;
            else if (i_bge)  BranchOp_reg = `Branch_BGE;    
            else if (i_bltu) BranchOp_reg = `Branch_BLTU;
            else if (i_bgeu) BranchOp_reg = `Branch_BGEU;
        end


        // ALUSrc
        if (i_auipc) ALUSrc1_reg = 1'b1;
        if (itype_r | load | store | utype) ALUSrc2_reg = 1'b1;

        // ALUOp
        if      (i_sub)                 ALUOp_reg = `ALUOp_sub;
        else if (i_and | i_andi)        ALUOp_reg = `ALUOp_and;
        else if (i_or  | i_ori)         ALUOp_reg = `ALUOp_or;
        else if (i_xor | i_xori)        ALUOp_reg = `ALUOp_xor;
        else if (i_sll | i_slli)        ALUOp_reg = `ALUOp_sll;
        else if (i_srl | i_srli)        ALUOp_reg = `ALUOp_srl;
        else if (i_sra | i_srai)        ALUOp_reg = `ALUOp_sra;
        else if (i_slt | i_slti)        ALUOp_reg = `ALUOp_slt;
        else if (i_sltu| i_sltiu)       ALUOp_reg = `ALUOp_sltu;
        else if (i_lui)                 ALUOp_reg = `ALUOp_lui;
        else if (i_auipc)               ALUOp_reg = `ALUOp_auipc;
        // 其余默认 ALU_ADD (涵盖了 add, addi, load, store 的地址计算)

        // DMType
        if      (i_lb | i_sb)    DMType_reg = `DM_BYTE;
        else if (i_lh | i_sh)    DMType_reg = `DM_HALF;
        else if (i_lbu)          DMType_reg = `DM_BYTEU;
        else if (i_lhu)          DMType_reg = `DM_HALFU;
        // 其余 lw, sw 默认 DM_WORD

        // MemtoReg
        if      (load)           MemtoReg_reg = `MemtoReg_MEM;
        else if (i_jal | i_jalr) MemtoReg_reg = `MemtoReg_PC4;
        // 其余默认 MemtoReg_ALU
    end

endmodule