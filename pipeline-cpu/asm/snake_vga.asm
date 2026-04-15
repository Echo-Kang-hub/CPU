############################################################
# snake_vga.asm
#
# VGA + Keyboard Snake Game (for pipeline-cpu)
#
# MMIO map:
#   0xFFFF_0010 : keyboard data (scan code)
#   0xFFFF_0014 : keyboard status (bit0=ready)
#   0xFFFF_0020 : VGA text base (word-addressed char cells)
#
# Features:
#   - Start screen (press Enter or WASD to start)
#   - WASD control
#   - Wrap-around (pass through walls)
#   - Score shown at top-right
#   - Game over screen with final score
#   - Press Enter to restart
############################################################

.text

_start:
    # MMIO base setup
    lui     x31, 0xFFFF0
    addi    x28, x31, 0x0010      # KBD data
    addi    x29, x31, 0x0014      # KBD status
    addi    x27, x31, 0x0020      # VGA base

    # RAM base for game state
    addi    x18, x0, 0x0200       # vars base

    # init persistent state
    addi    x7, x0, 1
    sw      x7, 36(x18)           # seed = 1
    sw      x0, 24(x18)           # break_pending = 0

main_restart:
    jal     x5, draw_start_screen
    jal     x5, wait_start_key
    jal     x5, init_game

game_loop:
    jal     x5, delay_tick
    jal     x5, poll_key_nonblock
    jal     x5, snake_step
    beq     x6, x0, game_continue  # x6=1 => game over

    jal     x5, draw_game_over
    jal     x5, wait_start_key
    jal     x0, main_restart

game_continue:
    jal     x0, game_loop

############################################################
# draw_start_screen
############################################################
draw_start_screen:
    addi    x30, x5, 0
    jal     x5, clear_screen

    # line: "SNAKE GAME"
    addi    x10, x0, 35
    addi    x11, x0, 10
    addi    x12, x0, 0x53          # S
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x4E          # N
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x41          # A
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x4B          # K
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x45          # E
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20          # ' '
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x47          # G
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x41          # A
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x4D          # M
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x45          # E
    jal     x5, put_char_at

    # line: "WASD TO MOVE"
    addi    x10, x0, 34
    addi    x11, x0, 13
    addi    x12, x0, 0x57          # W
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x41          # A
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x53          # S
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x44          # D
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x54          # T
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x4F          # O
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x4D          # M
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x4F          # O
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x56          # V
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x45          # E
    jal     x5, put_char_at

    # line: "PRESS ENTER TO START"
    addi    x10, x0, 30
    addi    x11, x0, 16
    addi    x12, x0, 0x50          # P
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x52          # R
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x45          # E
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x53          # S
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x53          # S
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x45          # E
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x4E          # N
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x54          # T
    jal     x5, put_char_at

    # line: "OR W A S D"
    addi    x10, x0, 35
    addi    x11, x0, 18
    addi    x12, x0, 0x4F          # O
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x52          # R
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x57          # W
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x41          # A
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x53          # S
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x44          # D
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x45          # E
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x52          # R
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x54          # T
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x4F          # O
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x53          # S
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x54          # T
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x41          # A
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x52          # R
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x54          # T
    jal     x5, put_char_at

    addi    x5, x30, 0
    jalr    x0, x5, 0

############################################################
# init_game
# vars layout from x18=0x0200
#  0 : food_x (word)
#  4 : food_y
#  8 : snake_len
# 12 : direction (0=up,1=right,2=down,3=left)
# 16 : score
# 20 : game_over flag
# 24 : break_pending
# 28 : tail_x
# 32 : tail_y
# 36 : seed
# snake_x bytes: 0x0300..0x037F
# snake_y bytes: 0x0380..0x03FF
############################################################
init_game:
    addi    x30, x5, 0
    jal     x5, clear_screen

    # score=0, game_over=0, break_pending=0
    sw      x0, 16(x18)
    sw      x0, 20(x18)
    sw      x0, 24(x18)

    # direction = right (1)
    addi    x7, x0, 1
    sw      x7, 12(x18)

    # snake_len = 5
    addi    x7, x0, 5
    sw      x7, 8(x18)

    # initial snake on row 16: (40,16)(39,16)(38,16)(37,16)(36,16)
    addi    x14, x0, 0x0300
    addi    x15, x0, 40
    sb      x15, 0(x14)
    addi    x15, x0, 39
    sb      x15, 1(x14)
    addi    x15, x0, 38
    sb      x15, 2(x14)
    addi    x15, x0, 37
    sb      x15, 3(x14)
    addi    x15, x0, 36
    sb      x15, 4(x14)

    addi    x14, x0, 0x0380
    addi    x15, x0, 16
    sb      x15, 0(x14)
    sb      x15, 1(x14)
    sb      x15, 2(x14)
    sb      x15, 3(x14)
    sb      x15, 4(x14)

    # draw snake
    addi    x10, x0, 40
    addi    x11, x0, 16
    addi    x12, x0, 0x3E          # '>' head
    jal     x5, put_char_at

    addi    x10, x0, 39
    addi    x12, x0, 0x6F          # 'o' body
    jal     x5, put_char_at
    addi    x10, x0, 38
    jal     x5, put_char_at
    addi    x10, x0, 37
    jal     x5, put_char_at
    addi    x10, x0, 36
    jal     x5, put_char_at

    jal     x5, place_food
    jal     x5, draw_score

    addi    x5, x30, 0
    jalr    x0, x5, 0

############################################################
# wait_start_key
############################################################
wait_start_key:
we_loop:
    lw      x6, 0(x29)
    andi    x6, x6, 1
    beq     x6, x0, we_loop

    lw      x25, 0(x28)

    # handle F0 break prefix
    addi    x7, x0, 0xF0
    beq     x25, x7, we_set_break

    # ignore next byte after F0
    lw      x7, 24(x18)
    beq     x7, x0, we_check_enter
    sw      x0, 24(x18)
    jal     x0, we_loop

we_set_break:
    addi    x7, x0, 1
    sw      x7, 24(x18)
    jal     x0, we_loop

we_check_enter:
    # Enter
    addi    x7, x0, 0x5A
    beq     x25, x7, we_start_ok

    # W / A / S / D can also start game
    addi    x7, x0, 0x1D
    beq     x25, x7, we_start_ok
    addi    x7, x0, 0x1C
    beq     x25, x7, we_start_ok
    addi    x7, x0, 0x1B
    beq     x25, x7, we_start_ok
    addi    x7, x0, 0x23
    bne     x25, x7, we_loop

we_start_ok:
    jalr    x0, x5, 0

############################################################
# poll_key_nonblock (WASD)
############################################################
poll_key_nonblock:
    lw      x6, 0(x29)
    andi    x6, x6, 1
    bne     x6, x0, pk_read
    jalr    x0, x5, 0

pk_read:
    lw      x25, 0(x28)

    addi    x7, x0, 0xF0
    beq     x25, x7, pk_set_break

    lw      x7, 24(x18)
    beq     x7, x0, pk_decode
    sw      x0, 24(x18)
    jalr    x0, x5, 0

pk_set_break:
    addi    x7, x0, 1
    sw      x7, 24(x18)
    jalr    x0, x5, 0

pk_decode:
    lw      x9, 12(x18)            # current dir

    # W (0x1D) => up(0), cannot from down(2)
    addi    x7, x0, 0x1D
    bne     x25, x7, pk_check_s
    addi    x7, x0, 2
    beq     x9, x7, pk_done
    sw      x0, 12(x18)
    jalr    x0, x5, 0

pk_check_s:
    # S (0x1B) => down(2), cannot from up(0)
    addi    x7, x0, 0x1B
    bne     x25, x7, pk_check_a
    beq     x9, x0, pk_done
    addi    x7, x0, 2
    sw      x7, 12(x18)
    jalr    x0, x5, 0

pk_check_a:
    # A (0x1C) => left(3), cannot from right(1)
    addi    x7, x0, 0x1C
    bne     x25, x7, pk_check_d
    addi    x7, x0, 1
    beq     x9, x7, pk_done
    addi    x7, x0, 3
    sw      x7, 12(x18)
    jalr    x0, x5, 0

pk_check_d:
    # D (0x23) => right(1), cannot from left(3)
    addi    x7, x0, 0x23
    bne     x25, x7, pk_done
    addi    x7, x0, 3
    beq     x9, x7, pk_done
    addi    x7, x0, 1
    sw      x7, 12(x18)

pk_done:
    jalr    x0, x5, 0

############################################################
# snake_step
# output: x6 = 0 continue, x6 = 1 game over
############################################################
snake_step:
    addi    x30, x5, 0
    addi    x6, x0, 0

    # len
    lw      x7, 8(x18)

    # save old tail coords (index len-1)
    addi    x8, x7, -1
    addi    x14, x0, 0x0300
    add     x15, x14, x8
    lbu     x16, 0(x15)
    sw      x16, 28(x18)

    addi    x14, x0, 0x0380
    add     x15, x14, x8
    lbu     x16, 0(x15)
    sw      x16, 32(x18)

    # shift body: for i=len-1 downto 1
ss_shift_loop:
    beq     x8, x0, ss_shift_done
    addi    x9, x8, -1

    addi    x14, x0, 0x0300
    add     x15, x14, x8
    add     x17, x14, x9
    lbu     x16, 0(x17)
    sb      x16, 0(x15)

    addi    x14, x0, 0x0380
    add     x15, x14, x8
    add     x17, x14, x9
    lbu     x16, 0(x17)
    sb      x16, 0(x15)

    addi    x8, x8, -1
    jal     x0, ss_shift_loop

ss_shift_done:
    # old head at index1 becomes body 'o'
    addi    x14, x0, 0x0300
    lbu     x10, 1(x14)
    addi    x14, x0, 0x0380
    lbu     x11, 1(x14)
    addi    x12, x0, 0x6F
    jal     x5, put_char_at

    # read head (index0)
    addi    x14, x0, 0x0300
    lbu     x10, 0(x14)            # new_x from old head first
    addi    x14, x0, 0x0380
    lbu     x11, 0(x14)            # new_y

    # move by direction
    lw      x9, 12(x18)

    # dir 0 up
    bne     x9, x0, ss_dir_right
    addi    x11, x11, -1
    jal     x0, ss_wrap

ss_dir_right:
    addi    x7, x0, 1
    bne     x9, x7, ss_dir_down
    addi    x10, x10, 1
    jal     x0, ss_wrap

ss_dir_down:
    addi    x7, x0, 2
    bne     x9, x7, ss_dir_left
    addi    x11, x11, 1
    jal     x0, ss_wrap

ss_dir_left:
    addi    x10, x10, -1

ss_wrap:
    # x wrap [0..79]
    bge     x10, x0, ss_x_hi
    addi    x10, x0, 79
ss_x_hi:
    addi    x7, x0, 80
    blt     x10, x7, ss_y_lo
    addi    x10, x0, 0

ss_y_lo:
    # y wrap [2..29] (rows 0..1 reserved for UI)
    addi    x7, x0, 2
    bge     x11, x7, ss_y_hi
    addi    x11, x0, 29
ss_y_hi:
    addi    x7, x0, 30
    blt     x11, x7, ss_store_head
    addi    x11, x0, 2

ss_store_head:
    # store new head to index0
    addi    x14, x0, 0x0300
    sb      x10, 0(x14)
    addi    x14, x0, 0x0380
    sb      x11, 0(x14)

    # self collision: compare head with body i=1..len-1
    lw      x7, 8(x18)
    addi    x8, x0, 1
ss_self_loop:
    beq     x8, x7, ss_self_done

    addi    x14, x0, 0x0300
    add     x15, x14, x8
    lbu     x16, 0(x15)
    bne     x16, x10, ss_self_next

    addi    x14, x0, 0x0380
    add     x15, x14, x8
    lbu     x16, 0(x15)
    bne     x16, x11, ss_self_next

    addi    x6, x0, 1
    addi    x5, x30, 0
    jalr    x0, x5, 0

ss_self_next:
    addi    x8, x8, 1
    lw      x7, 8(x18)
    jal     x0, ss_self_loop

ss_self_done:
    # draw directional head (^ > v <)
    lw      x9, 12(x18)
    addi    x12, x0, 0x3E          # default '>'
    bne     x9, x0, ss_head_right_check
    addi    x12, x0, 0x5E          # '^'
    jal     x0, ss_head_draw

ss_head_right_check:
    addi    x7, x0, 1
    bne     x9, x7, ss_head_down_check
    addi    x12, x0, 0x3E          # '>'
    jal     x0, ss_head_draw

ss_head_down_check:
    addi    x7, x0, 2
    bne     x9, x7, ss_head_left_set
    addi    x12, x0, 0x76          # 'v'
    jal     x0, ss_head_draw

ss_head_left_set:
    addi    x12, x0, 0x3C          # '<'

ss_head_draw:
    jal     x5, put_char_at

    # check eat food
    lw      x14, 0(x18)            # food_x
    bne     x10, x14, ss_not_eat
    lw      x14, 4(x18)            # food_y
    bne     x11, x14, ss_not_eat

    # eat: len++, score++, place food, redraw score
    lw      x14, 8(x18)
    addi    x14, x14, 1
    sw      x14, 8(x18)

    lw      x14, 16(x18)
    addi    x14, x14, 1
    sw      x14, 16(x18)

    jal     x5, place_food
    jal     x5, draw_score
    addi    x5, x30, 0
    jalr    x0, x5, 0

ss_not_eat:
    # erase old tail if not eaten
    lw      x10, 28(x18)
    lw      x11, 32(x18)
    addi    x12, x0, 0x20          # ' '
    jal     x5, put_char_at
    addi    x5, x30, 0
    jalr    x0, x5, 0

############################################################
# place_food
# simple LCG-like stepping + snake overlap check
############################################################
place_food:
    addi    x26, x5, 0
pf_retry:
    # seed = seed + 29
    lw      x7, 36(x18)
    addi    x7, x7, 29
    sw      x7, 36(x18)

    # x = (seed % 78) + 1
    addi    x8, x7, 0
pf_mod_x:
    addi    x9, x0, 78
    blt     x8, x9, pf_mod_x_done
    addi    x8, x8, -78
    jal     x0, pf_mod_x
pf_mod_x_done:
    addi    x10, x8, 1

    # y = ((seed+17) % 28) + 2
    addi    x8, x7, 17
pf_mod_y:
    addi    x9, x0, 28
    blt     x8, x9, pf_mod_y_done
    addi    x8, x8, -28
    jal     x0, pf_mod_y
pf_mod_y_done:
    addi    x11, x8, 2

    # overlap check with snake body
    lw      x12, 8(x18)            # len
    addi    x13, x0, 0             # i=0
pf_chk_loop:
    beq     x13, x12, pf_ok

    addi    x14, x0, 0x0300
    add     x15, x14, x13
    lbu     x16, 0(x15)
    bne     x16, x10, pf_chk_next

    addi    x14, x0, 0x0380
    add     x15, x14, x13
    lbu     x16, 0(x15)
    beq     x16, x11, pf_retry

pf_chk_next:
    addi    x13, x13, 1
    jal     x0, pf_chk_loop

pf_ok:
    sw      x10, 0(x18)
    sw      x11, 4(x18)

    addi    x12, x0, 0x2A          # '*'
    jal     x5, put_char_at
    addi    x5, x26, 0
    jalr    x0, x5, 0

############################################################
# draw_score (top-right)
############################################################
draw_score:
    addi    x26, x5, 0
    # "SCORE:" at row0, col64
    addi    x11, x0, 0
    addi    x10, x0, 64

    addi    x12, x0, 0x53          # S
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x43          # C
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x4F          # O
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x52          # R
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x45          # E
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x3A          # :
    jal     x5, put_char_at

    # convert score to 3 digits
    lw      x7, 16(x18)            # score
    addi    x8, x0, 0              # hundreds
    addi    x9, x0, 0              # tens

    addi    x14, x0, 100
sc_h_loop:
    blt     x7, x14, sc_h_done
    addi    x7, x7, -100
    addi    x8, x8, 1
    jal     x0, sc_h_loop

sc_h_done:
    addi    x14, x0, 10
sc_t_loop:
    blt     x7, x14, sc_t_done
    addi    x7, x7, -10
    addi    x9, x9, 1
    jal     x0, sc_t_loop

sc_t_done:
    # ones = x7
    addi    x10, x0, 70
    addi    x11, x0, 0

    addi    x12, x8, 48
    jal     x5, put_char_at

    addi    x10, x10, 1
    addi    x12, x9, 48
    jal     x5, put_char_at

    addi    x10, x10, 1
    addi    x12, x7, 48
    jal     x5, put_char_at

    addi    x5, x26, 0
    jalr    x0, x5, 0

############################################################
# draw_game_over
############################################################
draw_game_over:
    addi    x30, x5, 0
    jal     x5, clear_screen

    # "GAME OVER"
    addi    x10, x0, 35
    addi    x11, x0, 11
    addi    x12, x0, 0x47          # G
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x41          # A
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x4D          # M
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x45          # E
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x4F          # O
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x56          # V
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x45          # E
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x52          # R
    jal     x5, put_char_at

    # "FINAL SCORE:" line
    addi    x10, x0, 31
    addi    x11, x0, 14
    addi    x12, x0, 0x46          # F
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x49          # I
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x4E          # N
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x41          # A
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x4C          # L
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x53          # S
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x43          # C
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x4F          # O
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x52          # R
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x45          # E
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x3A          # :
    jal     x5, put_char_at

    # final score digits at col43..45 row14
    lw      x7, 16(x18)
    addi    x8, x0, 0
    addi    x9, x0, 0

    addi    x14, x0, 100
go_h_loop:
    blt     x7, x14, go_h_done
    addi    x7, x7, -100
    addi    x8, x8, 1
    jal     x0, go_h_loop

go_h_done:
    addi    x14, x0, 10
go_t_loop:
    blt     x7, x14, go_t_done
    addi    x7, x7, -10
    addi    x9, x9, 1
    jal     x0, go_t_loop

go_t_done:
    addi    x10, x0, 43
    addi    x11, x0, 14

    addi    x12, x8, 48
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x9, 48
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x7, 48
    jal     x5, put_char_at

    # "PRESS ENTER TO RESTART"
    addi    x10, x0, 29
    addi    x11, x0, 18
    addi    x12, x0, 0x50          # P
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x52          # R
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x45          # E
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x53          # S
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x53          # S
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x45          # E
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x4E          # N
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x54          # T
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x45          # E
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x52          # R
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x54          # T
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x4F          # O
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x52          # R
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x45          # E
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x53          # S
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x54          # T
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x41          # A
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x52          # R
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x54          # T
    jal     x5, put_char_at

    addi    x5, x30, 0
    jalr    x0, x5, 0

############################################################
# clear_screen
############################################################
clear_screen:
    addi    x12, x0, 0             # idx
    addi    x13, x0, 75
    slli    x13, x13, 5            # 2400
    addi    x14, x0, 0x20          # space

cs_loop:
    beq     x12, x13, cs_done
    slli    x15, x12, 2
    add     x16, x27, x15
    sw      x14, 0(x16)
    addi    x12, x12, 1
    jal     x0, cs_loop

cs_done:
    jalr    x0, x5, 0

############################################################
# put_char_at
# input: x10=col(0..79), x11=row(0..29), x12=ascii
############################################################
put_char_at:
    slli    x13, x11, 6            # row*64
    slli    x14, x11, 4            # row*16
    add     x13, x13, x14          # row*80
    add     x13, x13, x10          # +col
    slli    x13, x13, 2            # *4 (word addressed)
    add     x13, x13, x27
    sw      x12, 0(x13)
    jalr    x0, x5, 0

############################################################
# delay_tick
############################################################
delay_tick:
    addi    x7, x0, 110

dly_outer:
    addi    x8, x0, 255

dly_inner:
    addi    x8, x8, -1
    bne     x8, x0, dly_inner

    addi    x7, x7, -1
    bne     x7, x0, dly_outer

    jalr    x0, x5, 0
