#################################################
#	x1		stack pointer
#	x5		return addr
#	x6		n = SW[14:10]
#	x7		fib(n)
#	x31		0xFFFF0000
#################################################
#	Fibonacci with VGA display
#	Display format: "Fib(n) = result"
#################################################

	lui		x31, 0xFFFF0
	addi	x1, x0, -4

main:
	lw		x6, 0x004(x31)
	srli	x6, x6, 10
	andi	x6, x6, 0x01F
	jal		x5, fib
	
	# Display "Fib(n) = result" on VGA
	# 写入字符串到VGA显存
	# First row: "Fib(n) = "
	
	# 'F'
	addi	x2, x31, 0x0020
	addi	x3, x0, 0x46		# 'F'
	sw		x3, 0(x2)
	
	# 'i'
	addi	x2, x31, 0x0020
	addi	x3, x0, 0x69		# 'i'
	sw		x3, 4(x2)
	
	# 'b'
	addi	x2, x31, 0x0020
	addi	x3, x0, 0x62		# 'b'
	sw		x3, 8(x2)
	
	# Display n digit
	# Convert n to ASCII and display
	addi	x2, x31, 0x0020
	addi	x3, x6, 0x30		# n + '0'
	sw		x3, 12(x2)
	
	# ' '
	addi	x2, x31, 0x0020
	addi	x3, x0, 0x20		# ' '
	sw		x3, 16(x2)
	
	# '='
	addi	x2, x31, 0x0020
	addi	x3, x0, 0x3D		# '='
	sw		x3, 20(x2)
	
	# ' '
	addi	x2, x31, 0x0020
	addi	x3, x0, 0x20		# ' '
	sw		x3, 24(x2)
	
	# Display result (max 5 hex digits, but we display as hex)
	# Convert hex result to 2 hex characters
	srli	x8, x7, 28
	and	x8, x8, 0x0F
	addi	x2, x31, 0x0020
	addi	x3, x8, 0x30
	slti	x4, x8, 10
	bne	x4, x0, hex1
	addi	x3, x3, 7
hex1:
	sw	x3, 28(x2)
	
	srli	x8, x7, 24
	and	x8, x8, 0x0F
	addi	x2, x31, 0x0020
	addi	x3, x8, 0x30
	slti	x4, x8, 10
	bne	x4, x0, hex2
	addi	x3, x3, 7
hex2:
	sw	x3, 32(x2)
	
	srli	x8, x7, 20
	and	x8, x8, 0x0F
	addi	x2, x31, 0x0020
	addi	x3, x8, 0x30
	slti	x4, x8, 10
	bne	x4, x0, hex3
	addi	x3, x3, 7
hex3:
	sw	x3, 36(x2)
	
	srli	x8, x7, 16
	and	x8, x8, 0x0F
	addi	x2, x31, 0x0020
	addi	x3, x8, 0x30
	slti	x4, x8, 10
	bne	x4, x0, hex4
	addi	x3, x3, 7
hex4:
	sw	x3, 40(x2)
	
	srli	x8, x7, 12
	and	x8, x8, 0x0F
	addi	x2, x31, 0x0020
	addi	x3, x8, 0x30
	slti	x4, x8, 10
	bne	x4, x0, hex5
	addi	x3, x3, 7
hex5:
	sw	x3, 44(x2)
	
	srli	x8, x7, 8
	and	x8, x8, 0x0F
	addi	x2, x31, 0x0020
	addi	x3, x8, 0x30
	slti	x4, x8, 10
	bne	x4, x0, hex6
	addi	x3, x3, 7
hex6:
	sw	x3, 48(x2)
	
	srli	x8, x7, 4
	and	x8, x8, 0x0F
	addi	x2, x31, 0x0020
	addi	x3, x8, 0x30
	slti	x4, x8, 10
	bne	x4, x0, hex7
	addi	x3, x3, 7
hex7:
	sw	x3, 52(x2)
	
	and	x8, x7, 0x0F
	addi	x2, x31, 0x0020
	addi	x3, x8, 0x30
	slti	x4, x8, 10
	bne	x4, x0, hex8
	addi	x3, x3, 7
hex8:
	sw	x3, 56(x2)
	
	# Also output to seg7
	sw		x7, 0x00C(x31)
	jal		x0, main

fib:
	addi	x7, x0, 1
	bge		x7, x6, ret
	addi	x1, x1, -8
	sw		x5, 4(x1)
	addi	x6, x6, -1
	jal		x5, fib
	sw		x7, 0(x1)
	addi	x6, x6, -1
	jal		x5, fib
	lw		x8, 0(x1)
	add		x7, x7, x8
	addi	x6, x6, 2
	lw		x5, 4(x1)
	addi	x1, x1, 8
ret:
	jalr	x0, x5, 0
