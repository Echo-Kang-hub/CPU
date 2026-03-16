`define PR_DATA_WIDTH 100 // pipepline register width

// IF 到 ID 传 64 位 (32位PC + 32位指令)
`define IF_TO_ID_WD  64  

// ID 到 EX 假设传 150 位
// 包含: PC(32), rs1数据(32), rs2数据(32), imm(32), ALUOp(5), 各种控制信号(17)
`define ID_TO_EX_WD  150 

// 以此类推...
`define EX_TO_MA_WD 100
`define MA_TO_WB_WD 70