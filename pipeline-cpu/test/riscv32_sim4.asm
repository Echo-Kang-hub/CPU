# Test the RISC-V processor in simulation
# 已经能正确执行：lui, addi
# 待验证：slt, sltu, slti, sltiu
# 本测试只验证单条指令的功能，不考察转发和冒险检测的功能，所以在相关指令之间添加了足够多的nop指令

#		Assembly                Description
main:   lui     x5, 0xfffff             #x5 <== 0xFFFFF000
        lui     x6, 0xffffe             #x6 <== 0xFFFFE000
        addi    x0, x0, 0
        addi    x0, x0, 0 
        addi    x0, x0, 0
        addi    x0, x0, 0

        slt     x7, x5, x6              #x7 <== 0x00000000
        slti    x8, x5, 1               #x8 <== 0x00000001
        
        sltu    x9, x5, x6              #x9 <== 0x00000000
        sltiu   x10, x5, -2048          #x10 <== 0x00000001
        sltiu   x11, x5, 1              #x11 <== 0x00000000


0xFFFFF2B7
0xFFFFE337
0x00000013
0x00000013
0x00000013
0x00000013
0x0062A3B3
0x0012A413
0x0062B4B3
0x8002B513
0x0012B593


FFFFF2B7
FFFFE337
00000013
00000013
00000013
00000013
0062A3B3
0012A413
0062B4B3
8002B513
0012B593