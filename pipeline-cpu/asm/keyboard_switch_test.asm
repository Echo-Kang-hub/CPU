# keyboard_switch_test.asm
# 使用开关模拟键盘输入
# sw[7:0] = 扫描码
# 按下btnc（中心按钮）= 确认输入

.text
.globl _start

_start:
    # SWITCH = 0xFFFF0004
    lui  x9, 0xFFFFF
    addi x9, x9, 0x004
    
    # VGA_BASE = 0xFFFF0020
    lui  x11, 0xFFFFF
    addi x11, x11, 0x020
    
    # VGA位置
    addi x12, x0, 0
    
    # 上一次的开关值
    addi x13, x0, 0
    
    # 转换表基地址 (从0x100复制到0x00已经在初始化完成)
    addi x14, x0, 0

poll:
    # 读取开关值
    lw   x8, 0(x9)
    andi x8, x8, 0xFF       # 只取低8位
    
    # 检查是否有变化
    beq  x8, x13, poll      # 如果没变化，继续轮询
    
    # 有变化，更新上次值
    add  x13, x8, x0
    
    # 检查是否为0（开关全关）
    beq  x8, x0, poll
    
    # 查表转换为ASCII
    add  x15, x14, x8       # 转换表基地址 + 扫描码
    lbu  x16, 0(x15)        # 读取ASCII码
    
    # 检查是否为0（未定义的扫描码）
    beq  x16, x0, poll
    
    # 写入VGA
    add  x17, x11, x12
    sb   x16, 0(x17)
    
    # 更新位置
    addi x12, x12, 1
    
    # 简单延时（防抖）
    addi x18, x0, 100
delay:
    addi x18, x18, -1
    bne  x18, x0, delay
    
    j    poll
