.equ ADDR_VGA, 0x08000000
.equ ADDR_CHAR, 0x09000000
.equ MAX_SCREEN, 0x0803BE7F		#point right after end of screen
.equ TMAX_SCREEN, 0x08000280	# USED TO TRACK LAST X-COORDINATE - add 1024 after each iteration
# using r23 to store the data
# r23 0x80000001 right arrow pressed   LED0 
# r23 0x80000002 top arrow pressed     LED1
# r23 0x80000004 left arrow pressed    LED2
# r23 0x80000000 nothing is pressed	   NOTHING LIGHTS UP

# PS2 KEYBOARD/MOUSE address
.equ PS2,	0xFF200100

# VGA INFO
.equ ADDR_VGA, 0x08000000
.equ ADDR_CHAR, 0x09000000
.equ MAX_SCREEN, 0x0803BE7F		#point right after end of screen
.equ TMAX_SCREEN, 0x08000280	# USED TO TRACK LAST X-COORDINATE - add 1024 after each iteration

.equ LEDR, 0xFF200000 

char:
	.incbin "char.bmp"

#bmp for map (should be 320 x 480) (2x screen height)
#make sure to change this to be top-bottom using a bmp converter
map:
	.incbin "map.bmp"

#bmp for death screen
death:
	.incbin "death.bmp"

#bmp for title screen
title_screen:
	.incbin "title.bmp"

byte1: .byte 0x00
byte2: .byte 0x00
byte3: .byte 0x00
temp:  .byte 0x00




.section .text
.global _start
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

clear_loop:
	bge			r8, r10, print_title
	sthio		r0, (r8)
	addi		r8, r8, 2
	br			clear_loop




print_title:
	movia		r8, ADDR_VGA
	movia		r9, title_screen
	addi		r9, r9, 70			#offset to bmp file (might not be necessary)
	movia		r10, MAX_SCREEN
	movia		r11, TMAX_SCREEN

draw_loop0:
	bge			r8, r11, draw_loop1
	ldh			r16, (r9)
	sthio		r16, (r8)
	addi		r9, r9, 2			#offset to bmp file (might not be necessary)
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
	addi		r9, r0, 1
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
	br		gameplay




gameplay:

init:
	movia		r8, map 		#should always hold map data
	addi 		r8, r8, 66
	#if you want to move up, subtract 7680 from this number:
	movui 		r11, 38400		#should always hold map shift value
	add 		r11, r11, r11

	movia		r12, char		#should always hold char data
	addi		r12, r12, 70
	movi		r13, 5			#should always hold char's top left position (range from 0 to 9)
	mov 		r2, r0


game_loop:
	call		draw_map
	call		draw_char

	# check for keyboard input
	call 		checkByteValue
	call 		byte_clear

	# we can use keyboard inputs to poll for movement and screenchange
	# temporarily using bit 31 of r23 to check for keyboard UP
	call		key_poll

	#at this point, r2 holds key data
	call		key_response

	#clear r23 to wipe all past keyboard inputs
	mov 		r23, r0

	#read to see if any pixels touch obstacle
	call		check_position

	#if r2 is true, need to show death screen
	beq			r2, r0, game_loop
	call		death_screen




#subroutine with r4 as starting point
draw_map:
	movia		r9, ADDR_VGA
	movia		r10, MAX_SCREEN
	movia 		r16, TMAX_SCREEN
	add 		r4, r11, r11		#setup screen coordinate by multiplying offset by 2 (2 bytes/px)
	add 		r4, r4, r8			#add to drawing coordinate

draw_map_loop0:
	bge			r9, r16, draw_map_loop1:
	ldh			r17, (r4)
	sthio		r17, (r9)
	addi		r4, r4, 2
	addi		r9, r9, 2
	br			draw_map_loop0

draw_map_loop1:
	bge			r9, r10, draw_map_done
	addi 		r9, r9, 384
	addi 		r16, r16, 1024
	br			draw_map_loop0

draw_map_done:
	ret




draw_char:
	#setup pixel coordinates to be the last tenth of the map scren (320 x 24)
	movia		r9, ADDR_VGA
	movi		r5, 13760
	muli		r5, r5, 16
	add 		r9, r9, r5


	muli		r5, r13, 64			#shift character by r13 amount
	add			r9, r9, r5
	mov 		r4, r12
	#double for-loop to draw the character
	movi 		r5, 24
	movi		r6, 32

draw_char_loop0:
	beq 		r6, r0, draw_char_loop1
	ldh			r16, (r4)
	sthio		r16, (r9)
	addi		r4, r4, 2
	addi		r9, r9, 2
	subi 		r6, r6, 1
	br			draw_char_loop0

draw_char_loop1:
	subi 		r5, r5, 1
	beq 		r5, r0, draw_char_done
	addi 		r9, r9, 960
	movi 		r6, 32
	br			draw_char_loop0

draw_char_done:
	ret




checkByteValue:
	#store three bytes to different reg
	movia	r16, byte1
	ldbu	r22, 0(r16)
	movia	r16, byte2
	ldbu	r14, 0(r16)
	movia	r16, byte3
	ldbu	r15, 0(r16)

	bne		r22, r0, cond_done
	bne		r14, r0, cond_done
	bne		r15, r0, cond_done
	mov 	r23, r0
	br		checkByteValue
	
cond_done:
	movi	r16, 0xE0
	movi	r9, 0xF0

	bne		r22, r16, others
	bne		r14, r9, others

	#check if its right 0x00E0F074
	movi	r10, 0x74
	beq		r15, r10, right
	
	#check if its left 0x00E0F6B	
	movi	r10, 0x6B
	beq		r15, r10, left
	
	#check if its top 0x00E0F075
	movi	r10, 0x75
	beq		r15, r10, top

	br		others
	
right:
	movia	r9, LEDR
	movi	r16, 0b1
	stwio	r16, (r9)
	movia	r23, 0x80000001
	ret

left:
	movia	r9, LEDR
	movi	r16, 0b100
	stwio	r16, (r9)
	movia	r23, 0x80000004
	ret

top:
	movia	r9, LEDR
	movi	r16, 0b10
	stwio	r16, (r9)
	movia	r23, 0x80000002
	ret

others:
	movia	r9, LEDR
	movi	r16, 0
	stwio	r16, (r9)
	movia	r23, 0x80000000
	ret




byte_clear:
	#reset keyboard input bytes
	movia		r16, byte1
	stb 		r0, 0(r16)
	movia		r16, byte2
	stb 		r0, 0(r16)
	movia		r16, byte3
	stb 		r0, 0(r16) 
	ret




key_poll:
	srli		r4, r23, 31
	or			r4, r4, r0
	beq			r4, r0, key_poll
	mov 		r2, r23
	ret

key_response:
	andi		r5, r23, 0b1
	bne			r5, r0, move_right
	andi 		r5, r23, 0b10
	bne 		r5, r0, move_up
	andi 		r5, r23, 0b100
	bne			r5, r0, move_left

#if UP -> subi r11, 7680 -> if r11 < 0 -> movi r11, 76800
move_up:
	subi 		r11, r11, 7680
	blt 		r11, r0, move_up_cond
	ret

move_up_cond:
	movui 		r11, 38400
	add 		r11, r11, r11
	ret

#if LEFT -> subi r13, 1 -> if r13 < 0 -> mov r13, r0
move_left:
	subi 		r13, r13, 1
	blt 		r13, r0, move_left_cond
	ret

move_left_cond:
	mov 		r13, r0
	ret

#if RIGHT -> addi r13, 1 -> if r13 > 9 -> movi r13, 9
move_right:
	addi 		r13, r13, 1
	movi 		r5, 9
	bgt 		r13, r5, move_right_cond
	ret

move_right_cond:
	movi 		r13, 9
	ret

	#if ESC -> br clear_screen (found in drawing_char.s) TODO




check_position:
	# retrieve character position
	movia		r9, ADDR_VGA
	movi		r5, 13760
	muli		r5, r5, 16
	add 		r9, r9, r5
	muli		r5, r13, 64			#shift character by r13 amount
	add			r9, r9, r5

	# from here check if any of the next 32 bits are black
	mov 		r2, r0
	movi 		r5, 32

check_position_loop:
	beq			r5, r0, check_position_done
	ldhio		r16, (r9)
	subi 		r5, r5, 1
	addi 		r9, r9, 2
	bne			r16, r0, check_position_loop
	movi 		r2, 1
check_position_done:
	ret




death_screen:
	movia 		r8, death
	addi 		r8, r8, 70
	movia 		r9, ADDR_VGA
	movia 		r10, MAX_SCREEN
	movia 		r11, TMAX_SCREEN

death_screen_loop0:
	bge 		r9, r11, death_screen_loop1
	ldh 		r16, (r8)
	sthio		r16, (r9)
	addi 		r9, r9, 2
	addi		r8, r8, 2
	br 			death_screen_loop0

death_screen_loop1:
	bge 		r9, r10, death_screen_done
	addi 		r9, r9, 384
	addi 		r11, r11, 1024
	br 			death_screen_loop0

death_screen_done:
	srli		r4, r23, 31
	bne			r4, r9, death_screen_done
	br			clear_screen


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

exit:
	ldw			r16, 0(sp)
	ldw			r17, 4(sp)
	addi		sp, sp, 8
	subi		ea, ea, 4
	eret
