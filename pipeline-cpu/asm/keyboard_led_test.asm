# keyboard_led_test.asm
# 简单测试：按键时在LED显示扫描码
# 使用开关sw[0]选择显示模式

.text
.globl _start

_start:
    # KBD_STATUS = 0xFFFF0014
    lui  x9, 0xFFFFF
    addi x9, x9, 0x014
    
    # KBD_DATA = 0xFFFF0010
    lui  x10, 0xFFFFF
    addi x10, x10, 0x010
    
    # SEG7 = 0xFFFF000C
    lui  x11, 0xFFFFF
    addi x11, x11, 0x00C
    
    # 保存上次的按键码
    addi x12, x0, 0

poll:
    # 读键盘状态
    lw   x8, 0(x9)
    andi x8, x8, 1
    beq  x8, x0, poll
    
    # 读按键码
    lw   x12, 0(x10)
    
    # 显示在七段显示器上
    sw   x12, 0(x11)
    
    j    poll
