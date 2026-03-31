// IF/ID, ID/EX, EX/MA, MA/WB 流水线寄存器宽度
`define IF_to_ID_BUS_WIDTH  64  
`define ID_to_EX_BUS_WIDTH  233 
`define EX_to_MA_BUS_WIDTH 153
`define MA_to_WB_BUS_WIDTH 104

// EXTOp
`define EXT_SHAMT  3'b000
`define EXT_ITYPE  3'b001
`define EXT_STYPE  3'b010
`define EXT_BTYPE  3'b011
`define EXT_UTYPE  3'b100
`define EXT_JTYPE  3'b101

// BranchOp
`define Branch_NONE 3'b000
`define Branch_BEQ  3'b001
`define Branch_BNE  3'b010
`define Branch_BLT  3'b011
`define Branch_BGE  3'b100
`define Branch_BLTU 3'b101
`define Branch_BGEU 3'b110

// ALUOp: 0xxx算术逻辑, 1xxx移位比较
`define ALUOp_add  4'b0000
`define ALUOp_sub  4'b0001
`define ALUOp_and  4'b0010
`define ALUOp_or   4'b0011
`define ALUOp_xor  4'b0100
`define ALUOp_lui  4'b0101
`define ALUOp_auipc 4'b0110

`define ALUOp_sll  4'b1000
`define ALUOp_srl  4'b1001
`define ALUOp_sra  4'b1010
`define ALUOp_slt  4'b1100
`define ALUOp_sltu 4'b1101



// DMType
`define DM_WORD    3'b000 // lw, sw
`define DM_HALF    3'b001 // lh, sh
`define DM_HALFU   3'b010 // lhu
`define DM_BYTE    3'b011 // lb, sb
`define DM_BYTEU   3'b100 // lbu

// MemtoReg
`define MemtoReg_ALU     2'b00 // auipc, lui, R-type, I-type (except load)
`define MemtoReg_MEM     2'b01 // load
`define MemtoReg_PC4     2'b10 // jal, jalr

// Forwarding
`define Forward_NONE 2'b00
`define Forward_EXMA 2'b01
`define Forward_MAWB 2'b10

// mstatus csr
`define MSTATUS_MIE 3 // Machine Interrupt Enable
`define MSTATUS_MPIE 7 // Machine Previous Interrupt Enable

// mie csr: machine interrupt enable
`define MIE_MEIE 11 // external interrupt
`define MIE_MTIE 7 // timer interrupt
`define MIE_MSIE 3 // software interrupt

// mip csr: machine interrupt pending
`define MIP_MEIP 11 // external interrupt pending
`define MIP_MTIP 7 // timer interrupt pending
`define MIP_MSIP 3 // software interrupt pending

// mcause
`define CAUSE_EXTERNAL 11 // external interrupt
`define CAUSE_TIMER    7  // timer interrupt
`define CAUSE_SOFTWARE 3  // software interrupt

// CSR addresses
`define CSR_MSTATUS 12'h300
`define CSR_MIE     12'h304
`define CSR_MIP     12'h344
`define CSR_MEPC    12'h341
`define CSR_MCAUSE  12'h342

// MTVEC
`define MTVEC_BASE  32'h0000_0100

// csrType (funct3)
`define CSRType_RW 3'b001
`define CSRType_RS 3'b010
`define CSRType_RC 3'b011