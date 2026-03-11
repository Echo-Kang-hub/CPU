module ctrl(
    input [6:0] Op,
    input [6:0] Funct7,
    input [2:0] Funct3,
    input Zero,
    output RegWrite,
    output MemWrite,
    output [5:0] EXTOp,
    output reg [4:0] ALUOp,
    output [2:0] NPCOp,
    output ALUSrc,
    output ALUSrcA,  // A端来源：0=RD1, 1=PC（用于auipc）
    output [2:0] DMType,
    output [1:0] WDSel // MemtoReg: 00=aluout 01=mem 10=PC+4 11=imm(lui)
);
// R_type 10条
wire rtype = ~Op[6] & Op[5] & Op[4] & ~Op[3] & ~Op[2] & Op[1] & Op[0]; //0110011
wire i_add  = rtype & ~Funct3[2] & ~Funct3[1] & ~Funct3[0] & ~Funct7[5]; // add 0000000 000
wire i_sub  = rtype & ~Funct3[2] & ~Funct3[1] & ~Funct3[0] &  Funct7[5]; // sub 0100000 000
wire i_sll  = rtype & ~Funct3[2] & ~Funct3[1] &  Funct3[0];               // sll 0000000 001
wire i_slt  = rtype & ~Funct3[2] &  Funct3[1] & ~Funct3[0];               // slt 0000000 010
wire i_sltu = rtype & ~Funct3[2] &  Funct3[1] &  Funct3[0];               // sltu 0000000 011
wire i_xor  = rtype &  Funct3[2] & ~Funct3[1] & ~Funct3[0];               // xor 0000000 100
wire i_srl  = rtype &  Funct3[2] & ~Funct3[1] &  Funct3[0] & ~Funct7[5]; // srl 0000000 101
wire i_sra  = rtype &  Funct3[2] & ~Funct3[1] &  Funct3[0] &  Funct7[5]; // sra 0100000 101
wire i_or   = rtype &  Funct3[2] &  Funct3[1] & ~Funct3[0];               // or  0000000 110
wire i_and  = rtype &  Funct3[2] &  Funct3[1] &  Funct3[0];               // and 0000000 111

// i_l type load 5条
wire itype_l = ~Op[6] & ~Op[5] & ~Op[4] & ~Op[3] & ~Op[2] & Op[1] & Op[0]; //0000011
wire i_lb    = itype_l & ~Funct3[2] & ~Funct3[1] & ~Funct3[0]; //lb  000
wire i_lh    = itype_l & ~Funct3[2] & ~Funct3[1] &  Funct3[0]; //lh  001
wire i_lw    = itype_l & ~Funct3[2] &  Funct3[1] & ~Funct3[0]; //lw  010
wire i_lbu   = itype_l &  Funct3[2] & ~Funct3[1] & ~Funct3[0]; //lbu 100
wire i_lhu   = itype_l &  Funct3[2] & ~Funct3[1] &  Funct3[0]; //lhu 101

// i_r type：寄存器与立即数运算 10条
wire itype_r  = ~Op[6] & ~Op[5] & Op[4] & ~Op[3] & ~Op[2] & Op[1] & Op[0]; //0010011
wire i_addi  = itype_r & ~Funct3[2] & ~Funct3[1] & ~Funct3[0]; // addi  000
wire i_slti  = itype_r & ~Funct3[2] &  Funct3[1] & ~Funct3[0]; // slti  010
wire i_sltiu = itype_r & ~Funct3[2] &  Funct3[1] &  Funct3[0]; // sltiu 011
wire i_xori  = itype_r &  Funct3[2] & ~Funct3[1] & ~Funct3[0]; // xori  100
wire i_ori   = itype_r &  Funct3[2] &  Funct3[1] & ~Funct3[0]; // ori   110
wire i_andi  = itype_r &  Funct3[2] &  Funct3[1] &  Funct3[0]; // andi  111
wire i_slli  = itype_r & ~Funct3[2] & ~Funct3[1] &  Funct3[0];                // slli 001
wire i_srli  = itype_r &  Funct3[2] & ~Funct3[1] &  Funct3[0] & ~Funct7[5];  // srli 101 0000000
wire i_srai  = itype_r &  Funct3[2] & ~Funct3[1] &  Funct3[0] &  Funct7[5];  // srai 101 0100000
wire itype_shamt = i_slli | i_srli | i_srai;

// jalr
wire i_jalr = Op[6] & Op[5] & ~Op[4] & ~Op[3] & Op[2] & Op[1] & Op[0]; //1100111

// s format store 3条
wire stype = ~Op[6] & Op[5] & ~Op[4] & ~Op[3] & ~Op[2] & Op[1] & Op[0]; //0100011
wire i_sb   = stype & ~Funct3[2] & ~Funct3[1] & ~Funct3[0]; // sb 000
wire i_sh   = stype & ~Funct3[2] & ~Funct3[1] &  Funct3[0]; // sh 001
wire i_sw   = stype & ~Funct3[2] &  Funct3[1] & ~Funct3[0]; // sw 010

// B_type 6条
wire btype  = Op[6] & Op[5] & ~Op[4] & ~Op[3] & ~Op[2] & Op[1] & Op[0]; //1100011
wire i_beq  = btype & ~Funct3[2] & ~Funct3[1] & ~Funct3[0]; // beq 000
wire i_bne  = btype & ~Funct3[2] & ~Funct3[1] &  Funct3[0]; // bne 001
wire i_blt  = btype &  Funct3[2] & ~Funct3[1] & ~Funct3[0]; // blt 100
wire i_bge  = btype &  Funct3[2] & ~Funct3[1] &  Funct3[0]; // bge 101
wire i_bltu = btype &  Funct3[2] &  Funct3[1] & ~Funct3[0]; // bltu 110
wire i_bgeu = btype &  Funct3[2] &  Funct3[1] &  Funct3[0]; // bgeu 111

// J_type
wire jtype = Op[6] & Op[5] & ~Op[4] & Op[3] & Op[2] & Op[1] & Op[0]; //1101111
wire i_jal = jtype;

// U_type
wire utype    = ~Op[6] & Op[4] & ~Op[3] & Op[2] & Op[1] & Op[0]; //0X10111
wire i_lui    = utype &  Op[5]; // lui   0110111
wire i_auipc  = utype & ~Op[5]; // auipc 0010111

// ---- RegWrite / MemWrite ----
assign RegWrite = rtype | itype_r | itype_l | i_jal | i_jalr | i_lui | i_auipc;
assign MemWrite = stype;


// ---- ALUOp（用always块保证覆盖所有指令）----
// 编码与alu.v中define一致：
// add=00011 sub=00110 sll=00001 srl=00010 sra=00101
// and=01111 or=01011 xor=01001 slt=00111 sltu=01010
// beq=00100 bne=01000 blt=01100 bge=10000 bltu=10100 bgeu=11000
always @(*) begin
    if      (i_add | i_addi | itype_l | stype | i_jalr)  ALUOp = 5'b00011; // add
    else if (i_sub)                                        ALUOp = 5'b00110; // sub
    else if (i_sll | i_slli)                               ALUOp = 5'b00001; // sll
    else if (i_srl | i_srli)                               ALUOp = 5'b00010; // srl
    else if (i_sra | i_srai)                               ALUOp = 5'b00101; // sra
    else if (i_and | i_andi)                               ALUOp = 5'b01111; // and
    else if (i_or  | i_ori)                                ALUOp = 5'b01011; // or
    else if (i_xor | i_xori)                               ALUOp = 5'b01001; // xor
    else if (i_slt | i_slti)                               ALUOp = 5'b00111; // slt
    else if (i_sltu | i_sltiu)                             ALUOp = 5'b01010; // sltu
    else if (i_auipc)                                      ALUOp = 5'b00011; // auipc: PC+imm
    else if (i_beq)                                        ALUOp = 5'b00100;
    else if (i_bne)                                        ALUOp = 5'b01000;
    else if (i_blt)                                        ALUOp = 5'b01100;
    else if (i_bge)                                        ALUOp = 5'b10000;
    else if (i_bltu)                                       ALUOp = 5'b10100;
    else if (i_bgeu)                                       ALUOp = 5'b11000;
    else                                                   ALUOp = 5'b00000; // nop
end

// ---- NPCOp ----
// 000=PC+4, 001=branch(taken), 010=jal, 100=jalr
assign NPCOp[0] = btype & Zero; // 分支条件成立（Zero由ALU根据分支类型计算）
assign NPCOp[1] = i_jal;
assign NPCOp[2] = i_jalr;

// ---- ALUSrc / ALUSrcA ----
assign ALUSrc  = itype_r | itype_l | stype | i_jalr | i_lui | i_auipc; // B来自立即数
assign ALUSrcA = i_auipc; // A来自PC（auipc: PC + uimm<<12）

// ---- WDSel ----
// 00=aluout, 01=mem(load), 10=PC+4(jal/jalr), 11=immout(lui)
assign WDSel[0] = itype_l | i_lui;
assign WDSel[1] = i_jal | i_jalr | i_lui;

// ---- DMType ----
// [1:0]: 00=byte, 01=halfword, 10=word
// [2]:   0=有符号, 1=无符号（lbu/lhu）
assign DMType[0] = i_lh | i_lhu | i_sh;  // halfword
assign DMType[1] = i_lw | i_sw;           // word
assign DMType[2] = i_lbu | i_lhu;         // unsigned

endmodule