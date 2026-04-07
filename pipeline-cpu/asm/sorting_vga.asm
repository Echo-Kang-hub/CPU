#############################################
# C program for sorting the student no.
#############################################
#   sortedstuno = stuno;
#   mask0 = 0x0f; 
#   for (int i= 0; i < 8; i++) {
#       a = sortedstuno & mask0;
#       a = a >> (4 * i);
#       mask1 = mask0 << 4; 
#       bestj = i;
#       tmpMax = a; 
#		for (int j = i + 1; j < 8) {
#       	b = sortedstuno & mask1;
#       	b = b >> (4 * j);
#       	if (tmpMax < b) {
#          		tmpMax = b;
#          		bestj = j;
#       	}
#       	mask1 = mask1 << 4;
#     	}
#     	if (a < tmpMax) {
#         	mask1 = 0x0f;
#         	bestj4 = bestj << 2;
#         	mask1 = mask1 << bestj4
#         	mask2 = mask0 | mask1;
#         	mask2 = ~mask2;
#         	sortedstuno = sortedstuno & mask2;
#         	tmpMax = tmpMax << (4 * i);
#         	sortedstuno = sortedstuno | tmpMax;
#         	a = a << bestj4;
#         	sortedstuno = sortedstuno | a;
#       }
#     	mask0 = mask0 << 4;
#   }
#############################################
# VGA display version
# Display both original and sorted student no.
#############################################
# mem[0], student no.
# mem[4], sorted student no
# x15, partially sorted student number
# x1, temp
# x2, outer loop i / temp
# x3, inner loop j / temp
# x4, mask0
# x5, mask1
# x6, mask2
# x7, a
# x8, b
# x9, 4 * i
# x10, 4 * j
# x11, N = 8
# x12, bestj
# x13, tmpMax
# x14, compare result
# x30, VGA base address 0xFFFF0020
#############################################

	lui		x30, 0xFFFF2

	# Set student number
	addi	x2, x0, 0x16
	slli	x2, x2, 8
	addi	x2, x2, 0x11
	slli	x2, x2, 16
	addi	x3, x0, 0x11
	slli	x3, x3, 8
	addi	x3, x3, 0x02
	add		x2, x2, x3

	sw		x2, 0(x0)
	addi	x11, x0, 8
	lw		x15, 0(x0)
	add		x2, x0, x0
	addi	x4, x0, 0x0f

loop1:
	and		x7, x15, x4
	slli	x9, x2, 2
	srl		x7, x7, x9
	slli	x5, x4, 4
	add		x12, x2, x0
	add		x13, x7, x0
	addi	x3, x2, 1

loop2:
	beq		x3, x11, checkswap
	and		x8, x15, x5
	slli	x10, x3, 2
	srl		x8, x8, x10
	slt		x14, x13, x8
	beq		x14, x0, incrLoop2
	add		x13, x8, x0
	add		x12, x3, x0

incrLoop2:
	slli	x5, x5, 4
	addi	x3, x3, 1
	jal		x0, loop2

checkswap:
	slt		x14, x2, x12
	beq		x14, x0, incrLoop1
	jal		x1, swap

incrLoop1:
	slli	x4, x4, 4
	addi	x2, x2, 1
	bne		x2, x11, loop1

result:
	sw		x15, 4(x0)

	# Display on VGA: row 0 - original, row 1 - sorted
	# Row 0: "Original: 0x"
	lui		x2, 0xFFFF2
	
	# 'O'
	addi	x3, x0, 0x4F
	sw		x3, 0(x2)
	# 'r'
	addi	x3, x0, 0x72
	sw		x3, 4(x2)
	# 'i'
	addi	x3, x0, 0x69
	sw		x3, 8(x2)
	# 'g'
	addi	x3, x0, 0x67
	sw		x3, 12(x2)
	# 'i'
	addi	x3, x0, 0x69
	sw		x3, 16(x2)
	# 'n'
	addi	x3, x0, 0x6E
	sw		x3, 20(x2)
	# 'a'
	addi	x3, x0, 0x61
	sw		x3, 24(x2)
	# 'l'
	addi	x3, x0, 0x6C
	sw		x3, 28(x2)
	# ':'
	addi	x3, x0, 0x3A
	sw		x3, 32(x2)
	# ' '
	addi	x3, x0, 0x20
	sw		x3, 36(x2)
	# '0'
	addi	x3, x0, 0x30
	sw		x3, 40(x2)
	# 'x'
	addi	x3, x0, 0x78
	sw		x3, 44(x2)

	# Display original student no (8 hex digits) at row 0
	lw		x8, 0(x0)
	
	# Row 0, col 12+: hex digits
	srli	x9, x8, 28
	addi	x3, x9, 0x30
	slti	x4, x9, 10
	bne	x4, x0, orig_h1
	addi	x3, x3, 7
orig_h1:
	addi	x2, x30, 0x0040
	sw		x3, 0(x2)
	
	srli	x9, x8, 24
	and	x9, x9, 0x0F
	addi	x3, x9, 0x30
	slti	x4, x9, 10
	bne	x4, x0, orig_h2
	addi	x3, x3, 7
orig_h2:
	sw		x3, 4(x2)
	
	srli	x9, x8, 20
	and	x9, x9, 0x0F
	addi	x3, x9, 0x30
	slti	x4, x9, 10
	bne	x4, x0, orig_h3
	addi	x3, x3, 7
orig_h3:
	sw		x3, 8(x2)
	
	srli	x9, x8, 16
	and	x9, x9, 0x0F
	addi	x3, x9, 0x30
	slti	x4, x9, 10
	bne	x4, x0, orig_h4
	addi	x3, x3, 7
orig_h4:
	sw		x3, 12(x2)
	
	srli	x9, x8, 12
	and	x9, x9, 0x0F
	addi	x3, x9, 0x30
	slti	x4, x9, 10
	bne	x4, x0, orig_h5
	addi	x3, x3, 7
orig_h5:
	sw		x3, 16(x2)
	
	srli	x9, x8, 8
	and	x9, x9, 0x0F
	addi	x3, x9, 0x30
	slti	x4, x9, 10
	bne	x4, x0, orig_h6
	addi	x3, x3, 7
orig_h6:
	sw		x3, 20(x2)
	
	srli	x9, x8, 4
	and	x9, x9, 0x0F
	addi	x3, x9, 0x30
	slti	x4, x9, 10
	bne	x4, x0, orig_h7
	addi	x3, x3, 7
orig_h7:
	sw		x3, 24(x2)
	
	and	x9, x8, 0x0F
	addi	x3, x9, 0x30
	slti	x4, x9, 10
	bne	x4, x0, orig_h8
	addi	x3, x3, 7
orig_h8:
	sw		x3, 28(x2)

	# Row 2: "Sorted: 0x"
	lui		x2, 0xFFFF2
	
	addi	x3, x0, 0x53		# 'S'
	sw		x3, 0x0080(x2)
	addi	x3, x0, 0x6F		# 'o'
	sw		x3, 0x0084(x2)
	addi	x3, x0, 0x72		# 'r'
	sw		x3, 0x0088(x2)
	addi	x3, x0, 0x74		# 't'
	sw		x3, 0x008C(x2)
	addi	x3, x0, 0x65		# 'e'
	sw		x3, 0x0090(x2)
	addi	x3, x0, 0x64		# 'd'
	sw		x3, 0x0094(x2)
	addi	x3, x0, 0x3A		# ':'
	sw		x3, 0x0098(x2)
	addi	x3, x0, 0x20		# ' '
	sw		x3, 0x009C(x2)
	addi	x3, x0, 0x30		# '0'
	sw		x3, 0x00A0(x2)
	addi	x3, x0, 0x78		# 'x'
	sw		x3, 0x00A4(x2)

	# Display sorted student no at row 2
	lw		x8, 4(x0)
	
	addi	x2, x30, 0x00C0
	
	srli	x9, x8, 28
	addi	x3, x9, 0x30
	slti	x4, x9, 10
	bne	x4, x0, sorted_h1
	addi	x3, x3, 7
sorted_h1:
	sw		x3, 0(x2)
	
	srli	x9, x8, 24
	and	x9, x9, 0x0F
	addi	x3, x9, 0x30
	slti	x4, x9, 10
	bne	x4, x0, sorted_h2
	addi	x3, x3, 7
sorted_h2:
	sw		x3, 4(x2)
	
	srli	x9, x8, 20
	and	x9, x9, 0x0F
	addi	x3, x9, 0x30
	slti	x4, x9, 10
	bne	x4, x0, sorted_h3
	addi	x3, x3, 7
sorted_h3:
	sw		x3, 8(x2)
	
	srli	x9, x8, 16
	and	x9, x9, 0x0F
	addi	x3, x9, 0x30
	slti	x4, x9, 10
	bne	x4, x0, sorted_h4
	addi	x3, x3, 7
sorted_h4:
	sw		x3, 12(x2)
	
	srli	x9, x8, 12
	and	x9, x9, 0x0F
	addi	x3, x9, 0x30
	slti	x4, x9, 10
	bne	x4, x0, sorted_h5
	addi	x3, x3, 7
sorted_h5:
	sw		x3, 16(x2)
	
	srli	x9, x8, 8
	and	x9, x9, 0x0F
	addi	x3, x9, 0x30
	slti	x4, x9, 10
	bne	x4, x0, sorted_h6
	addi	x3, x3, 7
sorted_h6:
	sw		x3, 20(x2)
	
	srli	x9, x8, 4
	and	x9, x9, 0x0F
	addi	x3, x9, 0x30
	slti	x4, x9, 10
	bne	x4, x0, sorted_h7
	addi	x3, x3, 7
sorted_h7:
	sw		x3, 24(x2)
	
	and	x9, x8, 0x0F
	addi	x3, x9, 0x30
	slti	x4, x9, 10
	bne	x4, x0, sorted_h8
	addi	x3, x3, 7
sorted_h8:
	sw		x3, 28(x2)

display_loop:
	jal		x0, display_loop

############
# swap function
############
swap:
	addi	x5, x0, 0x0f
	slli	x10, x12, 2
	sll		x5, x5, x10
	or		x6, x4, x5
	xori	x6, x6, -1
	and		x15, x15, x6
	sll		x8, x13, x9
	or		x15, x15, x8
	sll		x7, x7, x10
	or		x15, x15, x7
	jalr	x0, x1, 0
