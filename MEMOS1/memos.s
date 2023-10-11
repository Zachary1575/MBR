# Some Directives
.code16
.section .bss
	stack_buffer: .space 0x4000 # 16KB for stack space

.section .data
	buffer: .space 24 # Buffer for 0xE820, OSDev reccommends 24 bytes...


.section .text
.global _start

_start:
	# We setup a stack useful for function calls when printing...
	# I defined the stack segment to be at the edge of Free RAM at
	# the memory address 0x7FFFF
	# Hence, we set the stack segment at 0x7FFFF
	movw $0x7, %ax # 0x7 * 16 = 0x70 -> Our Segment
	movw %ax, %ss
	xorw %sp, %sp # Clear Stack pointer
	movw $0xFFFF, %sp # 0x70 + 0xFFFF = 0x7FFFF -> Our Segment + Offset
	
	# BIOS Memory Map Probe
	# I think you can't do arithmetic ops on segment pointers...
	
	# Clearing the 32 bit registers, but keep in mind we are in 16 bit mode
	# Clear EBX register
	xorw %bx, %bx

	# Clear EDX register
	xorw %dx, %dx

	# Clear EAX register
	xorw %ax, %ax

	# PURE WRITING
	movw $0xB800, %ax
	movw %ax, %es
	movw $0x07E1, %es:(0)

	# PRINTING A CHARACTER 'A' in BIOS
	movb $0x03, %ah
	xor %al, %al
	int $0x10

	movb $0x02, %ah
	xor %bh, %bh
	xor %dh, %dh
	xor %dl, %dl
	int $0x10

	movb $'A', %al
	movb $0x0E, %ah
	movw $0x0007, %bx
	int $0x10
	
halt:
	hlt
	jmp halt

	# Master Boot Record Signature
	.org 0x1FE

	.byte 0x55
	.byte 0xAA
