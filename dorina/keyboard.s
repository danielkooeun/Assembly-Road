# using r23 to store the data
# r23 0x80000001 right arrow pressed   LED0 
# r23 0x80000002 top arrow pressed     LED1
# r23 0x80000004 left arrow pressed    LED2
# r23 0x80000000 nothing is pressed	   NOTHING LIGHTS UP


# LED address
.equ LEDR,	0xFF200000

# PS2 KEYBOARD/MOUSE address
.equ PS2,	0xFF200100



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

change_global:
	#check if all three bytes are filled
	movia		r17, byte3
	ldbu		r16, 0(r17)
	beq			r16, r0, exit
    
    movia		r17, byte2
	ldbu		r16, 0(r17)
	beq			r16, r0, exit
    
    movia		r17, byte1
	ldbu		r16, 0(r17)
	beq			r16, r0, exit
    
	movi  		r19, 1

exit:
	ldw			r16, 0(sp)
	ldw			r17, 4(sp)
	addi		sp, sp, 8
	subi		ea, ea, 4
	eret
