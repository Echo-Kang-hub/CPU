module ctrl(
    input [6:0] Op,
    input [6:0] Funct7,
    input [2:0] Funct3,
    input Zero,
    output RegWrite,
    output MemWrite,
    output [5:0] EXTOp,
    output [4:0] ALUOp,
    output [2:0] NPCOp,
    output ALUSrc,
    output [2:0] DMType,
    output [1:0] WDSel // MemtoReg
);
// R_type 10条
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
wire itype_l = ~Op[6] & ~Op[5] & ~Op[4] & ~Op[3] & ~Op[2] & Op[1] & Op[0]; //0000011
wire i_lb = itype_l & ~Funct3[2] & ~Funct3[1] & ~Funct3[0]; //lb 000
wire i_lh = itype_l & ~Funct3[2] & ~Funct3[1] & Funct3[0];  //lh 001
wire i_lw = itype_l & ~Funct3[2] & Funct3[1] & ~Funct3[0];  //lw 010
wire i_lbu = itype_l & Funct3[2] & ~Funct3[1] & ~Funct3[0]; //lbu 100
wire i_lhu = itype_l & Funct3[2] & ~Funct3[1] & Funct3[0];  //lh 101
 
 // i_r type 涉及Reg与imm运算，ALU with immediate 10条
wire itype_r = ~Op[6] & ~Op[5] & Op[4] & ~Op[3] & ~Op[2] & Op[1] & Op[0]; //0010011
wire i_addi = itype_r & ~Funct3[2] & ~Funct3[1] & ~Funct3[0]; // addi 000 func3
wire i_slti = itype_r & ~Funct3[2] & Funct3[1] & ~Funct3[0]; // slti 010 func3
wire i_sltiu = itype_r & ~Funct3[2] & Funct3[1] & Funct3[0]; // sltiu 011 func3

wire i_slli = itype_r & ~Funct3[2] & ~Funct3[1] & Funct3[0]; // slli 001
wire i_srli = itype_r & Funct3[2] & ~Funct3[1] & Funct3[0] & ~Funct7[5]; // srli 101 0000000
wire i_srai = itype_r & Funct3[2] & ~Funct3[1] & Funct3[0] & Funct7[5]; // srai 101 0100000
wire itype_shamt = i_slli | i_srli | i_srai;

// jalr
wire i_jalr = Op[6] & Op[5] & ~Op[4] & ~Op[3] & Op[2] & Op[1] & Op[0]; //1100111

// s format store 3条
wire stype = ~Op[6] & Op[5] & ~Op[4] & ~Op[3] & ~Op[2] & Op[1] & Op[0];//0100011
wire i_sb = stype & ~Funct3[2] & ~Funct3[1] & ~Funct3[0]; // sb 000
wire i_sh = stype & ~Funct3[2] & ~Funct3[1] & Funct3[0];  // sh 001
wire i_sw = stype & ~Funct3[2] & Funct3[1] & ~Funct3[0];  // sw 010

// B_type 6条
wire btype = Op[6] & Op[5] & ~Op[4] & ~Op[3] & ~Op[2] & Op[1] & Op[0]; //1100011
wire i_beq = btype & ~Funct3[2] & ~Funct3[1] & ~Funct3[0]; // beq 000
wire i_bne = btype & ~Funct3[2] & ~Funct3[1] & Funct3[0];  // bne 001
wire i_blt = btype & Funct3[2] & ~Funct3[1] & ~Funct3[0];  // blt 100
wire i_bge = btype & Funct3[2] & ~Funct3[1] & Funct3[0];   // bge 101
wire i_bltu = btype & Funct3[2] & Funct3[1] & ~Funct3[0]; // bltu 110
wire i_bgeu = btype & Funct3[2] & Funct3[1] & Funct3[0];  // bgeu 111

// J_type 1条
wire jtype = Op[6] & Op[5] & ~Op[4] & Op[3] & Op[2] & Op[1] & Op[0]; //1101111
wire i_jal = jtype; // jal 

// U_type 2条
wire utype = ~Op[6] & Op[4] & ~Op[3] & Op[2] & Op[1] & Op[0]; //0X10111
wire i_lui = utype & Op[5]; // lui 0110111
wire i_auipc = utype & ~Op[5]; // auipc 0010111


assign RegWrite = rtype | itype_r | itype_l | i_jal | i_jalr; // register write (含跳转返回地址)
assign MemWrite = stype; // memory write

//`define EXT_CTRL_ITYPE_SHAMT 6'b100000
//`define EXT_CTRL_ITYPE 6'b010000
//`define EXT_CTRL_STYPE 6'b001000
//`define EXT_CTRL_BTYPE 6'b000100
//`define EXT_CTRL_UTYPE 6'b000010
//`define EXT_CTRL_JTYPE 6'b000001
assign EXTOp[5] = itype_shamt;
assign EXTOp[4] = itype_l | (itype_r & ~itype_shamt) | i_jalr;
assign EXTOp[3] = stype;
assign EXTOp[2] = btype;
assign EXTOp[1] = i_lui | i_auipc;
assign EXTOp[0] = i_jal;


//`define ALUOp_nop 5'b00000

//`define ALUOp_sll 5'b00001
//`define ALUOp_srl 5'b00010
//`define ALUOp_sra 5'b00101

//`define ALUOp_add 5'b00011

//`define ALUOp_beq 5'b00100
//`define ALUOp_bne 5'b01000
//`define ALUOp_blt 5'b01100
//`define ALUOp_bge 5'b10000
//`define ALUOp_bltu 5'b10100
//`define ALUOp_bgeu 5'b11000
assign ALUOp[0] = i_add | i_addi | stype | itype_l | i_jalr | i_sll | i_sra | i_slli | i_srai;
assign ALUOp[1] = i_add | i_addi | stype | itype_l | i_jalr | i_srl | i_srli;
assign ALUOp[2] = i_beq | i_blt | i_bltu | i_sra | i_srai;
assign ALUOp[3] = i_bne | i_blt | i_bgeu;
assign ALUOp[4] = i_bge | i_bltu | i_bgeu;


//`define NPC_PLUS4 3'b000
//`define NPC_BRANCH 3'b001
//`define NPC_JUMP 3'b010
//`define NPC_JALR 3'b100
assign NPCOp[0] = btype & Zero;
assign NPCOp[1] = i_jal;
assign NPCOp[2] = i_jalr;


assign ALUSrc = itype_r | itype_l | stype | i_jal | i_jalr; // ALU B is from instruction immediate

// ALU_DM->RF RF_WD
// WDSel FromALU 2'b00
// WDSel FromMEM 2'b01
// WDSel FromPC 2'b10
assign WDSel[0] = itype_l;
assign WDSel[1] = i_jal | i_jalr;


// dm_word 3'b000
// dm_halfword 3'b001
// dm_halfword_unsigned 3'b010
// dm_byte 3'b011
// dm_byte_unsigned 3'b100
assign DMType[2] = i_lbu; // bu
assign DMType[1] = i_lb | i_sb | i_lhu; // hu和b
assign DMType[0] = i_lh | i_sh | i_lb | i_sb; // h和b

endmodule