# keyboard_vga_test.asm
# 键盘输入 → VGA显示测试程序
# 功能：读取键盘扫描码，转换为ASCII，写入VGA显示

# I/O地址定义
# KBD_STATUS = 0xffff0014 (键盘状态寄存器，bit0: 1=有按键)
# KBD_DATA   = 0xffff0010 (键盘数据寄存器，存储扫描码)
# VGA_BASE   = 0xffff0020 (VGA字符内存基地址)

# 寄存器分配
# x5  - KBD_STATUS地址
# x6  - KBD_DATA地址  
# x7  - VGA基地址
# x8  - 临时寄存器
# x9  - VGA显示位置偏移(字符位置)
# x10 - VGA写入地址
# x11 - ASCII码(从转换表读取)
# x12 - 转换表基地址(数据内存地址0x00)
# x13 - 转换表索引地址

main:
    # ========== 初始化I/O地址 ==========
    # 加载KBD_STATUS地址 0xffff0014
    lui  x5, 0xfffff        # x5 = 0xfffff000
    addi x5, x5, 0x014      # x5 = 0xffff0014 (KBD_STATUS)
    nop
    nop
    nop
    
    # 加载KBD_DATA地址 0xffff0010
    lui  x6, 0xfffff        # x6 = 0xfffff000
    addi x6, x6, 0x010      # x6 = 0xffff0010 (KBD_DATA)
    nop
    nop
    nop
    
    # 加载VGA基地址 0xffff0020
    lui  x7, 0xfffff        # x7 = 0xfffff000
    addi x7, x7, 0x020      # x7 = 0xffff0020 (VGA_BASE)
    nop
    nop
    nop
    
    # 初始化显示位置偏移
    addi x9, x0, 0          # x9 = 0 (从VGA位置0开始显示)
    nop
    nop
    
    # 初始化转换表基地址(数据内存地址0x00)
    addi x12, x0, 0         # x12 = 0 (转换表在dmem[0])
    nop
    nop

# ========== 主循环：轮询键盘 ==========
poll_loop:
    # 读取键盘状态
    lw   x8, 0(x5)          # x8 = KBD_STATUS
    nop
    nop
    nop
    
    # 检查是否有按键(bit0 = 1)
    andi x8, x8, 0x001      # 取bit0
    nop
    nop
    nop
    
    beq  x8, x0, poll_loop  # 如果没有按键，继续轮询
    nop
    nop
    nop

    # ========== 读取键盘扫描码 ==========
    lw   x8, 0(x6)          # x8 = 扫描码
    nop
    nop
    nop

    # ========== 扫描码 → ASCII 转换 ==========
    # 使用转换表查找：ASCII = dmem[扫描码]
    add  x13, x12, x8       # x13 = 转换表基地址 + 扫描码偏移
    nop
    nop
    nop
    
    lbu  x11, 0(x13)        # x11 = 从转换表读取ASCII码(无符号字节加载)
    nop
    nop
    nop

    # ========== 写入VGA显示 ==========
    # 计算VGA写入地址 = VGA_BASE + 显示位置偏移
    add  x10, x7, x9        # x10 = VGA基地址 + 位置偏移
    nop
    nop
    nop
    
    sb   x11, 0(x10)        # 将ASCII码写入VGA字符内存
    nop
    nop
    nop

    # ========== 更新显示位置 ==========
    addi x9, x9, 1          # 位置偏移 + 1 (下一个字符位置)
    nop
    nop
    nop

    # 返回主循环
    jal  x0, poll_loop      # 跳转到poll_loop
    nop
    nop
    nop

# ========== 机器码 ==========
# 地址    指令          机器码        说明
# 0x00: lui x5, 0xfffff          ; 0xFFFFF2B7  x5 = 0xfffff000
# 0x04: addi x5, x5, 0x014       ; 0x01428293  x5 = 0xffff0014 (KBD_STATUS)
# 0x08: nop                      ; 0x00000013
# 0x0C: nop                      ; 0x00000013
# 0x10: nop                      ; 0x00000013
# 0x14: lui x6, 0xfffff          ; 0xFFFFF337  x6 = 0xfffff000
# 0x18: addi x6, x6, 0x010       ; 0x01030313  x6 = 0xffff0010 (KBD_DATA)
# 0x1C: nop                      ; 0x00000013
# 0x20: nop                      ; 0x00000013
# 0x24: nop                      ; 0x00000013
# 0x28: lui x7, 0xfffff          ; 0xFFFFF3B7  x7 = 0xfffff000
# 0x2C: addi x7, x7, 0x020       ; 0x02038393  x7 = 0xffff0020 (VGA_BASE)
# 0x30: nop                      ; 0x00000013
# 0x34: nop                      ; 0x00000013
# 0x38: nop                      ; 0x00000013
# 0x3C: addi x9, x0, 0           ; 0x00000493  x9 = 0 (显示位置)
# 0x40: nop                      ; 0x00000013
# 0x44: nop                      ; 0x00000013
# 0x48: addi x12, x0, 0          ; 0x00000613  x12 = 0 (转换表基地址)
# 0x4C: nop                      ; 0x00000013
# 0x50: nop                      ; 0x00000013
# --- poll_loop: ---
# 0x54: lw x8, 0(x5)             ; 0x0002A403  x8 = [KBD_STATUS]
# 0x58: nop                      ; 0x00000013
# 0x5C: nop                      ; 0x00000013
# 0x60: nop                      ; 0x00000013
# 0x64: andi x8, x8, 1           ; 0x00147413  x8 = x8 & 1
# 0x68: nop                      ; 0x00000013
# 0x6C: nop                      ; 0x00000013
# 0x70: nop                      ; 0x00000013
# 0x74: beq x8, x0, -20          ; 0xFE040AE3  if(x8==0) goto poll_loop (PC-20)
# 0x78: nop                      ; 0x00000013
# 0x7C: nop                      ; 0x00000013
# 0x80: nop                      ; 0x00000013
# 0x84: lw x8, 0(x6)             ; 0x00032403  x8 = [KBD_DATA] (扫描码)
# 0x88: nop                      ; 0x00000013
# 0x8C: nop                      ; 0x00000013
# 0x90: nop                      ; 0x00000013
# 0x94: add x13, x12, x8         ; 0x008606B3  x13 = 转换表基地址 + 扫描码
# 0x98: nop                      ; 0x00000013
# 0x9C: nop                      ; 0x00000013
# 0xA0: nop                      ; 0x00000013
# 0xA4: lbu x11, 0(x13)          ; 0x0006C583  x11 = [x13] (ASCII码)
# 0xA8: nop                      ; 0x00000013
# 0xAC: nop                      ; 0x00000013
# 0xB0: nop                      ; 0x00000013
# 0xB4: add x10, x7, x9          ; 0x00938533  x10 = VGA基地址 + 位置偏移
# 0xB8: nop                      ; 0x00000013
# 0xBC: nop                      ; 0x00000013
# 0xC0: nop                      ; 0x00000013
# 0xC4: sb x11, 0(x10)           ; 0x00B50023  [x10] = x11 (写入VGA)
# 0xC8: nop                      ; 0x00000013
# 0xCC: nop                      ; 0x00000013
# 0xD0: nop                      ; 0x00000013
# 0xD4: addi x9, x9, 1           ; 0x00148493  x9 = x9 + 1 (下一个位置)
# 0xD8: nop                      ; 0x00000013
# 0xDC: nop                      ; 0x00000013
# 0xE0: nop                      ; 0x00000013
# 0xE4: jal x0, -0x90            ; 0xF6DFF06F  goto poll_loop (PC-144)
# 0xE8: nop                      ; 0x00000013
# 0xEC: nop                      ; 0x00000013
# 0xF0: nop                      ; 0x00000013
