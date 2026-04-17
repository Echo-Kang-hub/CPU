############################################################
# snake_vga.asm
#
# VGA + Keyboard Snake Game (pipeline-cpu)
#
# MMIO map:
#   0xFFFF_0010 : keyboard data (scan code)
#   0xFFFF_0014 : keyboard status (bit0=ready)
#   0xFFFF_0020 : VGA text base (word-addressed char cells)
#
# Gameplay:
#   - Visible border and inner play area
#   - Start/Exit menu with keyboard selection highlight
#   - Game Over menu with Restart/Exit selection highlight
#   - WASD movement
#   - Score and speed display
#   - Pseudo-random food placement
#   - Death on wall hit or self hit
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

    # persistent init
    addi    x7, x0, 1
    sw      x7, 36(x18)           # seed
    sw      x0, 24(x18)           # break_pending
    sw      x0, 44(x18)           # ext_pending
    sw      x0, 40(x18)           # menu_sel

main_restart:
    jal     x5, draw_start_screen
    jal     x5, start_menu_loop   # x6=1 start, x6=0 exit
    bne     x6, x0, start_game
    jal     x0, program_exit

start_game:
    jal     x5, init_game
    jal     x5, flush_kbd_buffer

game_loop:
    jal     x5, poll_key_nonblock
    jal     x5, snake_step        # x6=1 game over
    bne     x6, x0, game_over_enter
    jal     x5, delay_tick
    jal     x0, game_loop

game_over_enter:
    jal     x5, draw_game_over
    jal     x5, over_menu_loop    # x6=0 restart game, x6=1 start menu, x6=2 exit
    beq     x6, x0, start_game
    addi    x7, x0, 1
    beq     x6, x7, main_restart
    jal     x0, program_exit

program_exit:
    jal     x5, clear_screen

    # BYE
    addi    x10, x0, 38
    addi    x11, x0, 14
    addi    x12, x0, 0x42          # B
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x59          # Y
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x45          # E
    jal     x5, put_char_at

halt_loop:
    jal     x0, halt_loop

############################################################
# init_game
# vars layout from x18=0x0200
#  0 : food_x (word)
#  4 : food_y
#  8 : snake_len
# 12 : direction (0=up,1=right,2=down,3=left)
# 16 : score
# 20 : game_over flag (reserved)
# 24 : break_pending
# 28 : tail_x
# 32 : tail_y
# 36 : seed
# 40 : menu_sel
# snake_x bytes: 0x0300..0x037F
# snake_y bytes: 0x0380..0x03FF
############################################################
init_game:
    addi    x30, x5, 0

    jal     x5, clear_screen
    jal     x5, draw_border

    # score=0, game_over=0, break_pending=0
    sw      x0, 16(x18)
    sw      x0, 20(x18)
    sw      x0, 24(x18)
    sw      x0, 44(x18)

    # direction = right (1)
    addi    x7, x0, 1
    sw      x7, 12(x18)

    # snake_len = 5
    addi    x7, x0, 5
    sw      x7, 8(x18)

    # initial snake on row 6: (20,6)(19,6)(18,6)(17,6)(16,6)
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
    addi    x15, x0, 6
    sb      x15, 0(x14)
    sb      x15, 1(x14)
    sb      x15, 2(x14)
    sb      x15, 3(x14)
    sb      x15, 4(x14)

    # draw snake
    addi    x10, x0, 20
    addi    x11, x0, 6
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
    jal     x5, draw_score_speed

    addi    x5, x30, 0
    jalr    x0, x5, 0

############################################################
# draw_start_screen
############################################################
draw_start_screen:
    addi    x30, x5, 0
    jal     x5, clear_screen

    # line: SNAKE
    addi    x10, x0, 16
    addi    x11, x0, 2
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

    # line: WASD TO MOVE
    addi    x10, x0, 13
    addi    x11, x0, 4
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

    # line: HIT WALL/TAIL
    addi    x10, x0, 12
    addi    x11, x0, 5
    addi    x12, x0, 0x48          # H
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x49          # I
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x54          # T
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x57          # W
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x41          # A
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x4C          # L
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x4C          # L
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x2F          # /
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x54          # T
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x41          # A
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x49          # I
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x4C          # L
    jal     x5, put_char_at

    # line: ENTER TO CONFIRM
    addi    x10, x0, 10
    addi    x11, x0, 6
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
    addi    x12, x0, 0x43          # C
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x4F          # O
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x4E          # N
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x46          # F
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x49          # I
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x52          # R
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x4D          # M
    jal     x5, put_char_at

    # debug placeholder: K:-- at row0 (always visible in text area)
    addi    x10, x0, 32
    addi    x11, x0, 0
    addi    x12, x0, 0x4B          # K
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x3A          # :
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x2D          # -
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x2D          # -
    jal     x5, put_char_at

    # default menu selection: START
    sw      x0, 40(x18)
    jal     x5, render_start_options

    addi    x5, x30, 0
    jalr    x0, x5, 0

############################################################
# render_start_options
# menu_sel: 0=START, 1=EXIT
############################################################
render_start_options:
    addi    x26, x5, 0
    lw      x7, 40(x18)
    beq     x7, x0, rso_start_sel

    # line 8: clear full span of START option (overwrite old '>')
    addi    x10, x0, 12
    addi    x11, x0, 8
    addi    x12, x0, 0x20
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
    addi    x10, x10, 1
    addi    x12, x0, 0x20
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
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at

    # line 10: "> EXIT <" (highlight)
    addi    x10, x0, 15
    addi    x11, x0, 10
    addi    x12, x0, 0xBE          # > + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xC5          # E + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xD8          # X + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xC9          # I + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xD4          # T + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xBC          # < + hl
    jal     x5, put_char_at

    addi    x5, x26, 0
    jalr    x0, x5, 0

rso_start_sel:
    # line 8: "> START GAME <" (highlight)
    addi    x10, x0, 12
    addi    x11, x0, 8
    addi    x12, x0, 0xBE          # > + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xD3          # S + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xD4          # T + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xC1          # A + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xD2          # R + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xD4          # T + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xC7          # G + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xC1          # A + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xCD          # M + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xC5          # E + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xBC          # < + hl
    jal     x5, put_char_at

    # line 10: "  EXIT      "
    addi    x10, x0, 15
    addi    x11, x0, 10
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x45          # E
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x58          # X
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x49          # I
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x54          # T
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at

    addi    x5, x26, 0
    jalr    x0, x5, 0

############################################################
# start_menu_loop
# output: x6=1 start game, x6=0 exit
############################################################
start_menu_loop:
    addi    x30, x5, 0
sm_loop:
    jal     x5, read_make_key_block
    jal     x5, draw_key_debug

    # Enter confirms current item (set2/set1/ascii)
    addi    x7, x0, 0x5A
    beq     x25, x7, sm_confirm
    addi    x7, x0, 0x0D
    beq     x25, x7, sm_confirm
    addi    x7, x0, 0x0A
    beq     x25, x7, sm_confirm

    # W/S/A/D toggles selection (Set-2 + Set-1 + ASCII fallback)
    addi    x7, x0, 0x1D          # W
    beq     x25, x7, sm_toggle
    addi    x7, x0, 0x11          # W (set1)
    beq     x25, x7, sm_toggle
    addi    x7, x0, 0x57          # 'W'
    beq     x25, x7, sm_toggle
    addi    x7, x0, 0x77          # 'w'
    beq     x25, x7, sm_toggle
    addi    x7, x0, 0x1B          # S
    beq     x25, x7, sm_toggle
    addi    x7, x0, 0x1F          # S (set1)
    beq     x25, x7, sm_toggle
    addi    x7, x0, 0x53          # 'S'
    beq     x25, x7, sm_toggle
    addi    x7, x0, 0x73          # 's'
    beq     x25, x7, sm_toggle
    addi    x7, x0, 0x1C          # A
    beq     x25, x7, sm_toggle
    addi    x7, x0, 0x1E          # A (set1)
    beq     x25, x7, sm_toggle
    addi    x7, x0, 0x41          # 'A'
    beq     x25, x7, sm_toggle
    addi    x7, x0, 0x61          # 'a'
    beq     x25, x7, sm_toggle
    addi    x7, x0, 0x23          # D
    beq     x25, x7, sm_toggle
    addi    x7, x0, 0x20          # D (set1)
    beq     x25, x7, sm_toggle
    addi    x7, x0, 0x44          # 'D'
    beq     x25, x7, sm_toggle
    addi    x7, x0, 0x64          # 'd'
    beq     x25, x7, sm_toggle

    # Arrow keys (set2 + set1 make codes after E0 prefix)
    addi    x7, x0, 0x75          # Up
    beq     x25, x7, sm_toggle
    addi    x7, x0, 0x48          # Up (set1)
    beq     x25, x7, sm_toggle
    addi    x7, x0, 0x72          # Down
    beq     x25, x7, sm_toggle
    addi    x7, x0, 0x50          # Down (set1)
    beq     x25, x7, sm_toggle
    addi    x7, x0, 0x6B          # Left
    beq     x25, x7, sm_toggle
    addi    x7, x0, 0x4B          # Left (set1)
    beq     x25, x7, sm_toggle
    addi    x7, x0, 0x74          # Right
    beq     x25, x7, sm_toggle
    addi    x7, x0, 0x4D          # Right (set1)
    beq     x25, x7, sm_toggle
    jal     x0, sm_loop

sm_toggle:
    lw      x7, 40(x18)
    xori    x7, x7, 1
    sw      x7, 40(x18)
    jal     x5, render_start_options
    jal     x0, sm_loop

sm_confirm:
    lw      x7, 40(x18)
    bne     x7, x0, sm_exit
    addi    x6, x0, 1
    addi    x5, x30, 0
    jalr    x0, x5, 0

sm_exit:
    addi    x6, x0, 0
    addi    x5, x30, 0
    jalr    x0, x5, 0

############################################################
# draw_game_over
############################################################
draw_game_over:
    addi    x30, x5, 0
    jal     x5, clear_screen

    # line: GAME OVER
    addi    x10, x0, 14
    addi    x11, x0, 2
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

    # line: FINAL SCORE:
    addi    x10, x0, 11
    addi    x11, x0, 4
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

    addi    x10, x0, 24
    addi    x11, x0, 4
    jal     x5, draw_score3_at

    # default menu selection: RESTART
    sw      x0, 40(x18)
    jal     x5, render_over_options

    addi    x5, x30, 0
    jalr    x0, x5, 0

############################################################
# render_over_options
# menu_sel: 0=RESTART, 1=START MENU, 2=EXIT
############################################################
render_over_options:
    addi    x26, x5, 0

    # row 8: "  RESTART  " (centered)
    addi    x10, x0, 13
    addi    x11, x0, 8
    addi    x12, x0, 0x20
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
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at

    # row 10: "  START MENU  " (centered)
    addi    x10, x0, 12
    addi    x11, x0, 10
    addi    x12, x0, 0x20
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
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x4D          # M
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x45          # E
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x4E          # N
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x55          # U
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at

    # row 12: "  EXIT  "
    addi    x10, x0, 15
    addi    x11, x0, 12
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x45          # E
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x58          # X
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x49          # I
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x54          # T
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at

    lw      x7, 40(x18)
    beq     x7, x0, roo_restart_sel
    addi    x8, x0, 1
    beq     x7, x8, roo_menu_sel
    jal     x0, roo_exit_sel

roo_restart_sel:
    # line 8: "> RESTART <" (highlight)
    addi    x10, x0, 13
    addi    x11, x0, 8
    addi    x12, x0, 0xBE          # > + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xD2          # R + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xC5          # E + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xD3          # S + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xD4          # T + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xC1          # A + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xD2          # R + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xD4          # T + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xBC          # < + hl
    jal     x5, put_char_at

    addi    x5, x26, 0
    jalr    x0, x5, 0

roo_menu_sel:
    # line 10: "> START MENU <" (highlight)
    addi    x10, x0, 12
    addi    x11, x0, 10
    addi    x12, x0, 0xBE          # > + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xD3          # S + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xD4          # T + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xC1          # A + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xD2          # R + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xD4          # T + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xCD          # M + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xC5          # E + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xCE          # N + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xD5          # U + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xBC          # < + hl
    jal     x5, put_char_at

    addi    x5, x26, 0
    jalr    x0, x5, 0

roo_exit_sel:
    # line 12: "> EXIT <" (highlight)
    addi    x10, x0, 15
    addi    x11, x0, 12
    addi    x12, x0, 0xBE          # > + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xC5          # E + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xD8          # X + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xC9          # I + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xD4          # T + hl
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0xBC          # < + hl
    jal     x5, put_char_at

    # line 10: "  EXIT     "
    addi    x5, x26, 0
    jalr    x0, x5, 0

############################################################
# over_menu_loop
# output: x6=0 restart game, x6=1 start menu, x6=2 exit
############################################################
over_menu_loop:
    addi    x30, x5, 0
om_loop:
    jal     x5, read_make_key_block
    jal     x5, draw_key_debug

    # Enter confirms current item (set2/set1/ascii)
    addi    x7, x0, 0x5A
    beq     x25, x7, om_confirm
    addi    x7, x0, 0x0D
    beq     x25, x7, om_confirm
    addi    x7, x0, 0x0A
    beq     x25, x7, om_confirm

    # previous item: W/A/Up/Left (Set-2 + Set-1 + ASCII fallback)
    addi    x7, x0, 0x1D          # W
    beq     x25, x7, om_prev
    addi    x7, x0, 0x11          # W (set1)
    beq     x25, x7, om_prev
    addi    x7, x0, 0x57          # 'W'
    beq     x25, x7, om_prev
    addi    x7, x0, 0x77          # 'w'
    beq     x25, x7, om_prev
    addi    x7, x0, 0x1C          # A
    beq     x25, x7, om_prev
    addi    x7, x0, 0x1E          # A (set1)
    beq     x25, x7, om_prev
    addi    x7, x0, 0x41          # 'A'
    beq     x25, x7, om_prev
    addi    x7, x0, 0x61          # 'a'
    beq     x25, x7, om_prev
    addi    x7, x0, 0x75          # Up
    beq     x25, x7, om_prev
    addi    x7, x0, 0x48          # Up (set1)
    beq     x25, x7, om_prev
    addi    x7, x0, 0x6B          # Left
    beq     x25, x7, om_prev
    addi    x7, x0, 0x4B          # Left (set1)
    beq     x25, x7, om_prev

    # next item: S/D/Down/Right (Set-2 + Set-1 + ASCII fallback)
    addi    x7, x0, 0x1B          # S
    beq     x25, x7, om_next
    addi    x7, x0, 0x1F          # S (set1)
    beq     x25, x7, om_next
    addi    x7, x0, 0x53          # 'S'
    beq     x25, x7, om_next
    addi    x7, x0, 0x73          # 's'
    beq     x25, x7, om_next
    addi    x7, x0, 0x23          # D
    beq     x25, x7, om_next
    addi    x7, x0, 0x20          # D (set1)
    beq     x25, x7, om_next
    addi    x7, x0, 0x44          # 'D'
    beq     x25, x7, om_next
    addi    x7, x0, 0x64          # 'd'
    beq     x25, x7, om_next
    addi    x7, x0, 0x72          # Down
    beq     x25, x7, om_next
    addi    x7, x0, 0x50          # Down (set1)
    beq     x25, x7, om_next
    addi    x7, x0, 0x74          # Right
    beq     x25, x7, om_next
    addi    x7, x0, 0x4D          # Right (set1)
    beq     x25, x7, om_next
    jal     x0, om_loop

om_prev:
    lw      x7, 40(x18)
    beq     x7, x0, om_prev_wrap
    addi    x7, x7, -1
    sw      x7, 40(x18)
    jal     x5, render_over_options
    jal     x0, om_loop

om_prev_wrap:
    addi    x7, x0, 2
    sw      x7, 40(x18)
    jal     x5, render_over_options
    jal     x0, om_loop

om_next:
    lw      x7, 40(x18)
    addi    x8, x0, 2
    beq     x7, x8, om_next_wrap
    addi    x7, x7, 1
    sw      x7, 40(x18)
    jal     x5, render_over_options
    jal     x0, om_loop

om_next_wrap:
    sw      x0, 40(x18)
    jal     x5, render_over_options
    jal     x0, om_loop

om_confirm:
    lw      x7, 40(x18)
    beq     x7, x0, om_restart
    addi    x8, x0, 1
    beq     x7, x8, om_start_menu

    addi    x6, x0, 2
    addi    x5, x30, 0
    jalr    x0, x5, 0

om_start_menu:
    addi    x6, x0, 1
    addi    x5, x30, 0
    jalr    x0, x5, 0

om_restart:
    addi    x6, x0, 0
    addi    x5, x30, 0
    jalr    x0, x5, 0

############################################################
# flush_kbd_buffer
# Drain pending keyboard bytes (e.g., Enter break sequence)
# before gameplay starts, then reset prefix flags.
############################################################
flush_kbd_buffer:
    addi    x30, x5, 0
    addi    x7, x0, 32            # safety cap

fkb_loop:
    lw      x6, 0(x29)
    andi    x6, x6, 1
    beq     x6, x0, fkb_done

    lw      x25, 0(x28)           # pop one pending byte
    addi    x7, x7, -1
    bne     x7, x0, fkb_loop

fkb_done:
    sw      x0, 24(x18)           # break_pending = 0
    sw      x0, 44(x18)           # ext_pending = 0
    addi    x5, x30, 0
    jalr    x0, x5, 0

############################################################
# read_make_key_block
# blocking read, handles Set-2 prefixes E0/F0 and returns make code
# output: x25 = make code
############################################################
read_make_key_block:
rk_wait_ready:
    lw      x6, 0(x29)
    andi    x6, x6, 1
    beq     x6, x0, rk_wait_ready

    lw      x25, 0(x28)

    # E0 means next byte is extended key code
    addi    x7, x0, 0xE0
    beq     x25, x7, rk_set_ext

    # F0 means next byte is break code
    addi    x7, x0, 0xF0
    beq     x25, x7, rk_set_break

    # if previous F0 existed, skip this break data byte and continue
    lw      x7, 24(x18)
    beq     x7, x0, rk_check_ext_make
    sw      x0, 24(x18)

    # extended break sequence E0 F0 xx: clear ext_pending too
    lw      x7, 44(x18)
    beq     x7, x0, rk_wait_ready
    sw      x0, 44(x18)
    jal     x0, rk_wait_ready

rk_check_ext_make:
    # extended make sequence E0 xx: clear ext_pending then return xx
    lw      x7, 44(x18)
    beq     x7, x0, rk_return
    sw      x0, 44(x18)
    jal     x0, rk_return

rk_set_ext:
    addi    x7, x0, 1
    sw      x7, 44(x18)
    jal     x0, rk_wait_ready

rk_set_break:
    addi    x7, x0, 1
    sw      x7, 24(x18)
    jal     x0, rk_wait_ready

rk_return:
    jalr    x0, x5, 0

############################################################
# poll_key_nonblock (WASD in gameplay)
############################################################
poll_key_nonblock:
    addi    x30, x5, 0
    addi    x6, x0, 24            # max bytes consumed per frame

pk_check_ready:
    beq     x6, x0, pk_return
    lw      x14, 0(x29)
    andi    x14, x14, 1
    bne     x14, x0, pk_read
    jal     x0, pk_return

pk_read:
    lw      x25, 0(x28)

    addi    x7, x0, 0xE0
    beq     x25, x7, pk_set_ext

    addi    x7, x0, 0xF0
    beq     x25, x7, pk_set_break

    lw      x7, 24(x18)
    beq     x7, x0, pk_check_ext_make
    sw      x0, 24(x18)

    # extended break sequence E0 F0 xx: clear ext_pending too
    lw      x7, 44(x18)
    beq     x7, x0, pk_done
    sw      x0, 44(x18)
    jal     x0, pk_done

pk_check_ext_make:
    # extended make sequence E0 xx: consume ext flag and decode xx
    lw      x7, 44(x18)
    beq     x7, x0, pk_decode
    sw      x0, 44(x18)
    jal     x0, pk_decode

pk_set_ext:
    addi    x7, x0, 1
    sw      x7, 44(x18)
    jal     x0, pk_done

pk_set_break:
    addi    x7, x0, 1
    sw      x7, 24(x18)
    jal     x0, pk_done

pk_decode:
    lw      x9, 12(x18)            # current dir

    # W set2(0x1D) / set1(0x11) / ASCII W/w => up(0)
    addi    x7, x0, 0x1D
    beq     x25, x7, pk_go_up
    addi    x7, x0, 0x11
    beq     x25, x7, pk_go_up
    addi    x7, x0, 0x57
    beq     x25, x7, pk_go_up
    addi    x7, x0, 0x77
    bne     x25, x7, pk_check_s
pk_go_up:
    addi    x7, x0, 2
    beq     x9, x7, pk_done
    sw      x0, 12(x18)
    jal     x0, pk_return

pk_check_s:
    # S set2/set1/ASCII or ArrowDown set2/set1
    addi    x7, x0, 0x1B
    beq     x25, x7, pk_go_down
    addi    x7, x0, 0x1F
    beq     x25, x7, pk_go_down
    addi    x7, x0, 0x53
    beq     x25, x7, pk_go_down
    addi    x7, x0, 0x73
    beq     x25, x7, pk_go_down
    addi    x7, x0, 0x72
    beq     x25, x7, pk_go_down
    addi    x7, x0, 0x50
    bne     x25, x7, pk_check_a
pk_go_down:
    beq     x9, x0, pk_done
    addi    x7, x0, 2
    sw      x7, 12(x18)
    jal     x0, pk_return

pk_check_a:
    # A set2/set1/ASCII or ArrowLeft set2/set1
    addi    x7, x0, 0x1C
    beq     x25, x7, pk_go_left
    addi    x7, x0, 0x1E
    beq     x25, x7, pk_go_left
    addi    x7, x0, 0x41
    beq     x25, x7, pk_go_left
    addi    x7, x0, 0x61
    beq     x25, x7, pk_go_left
    addi    x7, x0, 0x6B
    beq     x25, x7, pk_go_left
    addi    x7, x0, 0x4B
    bne     x25, x7, pk_check_d
pk_go_left:
    addi    x7, x0, 1
    beq     x9, x7, pk_done
    addi    x7, x0, 3
    sw      x7, 12(x18)
    jal     x0, pk_return

pk_check_d:
    # D set2/set1/ASCII or ArrowRight set2/set1
    addi    x7, x0, 0x23
    beq     x25, x7, pk_go_right
    addi    x7, x0, 0x20
    beq     x25, x7, pk_go_right
    addi    x7, x0, 0x44
    beq     x25, x7, pk_go_right
    addi    x7, x0, 0x64
    beq     x25, x7, pk_go_right
    addi    x7, x0, 0x74
    beq     x25, x7, pk_go_right
    addi    x7, x0, 0x4D
    bne     x25, x7, pk_check_up_arrow
pk_go_right:
    addi    x7, x0, 3
    beq     x9, x7, pk_done
    addi    x7, x0, 1
    sw      x7, 12(x18)
    jal     x0, pk_return

pk_check_up_arrow:
    # ArrowUp set2(0x75)/set1(0x48) => up(0), cannot from down(2)
    addi    x7, x0, 0x75
    beq     x25, x7, pk_go_up_arrow
    addi    x7, x0, 0x48
    bne     x25, x7, pk_done
pk_go_up_arrow:
    addi    x7, x0, 2
    beq     x9, x7, pk_done
    sw      x0, 12(x18)
    jal     x0, pk_return

pk_done:
    addi    x6, x6, -1
    jal     x0, pk_check_ready

pk_return:
    addi    x5, x30, 0
    jalr    x0, x5, 0

############################################################
# snake_step
# output: x6 = 0 continue, x6 = 1 game over
############################################################
snake_step:
    addi    x30, x5, 0
    addi    x6, x0, 0

    # advance seed every frame to improve food randomness
    lw      x14, 36(x18)
    addi    x14, x14, 11
    sw      x14, 36(x18)

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
    lbu     x10, 0(x14)
    addi    x14, x0, 0x0380
    lbu     x11, 0(x14)

    # move by direction
    lw      x9, 12(x18)

    # dir 0 up
    bne     x9, x0, ss_dir_right
    addi    x11, x11, -1
    jal     x0, ss_check_wall

ss_dir_right:
    addi    x7, x0, 1
    bne     x9, x7, ss_dir_down
    addi    x10, x10, 1
    jal     x0, ss_check_wall

ss_dir_down:
    addi    x7, x0, 2
    bne     x9, x7, ss_dir_left
    addi    x11, x11, 1
    jal     x0, ss_check_wall

ss_dir_left:
    addi    x10, x10, -1

ss_check_wall:
    # Border is rectangle: left=1,right=36,top=1,bottom=12
    # Valid inner play area: x in [2..35], y in [2..11]
    addi    x7, x0, 2
    blt     x10, x7, ss_hit_wall
    addi    x7, x0, 36
    bge     x10, x7, ss_hit_wall
    addi    x7, x0, 2
    blt     x11, x7, ss_hit_wall
    addi    x7, x0, 12
    bge     x11, x7, ss_hit_wall
    jal     x0, ss_store_head

ss_hit_wall:
    addi    x6, x0, 1
    addi    x5, x30, 0
    jalr    x0, x5, 0

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

    # eat: len++ (max127), append new tail at old tail coord, score++, place food
    lw      x14, 8(x18)
    addi    x15, x0, 127
    bge     x14, x15, ss_skip_len_inc

    # new segment index is old len; initialize it to preserved old tail
    addi    x17, x0, 0x0300
    add     x17, x17, x14
    lw      x16, 28(x18)
    sb      x16, 0(x17)

    addi    x17, x0, 0x0380
    add     x17, x17, x14
    lw      x16, 32(x18)
    sb      x16, 0(x17)

    addi    x14, x14, 1
    sw      x14, 8(x18)

ss_skip_len_inc:
    lw      x14, 16(x18)
    addi    x14, x14, 1
    sw      x14, 16(x18)

    jal     x5, place_food
    jal     x5, draw_score_speed
    jal     x5, redraw_snake_food
    addi    x5, x30, 0
    jalr    x0, x5, 0

ss_not_eat:
    # erase old tail if not eaten
    lw      x10, 28(x18)
    lw      x11, 32(x18)
    addi    x12, x0, 0x20          # ' '
    jal     x5, put_char_at

    # Full redraw to self-heal any missed MMIO writes (avoid ghost tail trails)
    jal     x5, redraw_snake_food

    addi    x5, x30, 0
    jalr    x0, x5, 0

############################################################
# place_food
# LCG-like stepping + snake overlap check
# inner play area: x=[2..35], y=[2..11]
############################################################
place_food:
    addi    x26, x5, 0

pf_retry:
    # seed = seed * 5 + 17
    lw      x7, 36(x18)
    slli    x8, x7, 2
    add     x7, x8, x7
    addi    x7, x7, 17
    sw      x7, 36(x18)

    # bound seed before modulo-by-subtraction to avoid long stalls after restart
    andi    x8, x7, 0x3FF

    # x = (seed % 34) + 2
pf_mod_x:
    addi    x9, x0, 34
    blt     x8, x9, pf_mod_x_done
    addi    x8, x8, -34
    jal     x0, pf_mod_x
pf_mod_x_done:
    addi    x10, x8, 2

    # y = ((seed + 31) % 10) + 2
    andi    x8, x7, 0x3FF
    addi    x8, x8, 31
pf_mod_y:
    addi    x9, x0, 10
    blt     x8, x9, pf_mod_y_done
    addi    x8, x8, -10
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
# redraw_snake_food
# Repaint inner play area + food + snake from RAM state.
# This removes visual ghosting if incremental MMIO writes are dropped.
############################################################
redraw_snake_food:
    addi    x26, x5, 0

    # clear inner area: x=[2..35], y=[2..11]
    addi    x11, x0, 2
rsf_row_loop:
    addi    x10, x0, 2
rsf_col_loop:
    addi    x12, x0, 0x20
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x7, x0, 36
    blt     x10, x7, rsf_col_loop

    addi    x11, x11, 1
    addi    x7, x0, 12
    blt     x11, x7, rsf_row_loop

    # redraw food
    lw      x10, 0(x18)
    lw      x11, 4(x18)
    addi    x12, x0, 0x2A          # '*'
    jal     x5, put_char_at

    # redraw body: i=1..len-1
    lw      x7, 8(x18)
    addi    x8, x0, 1
rsf_body_loop:
    beq     x8, x7, rsf_head

    addi    x14, x0, 0x0300
    add     x15, x14, x8
    lbu     x10, 0(x15)

    addi    x14, x0, 0x0380
    add     x15, x14, x8
    lbu     x11, 0(x15)

    addi    x12, x0, 0x6F          # 'o'
    jal     x5, put_char_at

    addi    x8, x8, 1
    jal     x0, rsf_body_loop

rsf_head:
    addi    x14, x0, 0x0300
    lbu     x10, 0(x14)
    addi    x14, x0, 0x0380
    lbu     x11, 0(x14)

    lw      x9, 12(x18)
    addi    x12, x0, 0x3E          # default '>'
    bne     x9, x0, rsf_head_right
    addi    x12, x0, 0x5E          # '^'
    jal     x0, rsf_head_draw

rsf_head_right:
    addi    x7, x0, 1
    bne     x9, x7, rsf_head_down
    addi    x12, x0, 0x3E          # '>'
    jal     x0, rsf_head_draw

rsf_head_down:
    addi    x7, x0, 2
    bne     x9, x7, rsf_head_left
    addi    x12, x0, 0x76          # 'v'
    jal     x0, rsf_head_draw

rsf_head_left:
    addi    x12, x0, 0x3C          # '<'

rsf_head_draw:
    jal     x5, put_char_at

    addi    x5, x26, 0
    jalr    x0, x5, 0

############################################################
# draw_score_speed
# HUD at top row
############################################################
draw_score_speed:
    addi    x24, x5, 0

    # SCORE: at row0 col2
    addi    x11, x0, 0
    addi    x10, x0, 2

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

    # score digits at col9..11
    addi    x10, x0, 9
    addi    x11, x0, 0
    jal     x5, draw_score3_at

    # SPD: at row0 col16
    addi    x10, x0, 16
    addi    x11, x0, 0
    addi    x12, x0, 0x53          # S
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x50          # P
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x44          # D
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x3A          # :
    jal     x5, put_char_at

    # speed level = min(9, score/5 + 1)
    lw      x7, 16(x18)
    addi    x8, x0, 1
    addi    x9, x0, 5
dss_spd_loop:
    blt     x7, x9, dss_spd_done
    addi    x7, x7, -5
    addi    x8, x8, 1
    addi    x10, x0, 9
    blt     x8, x10, dss_spd_loop
    addi    x8, x0, 9

dss_spd_done:
    addi    x10, x0, 20
    addi    x11, x0, 0
    addi    x12, x8, 48
    jal     x5, put_char_at

    # hint line
    addi    x10, x0, 31
    addi    x11, x0, 0
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

    addi    x5, x24, 0
    jalr    x0, x5, 0

############################################################
# draw_score3_at
# input: x10=col, x11=row
# uses current score in 16(x18)
############################################################
draw_score3_at:
    addi    x26, x5, 0

    lw      x7, 16(x18)
    addi    x8, x0, 0              # hundreds
    addi    x9, x0, 0              # tens

    addi    x14, x0, 100
ds3_h_loop:
    blt     x7, x14, ds3_h_done
    addi    x7, x7, -100
    addi    x8, x8, 1
    jal     x0, ds3_h_loop

ds3_h_done:
    addi    x14, x0, 10
ds3_t_loop:
    blt     x7, x14, ds3_t_done
    addi    x7, x7, -10
    addi    x9, x9, 1
    jal     x0, ds3_t_loop

ds3_t_done:
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
# draw_key_debug
# input: x25=last key code
# Draw at row0,right side: "K:xx"
############################################################
draw_key_debug:
    addi    x26, x5, 0

    # 'K:'
    addi    x10, x0, 32
    addi    x11, x0, 0
    addi    x12, x0, 0x4B          # K
    jal     x5, put_char_at
    addi    x10, x10, 1
    addi    x12, x0, 0x3A          # :
    jal     x5, put_char_at

    # high nibble
    srli    x7, x25, 4
    andi    x7, x7, 0x0F
    addi    x12, x7, 0x30
    addi    x8, x0, 10
    blt     x7, x8, dkd_hi_ok
    addi    x12, x12, 7
dkd_hi_ok:
    addi    x10, x0, 34
    addi    x11, x0, 0
    jal     x5, put_char_at

    # low nibble
    andi    x7, x25, 0x0F
    addi    x12, x7, 0x30
    addi    x8, x0, 10
    blt     x7, x8, dkd_lo_ok
    addi    x12, x12, 7
dkd_lo_ok:
    addi    x10, x0, 35
    addi    x11, x0, 0
    jal     x5, put_char_at

    addi    x5, x26, 0
    jalr    x0, x5, 0

############################################################
# draw_border
# border: left=1,right=36,top=1,bottom=12
############################################################
draw_border:
    addi    x26, x5, 0

    # top and bottom horizontal lines
    addi    x10, x0, 1             # x
db_h_loop:
    addi    x11, x0, 1             # top y
    addi    x12, x0, 0x23          # '#'
    jal     x5, put_char_at

    addi    x11, x0, 12            # bottom y
    addi    x12, x0, 0x23
    jal     x5, put_char_at

    addi    x10, x10, 1
    addi    x7, x0, 37
    blt     x10, x7, db_h_loop

    # left and right vertical lines
    addi    x11, x0, 2             # y
db_v_loop:
    addi    x10, x0, 1             # left x
    addi    x12, x0, 0x23
    jal     x5, put_char_at

    addi    x10, x0, 36            # right x
    addi    x12, x0, 0x23
    jal     x5, put_char_at

    addi    x11, x11, 1
    addi    x7, x0, 12
    blt     x11, x7, db_v_loop

    addi    x5, x26, 0
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
# dynamic speed: score higher -> faster
############################################################
delay_tick:
    # If SW15 selects ultra-slow CPU clock, skip software busy-wait.
    # Otherwise one frame can take hours and appears completely frozen.
    lw      x11, 4(x31)           # switch register (0xFFFF0004)
    srli    x11, x11, 15          # move SW15 to bit0
    andi    x11, x11, 0x1
    bne     x11, x0, dly_done

    # outer = max(350, 800 - min(score*8, 450))
    # With inner=2000 this is about 2x faster than previous setting.
    lw      x7, 16(x18)            # score
    slli    x8, x7, 3              # score*8
    addi    x9, x0, 450
    blt     x8, x9, dly_cap_ok
    addi    x8, x0, 450

dly_cap_ok:
    addi    x7, x0, 800
    sub     x7, x7, x8
    addi    x9, x0, 350
    bge     x7, x9, dly_outer
    addi    x7, x0, 350

dly_outer:
    addi    x8, x0, 2000

dly_inner:
    addi    x8, x8, -1
    bne     x8, x0, dly_inner

    addi    x7, x7, -1
    bne     x7, x0, dly_outer

dly_done:
    jalr    x0, x5, 0