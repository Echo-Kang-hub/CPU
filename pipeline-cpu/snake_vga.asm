############################################################
# snake_vga.asm (Fixed for 40x15 2x Scaled VGA Grid)
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
# Adjusted for 40x15 screen center
############################################################
draw_start_screen:
    addi    x30, x5, 0
    jal     x5, clear_screen

    # line: "SNAKE GAME" (starts col 15, row 4)
    addi    x10, x0, 15
    addi    x11, x0, 4
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

    # line: "WASD TO MOVE" (starts col 14, row 7)
    addi    x10, x0, 14
    addi    x11, x0, 7
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

    # line: "PRESS ENTER TO START" (starts col 10, row 10)
    addi    x10, x0, 10
    addi    x11, x0, 10
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

    # line: "OR W A S D" (starts col 15, row 12)
    addi    x10, x0, 15
    addi    x11, x0, 12
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

    addi    x5, x30, 0
    jalr    x0, x5, 0

############################################################
# init_game
############################################################
init_game:
    addi    x30, x5, 0
    jal     x5, clear_screen

    sw      x0, 16(x18)
    sw      x0, 20(x18)
    sw      x0, 24(x18)

    # direction = right (1)
    addi    x7, x0, 1
    sw      x7, 12(x18)

    # snake_len = 5
    addi    x7, x0, 5
    sw      x7, 8(x18)

    # initial snake on row 7, col 20 (adjusted for 40x15)
    addi    x14, x0, 0x0300
    addi    x15, x0, 20
    sb      x15, 0(x14)
    addi    x15, x0, 19
    sb      x15, 1(x14)
    addi    x15, x0, 18
    sb      x15, 2(x14)
    addi    x15, x0, 17
    sb      x15, 3(x14)
    addi    x15, x0, 16
    sb      x15, 4(x14)

    addi    x14, x0, 0x0380
    addi    x15, x0, 7
    sb      x15, 0(x14)
    sb      x15, 1(x14)
    sb      x15, 2(x14)
    sb      x15, 3(x14)
    sb      x15, 4(x14)

    # draw initial snake
    addi    x10, x0, 20
    addi    x11, x0, 7
    addi    x12, x0, 0x3E          # '>' head
    jal     x5, put_char_at

    addi    x10, x0, 19
    addi    x12, x0, 0x6F          # 'o' body
    jal     x5, put_char_at
    addi    x10, x0, 18
    jal     x5, put_char_at
    addi    x10, x0, 17
    jal     x5, put_char_at
    addi    x10, x0, 16
    jal     x5, put_char_at

    jal     x5, place_food
    jal     x5, draw_score

    addi    x5, x30, 0
    jalr    x0, x5, 0

############################################################
# wait_start_key & poll_key_nonblock (No logic change needed)
############################################################
wait_start_key:
we_loop:
    lw      x6, 0(x29)
    andi    x6, x6, 1
    beq     x6, x0, we_loop
    lw      x25, 0(x28)
    addi    x7, x0, 0xF0
    beq     x25, x7, we_set_break
    lw      x7, 24(x18)
    beq     x7, x0, we_check_enter
    sw      x0, 24(x18)
    jal     x0, we_loop
we_set_break:
    addi    x7, x0, 1
    sw      x7, 24(x18)
    jal     x0, we_loop
we_check_enter:
    addi    x7, x0, 0x5A
    beq     x25, x7, we_start_ok
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
    lw      x9, 12(x18)
    addi    x7, x0, 0x1D
    bne     x25, x7, pk_check_s
    addi    x7, x0, 2
    beq     x9, x7, pk_done
    sw      x0, 12(x18)
    jalr    x0, x5, 0
pk_check_s:
    addi    x7, x0, 0x1B
    bne     x25, x7, pk_check_a
    beq     x9, x0, pk_done
    addi    x7, x0, 2
    sw      x7, 12(x18)
    jalr    x0, x5, 0
pk_check_a:
    addi    x7, x0, 0x1C
    bne     x25, x7, pk_check_d
    addi    x7, x0, 1
    beq     x9, x7, pk_done
    addi    x7, x0, 3
    sw      x7, 12(x18)
    jalr    x0, x5, 0
pk_check_d:
    addi    x7, x0, 0x23
    bne     x25, x7, pk_done
    addi    x7, x0, 3
    beq     x9, x7, pk_done
    addi    x7, x0, 1
    sw      x7, 12(x18)
pk_done:
    jalr    x0, x5, 0

############################################################
# snake_step (Adjusted limits for 40x15)
############################################################
snake_step:
    addi    x30, x5, 0
    addi    x6, x0, 0

    lw      x7, 8(x18)
    addi    x8, x7, -1
    addi    x14, x0, 0x0300
    add     x15, x14, x8
    lbu     x16, 0(x15)
    sw      x16, 28(x18)
    addi    x14, x0, 0x0380
    add     x15, x14, x8
    lbu     x16, 0(x15)
    sw      x16, 32(x18)

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
    addi    x14, x0, 0x0300
    lbu     x10, 1(x14)
    addi    x14, x0, 0x0380
    lbu     x11, 1(x14)
    addi    x12, x0, 0x6F
    jal     x5, put_char_at

    addi    x14, x0, 0x0300
    lbu     x10, 0(x14)
    addi    x14, x0, 0x0380
    lbu     x11, 0(x14)

    lw      x9, 12(x18)
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
    # x wrap [0..39]
    bge     x10, x0, ss_x_hi
    addi    x10, x0, 39
ss_x_hi:
    addi    x7, x0, 40
    blt     x10, x7, ss_y_lo
    addi    x10, x0, 0

ss_y_lo:
    # y wrap [1..14] (row 0 is for score)
    addi    x7, x0, 1
    bge     x11, x7, ss_y_hi
    addi    x11, x0, 14
ss_y_hi:
    addi    x7, x0, 15
    blt     x11, x7, ss_store_head
    addi    x11, x0, 1

ss_store_head:
    addi    x14, x0, 0x0300
    sb      x10, 0(x14)
    addi    x14, x0, 0x0380
    sb      x11, 0(x14)

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
    lw      x9, 12(x18)
    addi    x12, x0, 0x3E          # '>'
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

    lw      x14, 0(x18)            # food_x
    bne     x10, x14, ss_not_eat
    lw      x14, 4(x18)            # food_y
    bne     x11, x14, ss_not_eat

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
    lw      x10, 28(x18)
    lw      x11, 32(x18)
    addi    x12, x0, 0x20          # ' '
    jal     x5, put_char_at
    addi    x5, x30, 0
    jalr    x0, x5, 0

############################################################
# place_food (Adjusted modulos for 40x15 grid)
############################################################
place_food:
    addi    x26, x5, 0
pf_retry:
    lw      x7, 36(x18)
    addi    x7, x7, 29
    sw      x7, 36(x18)

    # x = (seed % 38) + 1 (avoids col 0 and 39 walls visually)
    addi    x8, x7, 0
pf_mod_x:
    addi    x9, x0, 38
    blt     x8, x9, pf_mod_x_done
    addi    x8, x8, -38
    jal     x0, pf_mod_x
pf_mod_x_done:
    addi    x10, x8, 1

    # y = ((seed+17) % 13) + 1 (avoids row 0 score area)
    addi    x8, x7, 17
pf_mod_y:
    addi    x9, x0, 13
    blt     x8, x9, pf_mod_y_done
    addi    x8, x8, -13
    jal     x0, pf_mod_y
pf_mod_y_done:
    addi    x11, x8, 1

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
# draw_score (Adjusted position for 40x15 grid)
############################################################
draw_score:
    addi    x26, x5, 0
    # "SCORE:" at row0, col 25
    addi    x11, x0, 0
    addi    x10, x0, 25
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
    # Print digits at col 32
    addi    x10, x0, 32
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
# draw_game_over (Adjusted for 40x15 grid)
############################################################
draw_game_over:
    addi    x30, x5, 0
    jal     x5, clear_screen

    # "GAME OVER" (starts col 15, row 5)
    addi    x10, x0, 15
    addi    x11, x0, 5
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

    # "FINAL SCORE:" (starts col 12, row 8)
    addi    x10, x0, 12
    addi    x11, x0, 8
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
    addi    x10, x0, 25
    addi    x11, x0, 8
    addi    x12, x8, 48
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x9, 48
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x7, 48
    jal     x5, put_char_at

    # "PRESS ENTER TO RESTART" (starts col 9, row 12)
    addi    x10, x0, 9
    addi    x11, x0, 12
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
# Clears up to 40x15 = 600 visible chars (up to 80*15 = 1200 safely)
############################################################
clear_screen:
    addi    x12, x0, 0             # idx
    addi    x13, x0, 1200          # Clear enough rows just to be safe
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
# put_char_at (Unchanged, Memory is still 80 columns wide per row)
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
# delay_tick (Significantly increased for CPU clock speeds)
############################################################
delay_tick:
    # Use LUI to load a massive number for the outer loop.
    # 0x2 -> ~8192 iterations for the outer loop. 
    # If the snake is still too fast, change 0x2 to 0x4 or 0x8. 
    # If it's too slow, change to 0x1.
    lui     x7, 0x2      
    
dly_outer:
    addi    x8, x0, 1000  # inner loop 1000
dly_inner:
    addi    x8, x8, -1
    bne     x8, x0, dly_inner

    addi    x7, x7, -1
    bne     x7, x0, dly_outer

    jalr    x0, x5, 0
