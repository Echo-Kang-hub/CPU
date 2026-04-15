# RISC-V 汇编贪吃蛇
# 硬件连接：VGA @ 0x80000000, 键盘 @ 0x80001000

    .data
    .align 2

# 游戏状态变量
snake_x:    .word   0:100       # 蛇身 X 坐标数组 (最大长度100)
snake_y:    .word   0:100       # 蛇身 Y 坐标数组
snake_len:  .word   3            # 当前蛇长
dir:        .word   3            # 当前方向: 0=上, 1=下, 2=左, 3=右
food_x:     .word   0            # 食物 X
food_y:     .word   0            # 食物 Y
rand_seed:  .word   0x12345678  # 随机数种子

    .text
    .globl _start

# ---------------- 常量定义 ----------------
.equ VGA_BASE,       0x80000000
.equ KBD_DATA,       0x80001000
.equ KBD_CTRL,       0x80001004

.equ CHAR_EMPTY,     0x20         # 空格
.equ CHAR_SNAKE,     0x4F         # 字母 'O'
.equ CHAR_FOOD,      0x46         # 字母 'F'
.equ CHAR_WALL,      0x2A         # 星号 '*'

# ---------------- 主程序入口 ----------------
_start:
    jal     init_game               # 初始化游戏
main_loop:
    jal     read_kbd                # 读取键盘并改变方向
    jal     move_snake              # 移动蛇身
    jal     check_collision         # 检测碰撞
    jal     draw_game               # 绘制画面
    jal     delay                   # 延时控制速度
    j       main_loop               # 无限循环

# ---------------- 1. 初始化游戏 ----------------
init_game:
    # 1.1 清屏
    li      t0, VGA_BASE
    li      t1, 2400
    li      t2, CHAR_EMPTY
init_cls_loop:
    sb      t2, 0(t0)
    addi    t0, t0, 1
    addi    t1, t1, -1
    bne     t1, zero, init_cls_loop

    # 1.2 画边框 (可选，增加视觉效果)
    li      t0, VGA_BASE
    li      t1, 0                   # Y=0
init_wall_top:
    li      t2, CHAR_WALL
    sb      t2, 0(t0)
    addi    t0, t0, 1
    addi    t1, t1, 1
    li      t2, 80
    blt     t1, t2, init_wall_top

    # (为了代码简洁，此处省略左右下边框，可自行补充)

    # 1.3 初始化蛇 (初始位置: (40,15), (39,15), (38,15))
    la      t0, snake_x
    li      t1, 40
    sw      t1, 0(t0)
    li      t1, 39
    sw      t1, 4(t0)
    li      t1, 38
    sw      t1, 8(t0)
    
    la      t0, snake_y
    li      t1, 15
    sw      t1, 0(t0)
    sw      t1, 4(t0)
    sw      t1, 8(t0)

    li      t0, 3
    la      t1, snake_len
    sw      t0, 0(t1)

    # 1.4 生成第一个食物
    jal     gen_food
    ret

# ---------------- 2. 读取键盘 (WASD) ----------------
read_kbd:
    li      t0, KBD_DATA
    lb      t1, 0(t0)               # 读取扫描码
    
    li      t0, KBD_CTRL             # 清除就绪信号
    li      t2, 1
    sb      t2, 0(t0)

    # 解析按键 (W=0x1C, A=0x1E, S=0x1B, D=0x23)
    la      t2, dir
    lw      t3, 0(t2)               # 当前方向
    
    li      t4, 0x1C                # W: 上
    beq     t1, t4, set_up
    li      t4, 0x1B                # S: 下
    beq     t1, t4, set_down
    li      t4, 0x1E                # A: 左
    beq     t1, t4, set_left
    li      t4, 0x23                # D: 右
    beq     t1, t4, set_right
    ret                             # 没按键则返回

set_up:
    li      t4, 1                   # 不能反向 (当前是下则忽略)
    beq     t3, t4, rk_end
    li      t4, 0
    sw      t4, 0(t2)
    j       rk_end
set_down:
    li      t4, 0
    beq     t3, t4, rk_end
    li      t4, 1
    sw      t4, 0(t2)
    j       rk_end
set_left:
    li      t4, 3
    beq     t3, t4, rk_end
    li      t4, 2
    sw      t4, 0(t2)
    j       rk_end
set_right:
    li      t4, 2
    beq     t3, t4, rk_end
    li      t4, 3
    sw      t4, 0(t2)
rk_end:
    ret

# ---------------- 3. 移动蛇身 ----------------
move_snake:
    # 3.1 计算新头坐标
    la      t0, snake_x
    lw      t1, 0(t0)               # 旧头 X
    la      t2, snake_y
    lw      t3, 0(t2)               # 旧头 Y
    la      t4, dir
    lw      t5, 0(t4)               # 方向

    li      t6, 0
    beq     t5, t6, ms_up
    li      t6, 1
    beq     t5, t6, ms_down
    li      t6, 2
    beq     t5, t6, ms_left
    li      t6, 3
    beq     t5, t6, ms_right
ms_up:
    addi    t3, t3, -1
    j       ms_new_head_done
ms_down:
    addi    t3, t3, 1
    j       ms_new_head_done
ms_left:
    addi    t1, t1, -1
    j       ms_new_head_done
ms_right:
    addi    t1, t1, 1
ms_new_head_done:

    # 3.2 检查是否吃到食物
    la      t0, food_x
    lw      t2, 0(t0)
    la      t3, food_y
    lw      t4, 0(t3)
    bne     t1, t2, ms_no_food      # X 不等
    bne     t3, t4, ms_no_food      # Y 不等
    # 吃到食物：长度+1，不删尾巴，生成新食物
    la      t0, snake_len
    lw      t5, 0(t0)
    addi    t5, t5, 1
    sw      t5, 0(t0)
    jal     gen_food
    j       ms_move_body
ms_no_food:
    # 没吃到：什么都不做，后面移动时会自然覆盖尾巴

ms_move_body:
    # 3.3 从后往前移动身体 (i = len-1 downto 1)
    la      t0, snake_len
    lw      t1, 0(t0)
    addi    t1, t1, -1              # i = len - 1
ms_loop:
    beq     t1, zero, ms_update_head # 到 i=0 停止
    # X[i] = X[i-1]
    la      t2, snake_x
    slli    t3, t1, 2               # i * 4
    add     t4, t2, t3              # &X[i]
    addi    t5, t4, -4              # &X[i-1]
    lw      t6, 0(t5)
    sw      t6, 0(t4)
    # Y[i] = Y[i-1]
    la      t2, snake_y
    add     t4, t2, t3
    addi    t5, t4, -4
    lw      t6, 0(t5)
    sw      t6, 0(t4)
    # i--
    addi    t1, t1, -1
    j       ms_loop
ms_update_head:
    # 3.4 更新头
    la      t0, snake_x
    sw      t1, 0(t0)               # 新头 X
    la      t2, snake_y
    sw      t3, 0(t2)               # 新头 Y
    ret

# ---------------- 4. 生成食物 (伪随机) ----------------
gen_food:
    # 简单的 LCG 随机数生成器
    la      t0, rand_seed
    lw      t1, 0(t0)
    li      t2, 1103515245
    li      t3, 12345
    mul     t1, t1, t2
    add     t1, t1, t3
    sw      t1, 0(t0)
    
    # 计算 X: [1..78]
    li      t2, 78
    remu    t3, t1, t2
    addi    t3, t3, 1
    la      t0, food_x
    sw      t3, 0(t0)
    
    # 计算 Y: [1..28]
    srli    t1, t1, 16
    li      t2, 28
    remu    t3, t1, t2
    addi    t3, t3, 1
    la      t0, food_y
    sw      t3, 0(t0)
    ret

# ---------------- 5. 碰撞检测 ----------------
check_collision:
    la      t0, snake_x
    lw      t1, 0(t0)               # 头 X
    la      t2, snake_y
    lw      t3, 0(t2)               # 头 Y

    # 5.1 撞墙检测 (X:0-79, Y:0-29)
    li      t4, 0
    blt     t1, t4, game_over
    li      t4, 79
    bgt     t1, t4, game_over
    li      t4, 0
    blt     t3, t4, game_over
    li      t4, 29
    bgt     t3, t4, game_over

    # 5.2 撞自己检测 (i from 1 to len-1)
    la      t0, snake_len
    lw      t1, 0(t0)
    addi    t1, t1, -1              # i = len-1
cc_loop:
    beq     t1, zero, cc_pass
    la      t2, snake_x
    slli    t3, t1, 2
    add     t4, t2, t3
    lw      t5, 0(t4)               # X[i]
    la      t2, snake_y
    add     t4, t2, t3
    lw      t6, 0(t4)               # Y[i]
    
    la      t2, snake_x
    lw      t7, 0(t2)               # Head X
    la      t3, snake_y
    lw      t8, 0(t3)               # Head Y
    
    bne     t7, t5, cc_next
    bne     t8, t6, cc_next
    j       game_over                # 撞到自己
cc_next:
    addi    t1, t1, -1
    j       cc_loop
cc_pass:
    ret

# ---------------- 6. 绘制画面 ----------------
draw_game:
    # 6.1 清空游戏区域 (为了性能，这里只重画蛇和食物，不清屏)
    # 实际上为了简单，我们可以先清屏再重画所有
    
    # 6.2 画蛇
    la      t0, snake_len
    lw      t1, 0(t0)
    li      t2, 0                   # i = 0
ds_loop:
    beq     t2, t1, ds_draw_food
    # 获取坐标
    la      t3, snake_x
    slli    t4, t2, 2
    add     t5, t3, t4
    lw      t6, 0(t5)               # X
    la      t3, snake_y
    add     t5, t3, t4
    lw      t7, 0(t5)               # Y
    # 计算 VGA 地址: Base + Y * 80 + X
    li      t0, VGA_BASE
    slli    t1, t7, 6               # Y * 64
    slli    t2, t7, 4               # Y * 16
    add     t1, t1, t2               # Y * 80
    add     t1, t1, t6               # + X
    add     t0, t0, t1
    # 写字符
    li      t1, CHAR_SNAKE
    sb      t1, 0(t0)
    # i++
    addi    t2, t2, 1
    j       ds_loop
ds_draw_food:
    # 6.3 画食物
    la      t0, food_x
    lw      t1, 0(t0)
    la      t2, food_y
    lw      t3, 0(t2)
    li      t0, VGA_BASE
    slli    t4, t3, 6
    slli    t5, t3, 4
    add     t4, t4, t5
    add     t4, t4, t1
    add     t0, t0, t4
    li      t1, CHAR_FOOD
    sb      t1, 0(t0)
    ret

# ---------------- 7. 延时函数 ----------------
delay:
    li      t0, 0x80000              # 调整这个值改变速度
d_loop:
    addi    t0, t0, -1
    bne     t0, zero, d_loop
    ret

# ---------------- 游戏结束 ----------------
game_over:
    # 这里我们只是简单地死循环
    j       game_over