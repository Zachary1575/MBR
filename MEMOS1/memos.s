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
	movw %ax, %ss # Load the segment into the SEGMENT POINTERS (duh)
	xorw %sp, %sp # Clear Stack pointer
	movw $0xFFFF, %sp # 0x70 + 0xFFFF = 0x7FFFF -> Our Segment + Offset
	
	#============= PRINT INTRO function =============

	# First we load the effective address into the %si segment register
	leaw msg, %si # "Load Effective Address Word"
	movw msg_len, %cx # We need to decrement after each print
	
1:
	# lodsb automatically increments the %si register
	lodsb # Loads address in %si to %al (accumulator)
	movb $0x0E, %ah # %ah is used to set display attributes, $0x0E is B & W
	int $0x10 # BIOS interrupt, writes what is in AL
	loop 1b #'b' automatically decrements %cx until 0 (works only with #s)

	# ============ BIOS MEMORY MAP PROBE =============
	# Clear all the general purpose registers after the printing
	xorw %ax, %ax
	xorw %dx, %dx
	xorw %bx, %bx
	xorw %cx, %cx

	# BIOS Memory detection needs ES:DI registers so clear em
	movw %ax, %es
	movw %ax, %di
	
	# First, we load ES:DI with our buffer (24 bytes)
	# Assumes only the buffer here exists
	movw %ds, %ax # Load the segment in ax for es
	movw %ax, %es # Move that segment into the segment register %es
	leaw buffer, %di # We load the buffer offset address int %di

	# Load the magic number in EDX $0x534D4150
	movw $0x534D, %dx
	
	# Load the BIOS Memory Probe command into EAX
	movw $0xE820, %ax

	# Load 24 in the ECX, I assume counting the buffer length
	movw $24, %cx
	
	# Trigger BIOS function call
	int $0x15

	cmp $0x4153, %ax
	jne error

error:
	# We ran into an error in the bootloader!
	hlt
	jmp error

	# We halt the CPU
halt:
	hlt
	jmp halt

# ============== Functions & References ================
print:	
	pushw %dx # Save the return address onto DX Register
	movb %al, %dl # Move 8 lower bits of AL to DL

msg:
	.asciz "MemOS: Welcome *** System Memory is: "
msg_len:
	.word . - msg # The Message Length
msg_units:
	.asciz "MB"
msg_ulen:
	.word . - msg_ulen

	# Master Boot Record (MBR) Signature
	.space 510 - (. - _start) # Pad until we slap the sig in the back

	.byte 0x55
	.byte 0xAA
