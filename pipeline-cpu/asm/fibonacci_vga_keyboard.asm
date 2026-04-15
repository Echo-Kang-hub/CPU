#################################################
# typing_vga.asm
#
# Keyboard typing on VGA text buffer
#
# MMIO map (canonical)
#   0xFFFF_0010 : keyboard data (scan code)
#   0xFFFF_0014 : keyboard status (bit0=ready)
#   0xFFFF_0020 : VGA text base (word-addressed char cells)
#
# Features
#   - Continuous typing to VGA
#   - Enter    : newline
#   - Backspace: erase previous character
#   - Tab      : insert 4 spaces
#   - Shift    : uppercase letters and symbol variants
#   - CapsLock : letter case toggle
#   - Handles PS/2 Set-2 break sequence (F0 xx)
#   - Ignores extended keys (E0 xx)
#   - Auto scroll when screen is full
#################################################

    lui     x31, 0xFFFF0
    addi    x28, x31, 0x0010      # KBD data
    addi    x29, x31, 0x0014      # KBD status
    addi    x27, x31, 0x0020      # VGA base

    addi    x20, x0, 0            # cursor col (0..79)
    addi    x21, x0, 0            # cursor row (0..29)
    addi    x22, x0, 0            # shift_down flag
    addi    x23, x0, 0            # break_pending flag
    addi    x24, x0, 0            # ext_pending flag (E0)
    addi    x26, x0, 0            # caps_lock flag
    addi    x1, x0, 0             # blink counter
    addi    x4, x0, 0             # cursor visible flag (0/1)

    jal     x5, clear_screen
    jal     x5, draw_title
    jal     x5, cursor_show

main_loop:
    # Poll keyboard ready
    lw      x6, 0(x29)
    andi    x6, x6, 0x1
    beq     x6, x0, no_key

    # Hide cursor before consuming key
    beq     x4, x0, key_read
    jal     x5, cursor_hide

key_read:

    # Read one scan code (also creates read-ack pulse in MIO_BUS)
    lw      x25, 0(x28)

    # Extended prefix E0
    addi    x7, x0, 0xE0
    beq     x25, x7, on_e0

    # Break prefix F0
    addi    x7, x0, 0xF0
    beq     x25, x7, on_f0

    # Break sequence data byte
    beq     x23, x0, check_ext_make
    beq     x24, x0, on_break_normal
    # Extended break byte: ignore and clear flags
    addi    x23, x0, 0
    addi    x24, x0, 0
    jal     x0, main_loop

on_break_normal:
    # Release shift?
    addi    x7, x0, 0x12
    beq     x25, x7, shift_up
    addi    x7, x0, 0x59
    beq     x25, x7, shift_up
    addi    x23, x0, 0
    jal     x0, main_loop

shift_up:
    addi    x22, x0, 0
    addi    x23, x0, 0
    jal     x0, main_loop

check_ext_make:
    # Ignore extended make byte after E0
    beq     x24, x0, check_shift_make
    addi    x24, x0, 0
    jal     x0, main_loop

check_shift_make:
    addi    x7, x0, 0x12
    beq     x25, x7, shift_down
    addi    x7, x0, 0x59
    beq     x25, x7, shift_down

    # Caps Lock (toggle on make code 0x58)
    addi    x7, x0, 0x58
    beq     x25, x7, caps_toggle

    # Enter
    addi    x7, x0, 0x5A
    beq     x25, x7, do_enter

    # Backspace
    addi    x7, x0, 0x66
    beq     x25, x7, do_backspace

    # Tab
    addi    x7, x0, 0x0D
    beq     x25, x7, do_tab

    # Convert scan code to ASCII (x17=0 means unsupported)
    jal     x5, scan_to_ascii
    beq     x17, x0, main_loop

    jal     x5, put_char
    jal     x0, main_loop

no_key:
    jal     x5, blink_tick
    jal     x0, main_loop

on_e0:
    addi    x24, x0, 1
    jal     x0, main_loop

on_f0:
    addi    x23, x0, 1
    jal     x0, main_loop

shift_down:
    addi    x22, x0, 1
    jal     x0, main_loop

caps_toggle:
    xori    x26, x26, 1
    jal     x0, main_loop

do_enter:
    addi    x20, x0, 0
    addi    x21, x21, 1
    addi    x7, x0, 30
    bne     x21, x7, main_loop
    jal     x5, scroll_up
    addi    x21, x0, 29
    jal     x0, main_loop

do_backspace:
    # Move cursor backward one cell
    bne     x20, x0, bs_dec_col
    beq     x21, x0, main_loop
    bne     x21, x0, bs_prev_row
    # At (0,0): wrap to last cell
    addi    x21, x0, 29
    addi    x20, x0, 79
    jal     x0, bs_erase

bs_prev_row:
    addi    x21, x21, -1
    addi    x20, x0, 79
    jal     x0, bs_erase

bs_dec_col:
    addi    x20, x20, -1

bs_erase:
    addi    x17, x0, 0x20
    jal     x5, put_char_raw
    jal     x0, main_loop

do_tab:
    addi    x17, x0, 0x20
    jal     x5, put_char
    jal     x5, put_char
    jal     x5, put_char
    jal     x5, put_char
    jal     x0, main_loop

#################################################
# clear_screen
#################################################
clear_screen:
    addi    x12, x0, 0            # idx
    addi    x13, x0, 75
    slli    x13, x13, 5           # total cells = 2400
    addi    x14, x0, 0x20         # ' '

cs_loop:
    beq     x12, x13, cs_done
    slli    x15, x12, 2
    add     x16, x27, x15
    sw      x14, 0(x16)
    addi    x12, x12, 1
    jal     x0, cs_loop

cs_done:
    jalr    x0, x5, 0

#################################################
# scroll_up
# Shift rows [1..29] up to [0..28], clear last row
#################################################
scroll_up:
    addi    x12, x0, 0            # dst idx
    addi    x13, x0, 145
    slli    x13, x13, 4           # 2320 = 29*80

su_copy_loop:
    beq     x12, x13, su_clear_last
    addi    x14, x12, 80          # src idx = dst + 80

    slli    x15, x12, 2           # dst byte offset
    slli    x16, x14, 2           # src byte offset

    add     x18, x27, x16         # src addr
    lw      x19, 0(x18)
    add     x18, x27, x15         # dst addr
    sw      x19, 0(x18)

    addi    x12, x12, 1
    jal     x0, su_copy_loop

su_clear_last:
    addi    x14, x0, 0x20         # ' '
    addi    x13, x0, 75
    slli    x13, x13, 5           # 2400

su_clear_loop:
    beq     x12, x13, su_done
    slli    x15, x12, 2
    add     x16, x27, x15
    sw      x14, 0(x16)
    addi    x12, x12, 1
    jal     x0, su_clear_loop

su_done:
    jalr    x0, x5, 0

#################################################
# draw_title
#################################################
draw_title:
    add     x2, x27, x0

    addi    x3, x0, 0x54   # T
    sw      x3, 0(x2)
    addi    x3, x0, 0x79   # y
    sw      x3, 4(x2)
    addi    x3, x0, 0x70   # p
    sw      x3, 8(x2)
    addi    x3, x0, 0x65   # e
    sw      x3, 12(x2)
    addi    x3, x0, 0x3A   # :
    sw      x3, 16(x2)
    addi    x3, x0, 0x20   # ' '
    sw      x3, 20(x2)

    # Start typing area from row 1, col 0
    addi    x21, x0, 1
    addi    x20, x0, 0

    jalr    x0, x5, 0

#################################################
# cursor_show / cursor_hide / blink_tick
#################################################
cursor_show:
    # idx = row*80 + col = row*64 + row*16 + col
    slli    x10, x21, 6
    slli    x11, x21, 4
    add     x10, x10, x11
    add     x10, x10, x20
    slli    x10, x10, 2
    add     x10, x27, x10

    addi    x17, x0, 0x5F         # '_'
    sw      x17, 0(x10)
    addi    x4, x0, 1
    addi    x1, x0, 0
    jalr    x0, x5, 0

cursor_hide:
    slli    x10, x21, 6
    slli    x11, x21, 4
    add     x10, x10, x11
    add     x10, x10, x20
    slli    x10, x10, 2
    add     x10, x27, x10

    addi    x17, x0, 0x20         # ' '
    sw      x17, 0(x10)
    addi    x4, x0, 0
    addi    x1, x0, 0
    jalr    x0, x5, 0

blink_tick:
    addi    x1, x1, 1
    addi    x7, x0, 1
    slli    x7, x7, 22            # blink period threshold
    bne     x1, x7, bt_done
    addi    x1, x0, 0

    beq     x4, x0, bt_turn_on

    # turn off cursor
    slli    x10, x21, 6
    slli    x11, x21, 4
    add     x10, x10, x11
    add     x10, x10, x20
    slli    x10, x10, 2
    add     x10, x27, x10
    addi    x17, x0, 0x20
    sw      x17, 0(x10)
    addi    x4, x0, 0
    jal     x0, bt_done

bt_turn_on:
    slli    x10, x21, 6
    slli    x11, x21, 4
    add     x10, x10, x11
    add     x10, x10, x20
    slli    x10, x10, 2
    add     x10, x27, x10
    addi    x17, x0, 0x5F
    sw      x17, 0(x10)
    addi    x4, x0, 1

bt_done:
    jalr    x0, x5, 0

#################################################
# put_char_raw
# input: x17 ascii
#################################################
put_char_raw:
    # idx = row*80 + col = row*64 + row*16 + col
    slli    x10, x21, 6
    slli    x11, x21, 4
    add     x10, x10, x11
    add     x10, x10, x20

    # byte offset = idx*4
    slli    x10, x10, 2
    add     x10, x27, x10

    sw      x17, 0(x10)
    jalr    x0, x5, 0

#################################################
# put_char
# input: x17 ascii
#################################################
put_char:
    # Inline write to avoid clobbering caller return address (x5)
    # idx = row*80 + col = row*64 + row*16 + col
    slli    x10, x21, 6
    slli    x11, x21, 4
    add     x10, x10, x11
    add     x10, x10, x20

    # byte offset = idx*4
    slli    x10, x10, 2
    add     x10, x27, x10

    sw      x17, 0(x10)

    # advance cursor
    addi    x20, x20, 1
    addi    x7, x0, 80
    bne     x20, x7, pc_done

    addi    x20, x0, 0
    addi    x21, x21, 1
    addi    x7, x0, 30
    bne     x21, x7, pc_done
    jal     x5, scroll_up
    addi    x21, x0, 29

pc_done:
    jalr    x0, x5, 0

#################################################
# scan_to_ascii
# input : x25 scan code, x22 shift flag
# output: x17 ascii (0 if unsupported)
#################################################
scan_to_ascii:
    addi    x17, x0, 0

    # Space
    addi    x8, x0, 0x29
    bne     x25, x8, map_letters
    addi    x17, x0, 0x20
    jalr    x0, x5, 0

map_letters:
    # a-z (lowercase base)
    addi    x8, x0, 0x1C
    bne     x25, x8, m_b
    addi    x17, x0, 0x61
    jal     x0, maybe_upper
m_b:
    addi    x8, x0, 0x32
    bne     x25, x8, m_c
    addi    x17, x0, 0x62
    jal     x0, maybe_upper
m_c:
    addi    x8, x0, 0x21
    bne     x25, x8, m_d
    addi    x17, x0, 0x63
    jal     x0, maybe_upper
m_d:
    addi    x8, x0, 0x23
    bne     x25, x8, m_e
    addi    x17, x0, 0x64
    jal     x0, maybe_upper
m_e:
    addi    x8, x0, 0x24
    bne     x25, x8, m_f
    addi    x17, x0, 0x65
    jal     x0, maybe_upper
m_f:
    addi    x8, x0, 0x2B
    bne     x25, x8, m_g
    addi    x17, x0, 0x66
    jal     x0, maybe_upper
m_g:
    addi    x8, x0, 0x34
    bne     x25, x8, m_h
    addi    x17, x0, 0x67
    jal     x0, maybe_upper
m_h:
    addi    x8, x0, 0x33
    bne     x25, x8, m_i
    addi    x17, x0, 0x68
    jal     x0, maybe_upper
m_i:
    addi    x8, x0, 0x43
    bne     x25, x8, m_j
    addi    x17, x0, 0x69
    jal     x0, maybe_upper
m_j:
    addi    x8, x0, 0x3B
    bne     x25, x8, m_k
    addi    x17, x0, 0x6A
    jal     x0, maybe_upper
m_k:
    addi    x8, x0, 0x42
    bne     x25, x8, m_l
    addi    x17, x0, 0x6B
    jal     x0, maybe_upper
m_l:
    addi    x8, x0, 0x4B
    bne     x25, x8, m_m
    addi    x17, x0, 0x6C
    jal     x0, maybe_upper
m_m:
    addi    x8, x0, 0x3A
    bne     x25, x8, m_n
    addi    x17, x0, 0x6D
    jal     x0, maybe_upper
m_n:
    addi    x8, x0, 0x31
    bne     x25, x8, m_o
    addi    x17, x0, 0x6E
    jal     x0, maybe_upper
m_o:
    addi    x8, x0, 0x44
    bne     x25, x8, m_p
    addi    x17, x0, 0x6F
    jal     x0, maybe_upper
m_p:
    addi    x8, x0, 0x4D
    bne     x25, x8, m_q
    addi    x17, x0, 0x70
    jal     x0, maybe_upper
m_q:
    addi    x8, x0, 0x15
    bne     x25, x8, m_r
    addi    x17, x0, 0x71
    jal     x0, maybe_upper
m_r:
    addi    x8, x0, 0x2D
    bne     x25, x8, m_s
    addi    x17, x0, 0x72
    jal     x0, maybe_upper
m_s:
    addi    x8, x0, 0x1B
    bne     x25, x8, m_t
    addi    x17, x0, 0x73
    jal     x0, maybe_upper
m_t:
    addi    x8, x0, 0x2C
    bne     x25, x8, m_u
    addi    x17, x0, 0x74
    jal     x0, maybe_upper
m_u:
    addi    x8, x0, 0x3C
    bne     x25, x8, m_v
    addi    x17, x0, 0x75
    jal     x0, maybe_upper
m_v:
    addi    x8, x0, 0x2A
    bne     x25, x8, m_w
    addi    x17, x0, 0x76
    jal     x0, maybe_upper
m_w:
    addi    x8, x0, 0x1D
    bne     x25, x8, m_x
    addi    x17, x0, 0x77
    jal     x0, maybe_upper
m_x:
    addi    x8, x0, 0x22
    bne     x25, x8, m_y
    addi    x17, x0, 0x78
    jal     x0, maybe_upper
m_y:
    addi    x8, x0, 0x35
    bne     x25, x8, m_z
    addi    x17, x0, 0x79
    jal     x0, maybe_upper
m_z:
    addi    x8, x0, 0x1A
    bne     x25, x8, map_other
    addi    x17, x0, 0x7A
    jal     x0, maybe_upper

map_other:
    # Digits / punctuation (shift-dependent)
    beq     x22, x0, map_unshift
    jal     x0, map_shift

maybe_upper:
    beq     x22, x26, st_done      # uppercase only when shift XOR caps is 1
    addi    x17, x17, -32
st_done:
    jalr    x0, x5, 0

map_unshift:
    addi    x8, x0, 0x45    # 0
    bne     x25, x8, u_1
    addi    x17, x0, 0x30
    jalr    x0, x5, 0
u_1:
    addi    x8, x0, 0x16
    bne     x25, x8, u_2
    addi    x17, x0, 0x31
    jalr    x0, x5, 0
u_2:
    addi    x8, x0, 0x1E
    bne     x25, x8, u_3
    addi    x17, x0, 0x32
    jalr    x0, x5, 0
u_3:
    addi    x8, x0, 0x26
    bne     x25, x8, u_4
    addi    x17, x0, 0x33
    jalr    x0, x5, 0
u_4:
    addi    x8, x0, 0x25
    bne     x25, x8, u_5
    addi    x17, x0, 0x34
    jalr    x0, x5, 0
u_5:
    addi    x8, x0, 0x2E
    bne     x25, x8, u_6
    addi    x17, x0, 0x35
    jalr    x0, x5, 0
u_6:
    addi    x8, x0, 0x36
    bne     x25, x8, u_7
    addi    x17, x0, 0x36
    jalr    x0, x5, 0
u_7:
    addi    x8, x0, 0x3D
    bne     x25, x8, u_8
    addi    x17, x0, 0x37
    jalr    x0, x5, 0
u_8:
    addi    x8, x0, 0x3E
    bne     x25, x8, u_9
    addi    x17, x0, 0x38
    jalr    x0, x5, 0
u_9:
    addi    x8, x0, 0x46
    bne     x25, x8, u_grave
    addi    x17, x0, 0x39
    jalr    x0, x5, 0
u_grave:
    addi    x8, x0, 0x0E
    bne     x25, x8, u_minus
    addi    x17, x0, 0x60
    jalr    x0, x5, 0
u_minus:
    addi    x8, x0, 0x4E
    bne     x25, x8, u_equal
    addi    x17, x0, 0x2D
    jalr    x0, x5, 0
u_equal:
    addi    x8, x0, 0x55
    bne     x25, x8, u_lbr
    addi    x17, x0, 0x3D
    jalr    x0, x5, 0
u_lbr:
    addi    x8, x0, 0x54
    bne     x25, x8, u_rbr
    addi    x17, x0, 0x5B
    jalr    x0, x5, 0
u_rbr:
    addi    x8, x0, 0x5B
    bne     x25, x8, u_bsl
    addi    x17, x0, 0x5D
    jalr    x0, x5, 0
u_bsl:
    addi    x8, x0, 0x5D
    bne     x25, x8, u_semi
    addi    x17, x0, 0x5C
    jalr    x0, x5, 0
u_semi:
    addi    x8, x0, 0x4C
    bne     x25, x8, u_quote
    addi    x17, x0, 0x3B
    jalr    x0, x5, 0
u_quote:
    addi    x8, x0, 0x52
    bne     x25, x8, u_comma
    addi    x17, x0, 0x27
    jalr    x0, x5, 0
u_comma:
    addi    x8, x0, 0x41
    bne     x25, x8, u_dot
    addi    x17, x0, 0x2C
    jalr    x0, x5, 0
u_dot:
    addi    x8, x0, 0x49
    bne     x25, x8, u_slash
    addi    x17, x0, 0x2E
    jalr    x0, x5, 0
u_slash:
    addi    x8, x0, 0x4A
    bne     x25, x8, u_none
    addi    x17, x0, 0x2F
    jalr    x0, x5, 0
u_none:
    addi    x17, x0, 0
    jalr    x0, x5, 0

map_shift:
    addi    x8, x0, 0x45    # )
    bne     x25, x8, s_1
    addi    x17, x0, 0x29
    jalr    x0, x5, 0
s_1:
    addi    x8, x0, 0x16
    bne     x25, x8, s_2
    addi    x17, x0, 0x21
    jalr    x0, x5, 0
s_2:
    addi    x8, x0, 0x1E
    bne     x25, x8, s_3
    addi    x17, x0, 0x40
    jalr    x0, x5, 0
s_3:
    addi    x8, x0, 0x26
    bne     x25, x8, s_4
    addi    x17, x0, 0x23
    jalr    x0, x5, 0
s_4:
    addi    x8, x0, 0x25
    bne     x25, x8, s_5
    addi    x17, x0, 0x24
    jalr    x0, x5, 0
s_5:
    addi    x8, x0, 0x2E
    bne     x25, x8, s_6
    addi    x17, x0, 0x25
    jalr    x0, x5, 0
s_6:
    addi    x8, x0, 0x36
    bne     x25, x8, s_7
    addi    x17, x0, 0x5E
    jalr    x0, x5, 0
s_7:
    addi    x8, x0, 0x3D
    bne     x25, x8, s_8
    addi    x17, x0, 0x26
    jalr    x0, x5, 0
s_8:
    addi    x8, x0, 0x3E
    bne     x25, x8, s_9
    addi    x17, x0, 0x2A
    jalr    x0, x5, 0
s_9:
    addi    x8, x0, 0x46
    bne     x25, x8, s_grave
    addi    x17, x0, 0x28
    jalr    x0, x5, 0
s_grave:
    addi    x8, x0, 0x0E
    bne     x25, x8, s_minus
    addi    x17, x0, 0x7E
    jalr    x0, x5, 0
s_minus:
    addi    x8, x0, 0x4E
    bne     x25, x8, s_equal
    addi    x17, x0, 0x5F
    jalr    x0, x5, 0
s_equal:
    addi    x8, x0, 0x55
    bne     x25, x8, s_lbr
    addi    x17, x0, 0x2B
    jalr    x0, x5, 0
s_lbr:
    addi    x8, x0, 0x54
    bne     x25, x8, s_rbr
    addi    x17, x0, 0x7B
    jalr    x0, x5, 0
s_rbr:
    addi    x8, x0, 0x5B
    bne     x25, x8, s_bsl
    addi    x17, x0, 0x7D
    jalr    x0, x5, 0
s_bsl:
    addi    x8, x0, 0x5D
    bne     x25, x8, s_semi
    addi    x17, x0, 0x7C
    jalr    x0, x5, 0
s_semi:
    addi    x8, x0, 0x4C
    bne     x25, x8, s_quote
    addi    x17, x0, 0x3A
    jalr    x0, x5, 0
s_quote:
    addi    x8, x0, 0x52
    bne     x25, x8, s_comma
    addi    x17, x0, 0x22
    jalr    x0, x5, 0
s_comma:
    addi    x8, x0, 0x41
    bne     x25, x8, s_dot
    addi    x17, x0, 0x3C
    jalr    x0, x5, 0
s_dot:
    addi    x8, x0, 0x49
    bne     x25, x8, s_slash
    addi    x17, x0, 0x3E
    jalr    x0, x5, 0
s_slash:
    addi    x8, x0, 0x4A
    bne     x25, x8, s_none
    addi    x17, x0, 0x3F
    jalr    x0, x5, 0
s_none:
    addi    x17, x0, 0
    jalr    x0, x5, 0
