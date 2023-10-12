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

	# While we are at it, lets clear the DS register
	movw %ax, %ds

	# WRITING A CHARACTER "A" in BIOS
	mov $0x0e41, %ax
	xorw %bx, %bx
	int $0x10 # BIOS Video Interrupt
	
halt:
	hlt
	jmp halt

	# Master Boot Record Signature
	.space 510 - (. - _start) # Pad until we slap the sig in the back

	.byte 0x55
	.byte 0xAA
