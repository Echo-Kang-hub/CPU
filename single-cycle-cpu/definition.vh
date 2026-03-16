`define PR_DATA_WIDTH 100 // pipepline register width

// NPCOp
`define NPC_PLUS4  2'b00
`define NPC_BRANCH 2'b01
`define NPC_JAL   2'b10
`define NPC_JALR   2'b11

// EXTOp
`define EXT_SHAMT  3'b000
`define EXT_ITYPE  3'b001
`define EXT_STYPE  3'b010
`define EXT_BTYPE  3'b011
`define EXT_UTYPE  3'b100
`define EXT_JTYPE  3'b101

// ALUOp: 00xxx算术逻辑, 01xxx移位比较, 10xxx分支
`define ALUOp_add  5'b00000
`define ALUOp_sub  5'b00001
`define ALUOp_and  5'b00010
`define ALUOp_or   5'b00011
`define ALUOp_xor  5'b00100

`define ALUOp_sll  5'b01000
`define ALUOp_srl  5'b01001
`define ALUOp_sra  5'b01010
`define ALUOp_slt  5'b01100
`define ALUOp_sltu 5'b01101

`define ALUOp_beq  5'b10000
`define ALUOp_bne  5'b10001
`define ALUOp_blt  5'b10100
`define ALUOp_bge  5'b10101
`define ALUOp_bltu 5'b10110
`define ALUOp_bgeu 5'b10111

// DMType
`define DM_WORD    3'b000 // lw, sw
`define DM_HALF    3'b001 // lh, sh
`define DM_HALFU   3'b010 // lhu
`define DM_BYTE    3'b011 // lb, sb
`define DM_BYTEU   3'b100 // lbu

// WDSel
`define WD_ALU     3'b000
`define WD_MEM     3'b001 // load
`define WD_PC4     3'b010 // jal, jalr
`define WD_IMM     3'b011 // lui
`define WD_PCIMM   3'b100 // auipc
