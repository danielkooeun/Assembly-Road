.equ ADDR_VGA, 0x08000000
.equ ADDR_CHAR, 0x09000000
.equ MAX_SCREEN, 0x0803BE7F		#point right after end of screen
.equ TMAX_SCREEN, 0x08000280	# USED TO TRACK LAST X-COORDINATE - add 1024 after each iteration

# LED address
.equ LEDR,	0xFF200000

# PS2 KEYBOARD/MOUSE address
.equ PS2,	0xFF200100




.data

#bmp for title screen
title_screen:
	.incbin "title.bmp"

.global byte1
.global byte2
.global byte3
.global temp
.global score

byte1: .byte 0x00
byte2: .byte 0x00
byte3: .byte 0x00
temp:  .byte 0x00
score: .hword 0x00




.section .text
.global _start
.global clear_screen
_start:




keyboard_setup:
	#enable read interrupts on PS2
	#by setting bit0 of control reg to 1
	movia	r20, PS2
	movi	r9, 0b1
	stwio	r9, 4(r20)

	#enable ext interrupts
	movi	r9, 0b1
	wrctl	ctl0, r9
	movi	r9, 0b10000000
	wrctl	ctl3, r9
	movia	r9, LEDR
	movi	r20, 0
	stwio	r20, (r9)




#subroutine to loop through every VGA point and clear it with black bit
clear_screen:
	movia		r8, ADDR_VGA
	movia		r10, MAX_SCREEN

	movia		r16, byte1
	stb 		r0, 0(r16)
	movia		r16, byte2
	stb 		r0, 0(r16)
	movia		r16, byte3
	stb 		r0, 0(r16)

	movia 	r16, score
	sth 		r0, (r16)

clear_loop:
	bge			r8, r10, print_title
	sthio		r0, (r8)
	addi		r8, r8, 2
	br			clear_loop




print_title:
	movia		r8, ADDR_VGA
	movia		r12, title_screen
	addi		r12, r12, 70			#offset to bmp file (might not be necessary)
	movia		r10, MAX_SCREEN
	movia		r11, TMAX_SCREEN

draw_loop0:
	bge			r8, r11, draw_loop1
	ldh			r16, (r12)
	sthio		r16, (r8)
	addi		r12, r12, 2			#offset to bmp file (might not be necessary)
	addi		r8, r8, 2
	br			draw_loop0

# second loop to skip non-existing x-coordinates
# skipping to next valid y-coordinate
draw_loop1:
	bge			r8, r10, draw_done0			#check whether r8 (printing coordiante) has reached the end yet
	addi		r8, r8, 384							#adding offset from (320, i) to (0, i + 1)
	addi		r11, r11, 1024					#adding offset from (MAX, i) to (MAX i + 1)
	br			draw_loop0

draw_done0:
	addi		r12, r0, 1
	mov 		r23, r0




# once drawing is done, poll for key press
wait_for_start:
	#store three bytes to different reg
	movia	r16, byte1
	ldbu	r22, 0(r16)
	movia	r16, byte2
	ldbu	r14, 0(r16)
	movia	r16, byte3
	ldbu	r15, 0(r16)

	bne		r22, r0, continue
	bne		r14, r0, continue
	bne		r15, r0, continue
	br		wait_for_start
	
continue:
	movia		r16, byte1
	stb 		r0, 0(r16)
	movia		r16, byte2
	stb 		r0, 0(r16)
	movia		r16, byte3
	stb 		r0, 0(r16)
	br		gameplay