#################################################
# Fibonacci with keyboard input + VGA display
#
# MMIO map (canonical)
#   0xFFFF_0010 : keyboard data
#   0xFFFF_0014 : keyboard status (bit0 = ready)
#   0xFFFF_0020 : VGA text buffer base (word-addressed)
#
# Input: decimal n from keyboard (0..31)
# Keys : digit 0-9, Enter(0x5A) to compute, Backspace(0x66) to delete
# PS/2 set2 break sequence (F0 xx) is ignored
#
# Display:
#   Row0: "Input n(0-31): _"
#   Row1: "n=__ , fib=0x________" (fib field blank initially)
#################################################

    lui     x31, 0xFFFF0
    addi    x30, x31, 0x0020      # VGA base
    addi    x29, x31, 0x0014      # KBD status
    addi    x28, x31, 0x0010      # KBD data

    addi    x20, x0, 0            # n value
    addi    x21, x0, 0            # has_digit flag
    addi    x22, x0, 0            # break_pending flag

    jal     x5, draw_static

main_loop:
    # Poll keyboard ready bit
    lw      x6, 0(x29)
    andi    x6, x6, 0x1
    beq     x6, x0, main_loop

    # Read scan code (this also acks key_read in hardware)
    lw      x6, 0(x28)

    # Handle break prefix F0
    addi    x7, x0, 0xF0
    beq     x6, x7, set_break

    # If previous byte was F0, skip this release code
    beq     x22, x0, check_special
    addi    x22, x0, 0
    jal     x0, main_loop

check_special:
    # Enter key (make code 5A)
    addi    x7, x0, 0x5A
    beq     x6, x7, on_enter

    # Backspace key (make code 66)
    addi    x7, x0, 0x66
    beq     x6, x7, on_backspace

    # Convert scan code to digit
    jal     x5, scan_to_digit
    addi    x8, x0, 0xFF
    beq     x7, x8, main_loop      # not a digit

    # n_new = n*10 + digit
    slli    x8, x20, 3             # n*8
    slli    x9, x20, 1             # n*2
    add     x8, x8, x9             # n*10
    add     x8, x8, x7             # n*10 + digit

    # Keep n in [0,31]
    slti    x9, x8, 32
    beq     x9, x0, main_loop

    add     x20, x8, x0
    addi    x21, x0, 1
    jal     x5, draw_n_field
    jal     x0, main_loop

set_break:
    addi    x22, x0, 1
    jal     x0, main_loop

on_backspace:
    beq     x21, x0, main_loop

    # n = n / 10 using repeated subtraction
    addi    x23, x0, 0             # quotient
    add     x24, x20, x0           # remainder working value
bs_div10_loop:
    slti    x25, x24, 10
    bne     x25, x0, bs_div10_done
    addi    x24, x24, -10
    addi    x23, x23, 1
    jal     x0, bs_div10_loop
bs_div10_done:
    add     x20, x23, x0

    # Update has_digit
    slti    x25, x20, 1
    beq     x25, x0, bs_keep_digit
    addi    x21, x0, 0
bs_keep_digit:
    jal     x5, draw_n_field
    jal     x0, main_loop

on_enter:
    beq     x21, x0, main_loop

    # fib_iter input: x6=n, output: x7=fib(n)
    add     x6, x20, x0
    jal     x5, fib_iter
    jal     x5, draw_result_hex

    # Also mirror result to SEG7 for quick board debug
    sw      x7, 0x000C(x31)

    jal     x0, main_loop

#################################################
# draw_static
# Draw fixed labels and initialize dynamic fields
#################################################
draw_static:
    # Row0 base: x30 + 0x000
    add     x2, x30, x0

    # "Input n(0-31): _"
    addi    x3, x0, 0x49   # I
    sw      x3, 0(x2)
    addi    x3, x0, 0x6E   # n
    sw      x3, 4(x2)
    addi    x3, x0, 0x70   # p
    sw      x3, 8(x2)
    addi    x3, x0, 0x75   # u
    sw      x3, 12(x2)
    addi    x3, x0, 0x74   # t
    sw      x3, 16(x2)
    addi    x3, x0, 0x20   # space
    sw      x3, 20(x2)
    addi    x3, x0, 0x6E   # n
    sw      x3, 24(x2)
    addi    x3, x0, 0x28   # (
    sw      x3, 28(x2)
    addi    x3, x0, 0x30   # 0
    sw      x3, 32(x2)
    addi    x3, x0, 0x2D   # -
    sw      x3, 36(x2)
    addi    x3, x0, 0x33   # 3
    sw      x3, 40(x2)
    addi    x3, x0, 0x31   # 1
    sw      x3, 44(x2)
    addi    x3, x0, 0x29   # )
    sw      x3, 48(x2)
    addi    x3, x0, 0x3A   # :
    sw      x3, 52(x2)
    addi    x3, x0, 0x20   # space
    sw      x3, 56(x2)
    addi    x3, x0, 0x5F   # _
    sw      x3, 60(x2)

    # Row1 base: x30 + 0x140
    addi    x2, x30, 0x0140

    # "n=__ , fib=0x________"
    addi    x3, x0, 0x6E   # n
    sw      x3, 0(x2)
    addi    x3, x0, 0x3D   # =
    sw      x3, 4(x2)
    addi    x3, x0, 0x20   # space
    sw      x3, 8(x2)
    sw      x3, 12(x2)
    sw      x3, 16(x2)
    addi    x3, x0, 0x2C   # ,
    sw      x3, 20(x2)
    addi    x3, x0, 0x20   # space
    sw      x3, 24(x2)
    addi    x3, x0, 0x66   # f
    sw      x3, 28(x2)
    addi    x3, x0, 0x69   # i
    sw      x3, 32(x2)
    addi    x3, x0, 0x62   # b
    sw      x3, 36(x2)
    addi    x3, x0, 0x3D   # =
    sw      x3, 40(x2)
    addi    x3, x0, 0x30   # 0
    sw      x3, 44(x2)
    addi    x3, x0, 0x78   # x
    sw      x3, 48(x2)

    # Initialize 8 hex digits to spaces
    addi    x3, x0, 0x20
    sw      x3, 52(x2)
    sw      x3, 56(x2)
    sw      x3, 60(x2)
    sw      x3, 64(x2)
    sw      x3, 68(x2)
    sw      x3, 72(x2)
    sw      x3, 76(x2)
    sw      x3, 80(x2)

    jalr    x0, x5, 0

#################################################
# draw_n_field
# Show n as two decimal chars at row1 offsets 8,12
#################################################
draw_n_field:
    addi    x9, x0, 0x20           # tens default ' '
    addi    x10, x20, 0x30         # ones default

    slti    x4, x20, 10
    bne     x4, x0, n_draw_done
    slti    x4, x20, 20
    bne     x4, x0, n_draw_10
    slti    x4, x20, 30
    bne     x4, x0, n_draw_20

    addi    x9, x0, 0x33           # '3'
    addi    x10, x20, 18           # n-30+'0'
    jal     x0, n_draw_done

n_draw_20:
    addi    x9, x0, 0x32           # '2'
    addi    x10, x20, 28           # n-20+'0'
    jal     x0, n_draw_done

n_draw_10:
    addi    x9, x0, 0x31           # '1'
    addi    x10, x20, 38           # n-10+'0'

n_draw_done:
    addi    x2, x30, 0x0140
    sw      x9, 8(x2)
    sw      x10, 12(x2)
    jalr    x0, x5, 0

#################################################
# draw_result_hex
# Input : x7 = fib(n)
# Output: row1 offsets 52..80 updated
#################################################
draw_result_hex:
    addi    x2, x30, 0x0140

    srli    x8, x7, 28
    andi    x8, x8, 0x0F
    addi    x3, x8, 0x30
    slti    x4, x8, 10
    bne     x4, x0, rh1
    addi    x3, x3, 7
rh1:
    sw      x3, 52(x2)

    srli    x8, x7, 24
    andi    x8, x8, 0x0F
    addi    x3, x8, 0x30
    slti    x4, x8, 10
    bne     x4, x0, rh2
    addi    x3, x3, 7
rh2:
    sw      x3, 56(x2)

    srli    x8, x7, 20
    andi    x8, x8, 0x0F
    addi    x3, x8, 0x30
    slti    x4, x8, 10
    bne     x4, x0, rh3
    addi    x3, x3, 7
rh3:
    sw      x3, 60(x2)

    srli    x8, x7, 16
    andi    x8, x8, 0x0F
    addi    x3, x8, 0x30
    slti    x4, x8, 10
    bne     x4, x0, rh4
    addi    x3, x3, 7
rh4:
    sw      x3, 64(x2)

    srli    x8, x7, 12
    andi    x8, x8, 0x0F
    addi    x3, x8, 0x30
    slti    x4, x8, 10
    bne     x4, x0, rh5
    addi    x3, x3, 7
rh5:
    sw      x3, 68(x2)

    srli    x8, x7, 8
    andi    x8, x8, 0x0F
    addi    x3, x8, 0x30
    slti    x4, x8, 10
    bne     x4, x0, rh6
    addi    x3, x3, 7
rh6:
    sw      x3, 72(x2)

    srli    x8, x7, 4
    andi    x8, x8, 0x0F
    addi    x3, x8, 0x30
    slti    x4, x8, 10
    bne     x4, x0, rh7
    addi    x3, x3, 7
rh7:
    sw      x3, 76(x2)

    andi    x8, x7, 0x0F
    addi    x3, x8, 0x30
    slti    x4, x8, 10
    bne     x4, x0, rh8
    addi    x3, x3, 7
rh8:
    sw      x3, 80(x2)

    jalr    x0, x5, 0

#################################################
# scan_to_digit
# Input : x6 = PS/2 set2 scan code (make code)
# Output: x7 = digit(0..9), or 0xFF if invalid
#################################################
scan_to_digit:
    addi    x7, x0, 0xFF

    addi    x8, x0, 0x45   # '0'
    bne     x6, x8, sd1
    addi    x7, x0, 0
    jalr    x0, x5, 0
sd1:
    addi    x8, x0, 0x16   # '1'
    bne     x6, x8, sd2
    addi    x7, x0, 1
    jalr    x0, x5, 0
sd2:
    addi    x8, x0, 0x1E   # '2'
    bne     x6, x8, sd3
    addi    x7, x0, 2
    jalr    x0, x5, 0
sd3:
    addi    x8, x0, 0x26   # '3'
    bne     x6, x8, sd4
    addi    x7, x0, 3
    jalr    x0, x5, 0
sd4:
    addi    x8, x0, 0x25   # '4'
    bne     x6, x8, sd5
    addi    x7, x0, 4
    jalr    x0, x5, 0
sd5:
    addi    x8, x0, 0x2E   # '5'
    bne     x6, x8, sd6
    addi    x7, x0, 5
    jalr    x0, x5, 0
sd6:
    addi    x8, x0, 0x36   # '6'
    bne     x6, x8, sd7
    addi    x7, x0, 6
    jalr    x0, x5, 0
sd7:
    addi    x8, x0, 0x3D   # '7'
    bne     x6, x8, sd8
    addi    x7, x0, 7
    jalr    x0, x5, 0
sd8:
    addi    x8, x0, 0x3E   # '8'
    bne     x6, x8, sd9
    addi    x7, x0, 8
    jalr    x0, x5, 0
sd9:
    addi    x8, x0, 0x46   # '9'
    bne     x6, x8, sd_end
    addi    x7, x0, 9
sd_end:
    jalr    x0, x5, 0

#################################################
# fib_iter
# Input : x6 = n (0..31)
# Output: x7 = fib(n)
#################################################
fib_iter:
    beq     x6, x0, fib_n0

    addi    x8, x0, 1
    beq     x6, x8, fib_n1

    addi    x9, x0, 0      # a = 0
    addi    x10, x0, 1     # b = 1
    addi    x11, x0, 2     # i = 2
fib_loop:
    slt     x12, x6, x11   # if n < i -> done
    bne     x12, x0, fib_done

    add     x13, x9, x10   # t = a + b
    add     x9, x10, x0    # a = b
    add     x10, x13, x0   # b = t
    addi    x11, x11, 1
    jal     x0, fib_loop

fib_done:
    add     x7, x10, x0
    jalr    x0, x5, 0

fib_n0:
    addi    x7, x0, 0
    jalr    x0, x5, 0

fib_n1:
    addi    x7, x0, 1
    jalr    x0, x5, 0
