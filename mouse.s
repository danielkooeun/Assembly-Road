# using r23 to store the data
# r23 0x80000001 right arrow pressed   LED0 
# r23 0x80000002 top arrow pressed     LED1
# r23 0x80000004 left arrow pressed    LED2
# r23 0x80000000 nothing is pressed	   NOTHING LIGHTS UP

# LED address
.equ LEDR,	0xFF200000

# PS2 KEYBOARD/MOUSE address
.equ PS2,	0xFF200100

#save the last three bytes received
#should be overwritten by the interrupt handler
.section .data
	byte1: .byte 0x00
	byte2: .byte 0x00
	byte3: .byte 0x00
	temp:  .byte 0x00

.section .text
#start of keyboard initialization
.global _start
_start:
	#enable read interrupts on PS2
	#by setting bit0 of control reg to 1
	movia	r8, PS2
	movi	r9, 0b1
	stwio	r9, 4(r8)
	
setup:
	#enable ext interrupts
	movi	r9, 0b1
	wrctl	ctl0, r9
	movi	r9, 0b10000000
	wrctl	ctl3, r9
	movia	r9, LEDR
	movi	r8, 0
	stwio	r8, (r9)

checkByteValue:
	#store three bytes to different reg
	movia	r8, byte1
	ldbu	r13, 0(r8)
	movia	r8, byte2
	ldbu	r14, 0(r8)
	movia	r8, byte3
	ldbu	r15, 0(r8) 

	#check if its right 0x0A
	movi	r10, 0x0A
	beq		r13, r10, right
	
	#check if its left 0x09	
	movi	r10, 0x09
	beq		r13, r10, left
	
	#check if its top 0x0C
	movi	r10, 0x0C
	beq		r13, r10, top

	br		others
	
right:
	movia	r9, LEDR
	movi	r8, 0b1
	stwio	r8, (r9)
	movia	r23, 0x80000001
	br		checkByteValue

left:
	movia	r9, LEDR
	movi	r8, 0b100
	stwio	r8, (r9)
	movia	r23, 0x80000004
	br		checkByteValue

top:
	movia	r9, LEDR
	movi	r8, 0b10
	stwio	r8, (r9)
	movia	r23, 0x80000002
	br		checkByteValue	

others:
	movia	r9, LEDR
	movi	r8, 0
	stwio	r8, (r9)
	movia	r23, 0x80000000
	br		checkByteValue


# interrupt setup for PS2 keyboard
.section .exceptions, "ax"

keyboardISR:
	#saving r16 and r17 for use inside interrupt
	subi	sp, sp, 8
	stw		r16, 0(sp)
	stw		r17, 4(sp)
	
	#check the status register
	
	rdctl	et, ctl4
	andi	et, et, 0b10000000		#check whether it was IRQ7
	beq		et, r0, exit

#read data to acknowledge the interrupt
acknowledge:
	movia		et, PS2
	ldwio		r16, (et)
	
	#saving the last three bytes received
	#byte1 = byte2
	#byte2 = byte3
	#byte3 = data & 0xFF

	#data received, copy the lower 8 bits to r16 and store to byte3
	andi		r16, r16, 0xFF
	movia		r17, temp
	stb			r16, 0(r17)
	
	#byte1 = byte2
	movia		r17, byte2
	ldbu		r16, 0(r17)
	movia		r17, byte1
	stb			r16, 0(r17)

	#byte2 = byte3
	movia		r17, byte3
	ldbu		r16, 0(r17)
	movia		r17, byte2
	stb			r16, 0(r17)

	#byte3 = data & 0xff
	movia		r17, temp
	ldbu		r16, 0(r17)
	movia		r17, byte3
	stb			r16, 0(r17)


display:
	movia		r17, byte3
	ldbu		r16, 0(r17)

	#display byte3 on LED 
	movia		r17, LEDR
	andi		r16, r16, 0xFF
	stwio		r16, 0(r17)


exit:
	ldw			r16, 0(sp)
	ldw			r17, 4(sp)
	addi		sp, sp, 8
	subi		ea, ea, 4
	eret


	
	
