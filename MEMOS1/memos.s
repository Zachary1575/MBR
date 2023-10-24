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
	#leaw msg, %si # "Load Effective Address Word"
	#movw msg_len, %cx # We need to decrement after each print
	
#1:
	#lodsb automatically increments the %si register
	#lodsb # Loads address in %si to %al (accumulator)
	#movb $0x0E, %ah # %ah is used to set display attributes, $0x0E is B & W
	#int $0x10 # BIOS interrupt, writes what is in AL
	#loop 1b #'b' automatically decrements %cx until 0 (works only with #s)

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
	.byte 0x66
	movl $0x0534D4150, %edx
	
	# Load the BIOS Memory Probe command into EAX
	.byte 0x66
	movl $0xe820, %eax

	# Load 24 in the ECX, I assume counting the buffer length
	movw $24, %cx
	
	# Trigger BIOS function call
	int $0x15
	
	.byte 0x66
	cmp $0x0534D4150, %eax # Check for SMAP returned in EAX
	jne error
	
	.byte 0x66
	testl %ebx, %ebx
	jz error # OSdev: ebx = 0 implies list is only 1 entry long (worthless)

	jmp jmpin

# ============= BIOS MEMORY COUNTING LOGIC ===============
memloop:
	.byte 0x66
	movl $0xe820, %eax # ecx gets trasged on every int 0x15 call
	movw $24, %cx
	int $0x15
	jc memfinish # We finished as carry flag has been set

jmpin:
	jcxz skipentry # Skip this current entry if cx is zero (no bytes)
	cmpb $0x14, %cl # See if cx register has 20 bytes
	je getmemlength

getmemlength:
	call printA # Prints "Address range["
	movl %es:0(%di), %ecx # Gets the base address of the memory block in map
	call print_32bit # This prints the 32 bit value of whats in %ecx
	call print_colon # Prints ":"
	
	# Calculating the end address
	.byte 0x66
	pushl %eax # Save the state of %eax
	movl %es:8(%di), %eax # Get the size of the memory page
	.byte 0x66
	addl %eax, %ecx # We calculated the end address
	call print_32bit
	.byte 0x66
	popl %eax # Pop back the state of the %eax register
	
	# Calculating the Status of memory page
	call printB
	xorl %ecx, %ecx # Clear the ecx register for status
	movw %es:16(%di), %cx # Get status of the memory page
	call print_32bit

	call print_newline # Prints new line!

	#movl %es:8(%di), %ecx # Get the lower uint32_t of memory region length
	#or %es:12(%di), %ecx
	


	inc %bp
	add $24, %di

skipentry:
	.byte 0x66
	testl %ebx, %ebx # if ebx resets to 0, the list is complete
	jne memloop

memfinish:
	jmp halt

# ============= ADDRESS PRINT FUNCTIONS =============

# Prints ':' using BIOS interrupts
print_colon:
	.byte 0x66
	pushl %eax
	
	movb $':', %al
	movb $0x0E, %ah
	int $0x10

	.byte 0x66
	popl %eax

	ret

# Prints '\n' or new line using BIOS interrupts
print_newline:
	.byte 0x66
	pushl %eax

	movb $0x0E, %ah
	
	movb $0x0D, %al # 0x0D: Carriage Return (CR)
	int $0x10

	movb $0x0A, %al # 0x0A: Line Feed (LF)
	int $0x10
	
	.byte 0x66
	popl %eax

	ret

# Prints out 32 bit hexadecimal values
print_32bit:
	.byte 0x66
	pushl %ecx
	.byte 0x66
	pushl %eax
	.byte 0x66
	pushl %ebx
	.byte 0x66
	pushl %edx

	movb $'0', %al
	movb $0x0E, %ah
	int $0x10

	movb $'x', %al
	movb $0x0E, %ah
	int $0x10

	.byte 0x66
	movl %ecx, %eax # Move the address from ecx to eax temporarily
	.byte 0x66
	xorl %ecx, %ecx
	movw $8, %cx # 8 hex digits to be printed

print_hex:
	# Rotate the left 4 bits to get the next nibble into lower 4 bits
	roll $4, %eax
	xorl %ebx, %ebx # Clear the EBX
	mov %al, %bl # Preserve the value in BL
	andb $0x0F, %bl # Mask out the upper 4 bits
	cmpb $9, %bl # Check if the nibble is 9 or less
	jbe print_digit # If it is 9 or less, print the digit
	addb $7, %bl # Convert to hex 'A' to 'F' if it's 10 to 15

print_digit:
	movl %eax, %edx
	addb $'0', %bl # Convert to ASCII
	movb %bl, %al # Copy the results back to AL for BIOS printing
	movb $0x0E, %ah
	int $0x10 # BIOS interrupts change EAX
	dec %cx
	movl %edx, %eax # Move it back after BIOS change

	testw %cx, %cx
	jnz print_hex
	
	.byte 0x66
	popl %edx
	.byte 0x66
	popl %ebx
	.byte 0x66
	popl %eax
	.byte 0x66
	popl %ecx

	ret

printA:	
	# Just in case, we preserve state
	pushw %si
	pushw %cx
	pushw %ax

	leaw add_msg_beg, %si
	movw add_msg_beg_len, %cx
local_1:
	lodsb
	movb $0x0E, %ah
	int $0x10
	dec %cx
	
	testw %cx, %cx
	jnz local_1

	popw %ax
	popw %cx
	popw %si

	ret

printB:
	pushw %si
	pushw %cx
	pushw %ax

	leaw add_msg_end, %si
	movw add_msg_end_len, %cx
local_2:
	lodsb
	movb $0x0E, %ah
	int $0x10
	dec %cx

	testw %cx, %cx
	jnz local_2

	popw %ax
	popw %cx
	popw %si

	ret
# ============= States to be in... =================

error:
	# We ran into an error in the bootloader!
	hlt
	jmp error

	# We halt the CPU
halt:
	hlt
	jmp halt

# ============== Functions & messages ================
print:	
	pushw %dx # Save the return address onto DX Register
	movb %al, %dl # Move 8 lower bits of AL to DL

# ===
add_msg_beg:
	.asciz "Address range["
add_msg_beg_len:
	.word . - add_msg_beg
# ===
add_msg_end:
	.asciz " ] status:"
add_msg_end_len:
	.word . - add_msg_end
# ===
msg:
	.asciz "MemOS: Welcome *** System Memory is: "
msg_len:
	.word . - msg
# ===
msg_units:
	.asciz "MB"
msg_ulen:
	.word . - msg_ulen
# ===
	# Master Boot Record (MBR) Signature
	.space 510 - (. - _start) # Pad until we slap the sig in the back

	.byte 0x55
	.byte 0xAA
