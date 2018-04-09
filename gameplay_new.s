# using r23 to store the data
# r23 0x80000001 right arrow pressed   LED0 
# r23 0x80000002 top arrow pressed     LED1
# r23 0x80000004 left arrow pressed    LED2
# r23 0x80000000 nothing is pressed	   NOTHING LIGHTS UP

# PS2 KEYBOARD/MOUSE address
.equ PS2,	0xFF200100

# LED address
.equ LEDR,	0xFF200000

# audio address
.equ audio, 0xFF203040

# VGA INFO
.equ ADDR_VGA, 0x08000000
.equ ADDR_CHAR, 0x09000000
.equ MAX_SCREEN, 0x0803BE7F		#point right after end of screen
.equ TMAX_SCREEN, 0x08000280	# USED TO TRACK LAST X-COORDINATE - add 1024 after each iteration


.data

#bmp for character (32 x 24)
char:
	.incbin "char.bmp"

#bmp for map (should be 320 x 480) (2x screen height)
#make sure to change this to be top-bottom using a bmp converter
map:
	.incbin "map.bmp"

#bmp for death screen
death:
	.incbin "death.bmp"

sound_jump:
	.incbin "jump.wav"

stop_jump:
	.byte 0x00


.section .text
.global gameplay
gameplay:

init:
	movia sp, 0x03FFFFFC
	movia		r8, map 		#should always hold map data
	addi 		r8, r8, 66
	#if you want to move up, subtract 7680 from this number:
	movui 		r11, 27840		#should always hold map shift value
	muli 		r11, r11, 8

	movia		r12, char		#should always hold char data
	addi		r12, r12, 70
	movi		r13, 10			#should always hold char's top left position (range from 0 to 19)
	mov 		r2, r0


	call		draw_map
	call		draw_char
	call 		draw_score

game_loop:
	# check for keyboard input
	# we can use keyboard inputs to poll for movement and screenchange
	call 		checkByteValue
	call 		byte_clear

	#clear r23 to wipe all past keyboard inputs
	mov 		r23, r0

	#at this point, r23 holds key data
	call		key_response

	call		draw_map

	#read to see if any pixels touch obstacle
	call		check_position

	call		draw_char
	call 		draw_score

	#if r2 is true, need to show death screen
	beq			r2, r0, game_loop
	call		death_screen




#subroutine with r4 as starting point
draw_map:
	movia		r9, ADDR_VGA
	movia		r10, MAX_SCREEN
	movia 	r16, TMAX_SCREEN
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
	movi		r5, 13824		# 1024 x 216
	muli		r5, r5, 16
	add 		r9, r9, r5


	muli		r5, r13, 32			#shift character by r13 amount (2 * 16)
	add			r9, r9, r5
	mov 		r4, r12
	#double for-loop to draw the character
	movi 		r5, 24
	movi		r6, 16

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
	addi 		r9, r9, 992
	movi 		r6, 16
	br			draw_char_loop0

draw_char_done:
	ret


draw_score:
	movia		r5, ADDR_CHAR
	addi 		r5, r5, 129
	movi 		r9, 0x53
	stbio 	r9, (r5)
	movi 		r9, 0x43
	stbio 	r9, 1(r5)
	movi 		r9, 0x4F
	stbio 	r9, 2(r5)
	movi 		r9, 0x52
	stbio 	r9, 3(r5)
	movi 		r9, 0x45
	stbio 	r9, 4(r5)
	movi 		r9, 0x3A
	stbio 	r9, 6(r5)

	movia 	r9, score
	ldh 		r9, (r9)
	mov 		r22, r0
	movi 		r6, 10

score_loop:
	bgt 		r6, r9, score_done
	addi 		r22, r22, 1
	subi 		r9, r9, 10
	br 			score_loop

score_done:
	addi 		r9,r9, 0x30
	addi 		r22, r22, 0x30
	addi 		r5, r5, 256
	stbio 	r22, (r5)
	stbio 	r9, 1(r5)
	ret



checkByteValue:
#	bne		r22, r0, cond_done
#	bne		r14, r0, cond_done
#	bne		r15, r0, cond_done
# check if we have received all three bytes
	bne		r19, r0, cond_done
	mov 	r23, r0
	br		checkByteValue
	
cond_done:	
	# reset r19 back to 0
	mov 	r19, r0 

	#store three bytes to different reg
	movia	r16, byte1
	ldbu	r22, 0(r16)
	movia	r16, byte2
	ldbu	r14, 0(r16)
	movia	r16, byte3
	ldbu	r15, 0(r16)

	movi	r16, 0xE0
	movi	r9, 0xF0

	bne		r22, r16, check_mouse
	bne		r14, r9, check_mouse

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

check_mouse:
	movi 	r16, 0x0A
	beq		r22, r16, right

	movi    r16, 0x09
	beq		r22, r16, left

	movi    r16, 0x0C
	beq		r22, r16, top

	br 		others

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
	mov 		r19, r0
	movia		r16, byte1
	stb 		r0, 0(r16)
	movia		r16, byte2
	stb 		r0, 0(r16)
	movia		r16, byte3
	stb 		r0, 0(r16)
	ret


key_response:
	subi		sp, sp, 4
    stw			ra, 0(sp)
	andi		r5, r23, 1
	bne			r5, r0, move_right
	andi 		r5, r23, 2
	bne 		r5, r0, move_up
	andi 		r5, r23, 4
	bne			r5, r0, move_left
key_reponse_end:
	ldw			ra, 0(sp)
    addi		sp, sp, 4
	ret

#if RIGHT -> addi r13, 1 -> if r13 > 9 -> movi r13, 9
move_right:
	addi 		r13, r13, 1
	movi 		r5, 19
	call		sound_effect
	bgt 		r13, r5, move_right_cond
	br			key_reponse_end

move_right_cond:
	movi 		r13, 19
	br			key_reponse_end

#if UP -> subi r11, 7680 -> if r11 < 0 -> movi r11, 76800
# CHANGE TO movi r11, 222720
move_up:
	subi 		r11, r11, 7680
	movia 	r5, score
	ldh 		r9, (r5)
	addi 		r9, r9, 1
	sth 		r9, (r5)
	call		sound_effect
	blt 		r11, r0, move_up_cond
	br			key_reponse_end

move_up_cond:
	movui 		r11, 27840
	muli 			r11, r11, 8
	br			key_reponse_end

#if LEFT -> subi r13, 1 -> if r13 < 0 -> mov r13, r0
move_left:
	subi 		r13, r13, 1
	call		sound_effect
	blt 		r13, r0, move_left_cond
	br			key_reponse_end

move_left_cond:
	mov 		r13, r0
	br			key_reponse_end


	#if ESC -> br clear_screen (found in drawing_char.s) TODO

sound_effect:
    movia	r6, audio	

	#clear both left and right read and write FIFOs 
	#enable read interrupt and write interrupt
	movi	r9, 0b1111
	stwio	r9, 0(r8)

	movia	r9, sound_jump
	movia	r10, stop_jump
loop: 
	#stw the first byte into r4
	ldw		r4, 0(r9)		

WaitForWriteSpace:
    ldwio	r2, 4(r6)
    andhi	r3, r2, 0xff00
    beq		r3, r0, WaitForWriteSpace
    andhi	r3, r2, 0xff
    beq		r3, r0, WaitForWriteSpace

WriteTwoSamples:
    stwio	r4, 8(r6)
    stwio	r4, 12(r6)
    #incrementing address
	addi	r9, r9, 4
	bne		r9, r10, loop
    
   	ret



check_position:
	# retrieve character position
	movia		r9, ADDR_VGA
	movi		r5, 13824
	muli		r5, r5, 16
	add 		r9, r9, r5
	muli		r5, r13, 32			#shift character by r13 amount
	add			r9, r9, r5

	# from here check if any of the next 32 bits are black
	mov 		r2, r0
	movi 		r5, 16

	# check if any of the bits are TURQUOISE TODO (CAR COLOR)
	movi 		r10, 0x2571

check_position_loop:
	beq			r5, r0, check_position_done
	ldhio		r16, (r9)
	subi 		r5, r5, 1
	addi 		r9, r9, 2
	bne			r16, r0, check_2
check_2:
	bne 		r16, r10, check_position_loop
	movi 		r2, 1
check_position_done:
	ret




death_screen:
	movia 		r8, death
	addi 			r8, r8, 70
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

# wait until user presses key in order to restart
death_screen_done:
	#store three bytes to different reg
	movia	r16, byte1
	ldbu	r22, 0(r16)
	movia	r16, byte2
	ldbu	r14, 0(r16)
	movia	r16, byte3
	ldbu	r15, 0(r16)

	bne		r22, r0, clear_screen
	bne		r14, r0, clear_screen
	bne		r15, r0, clear_screen
	br		death_screen_done
