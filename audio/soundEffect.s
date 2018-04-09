.equ audio, 0xFF203040	#base
/*	base+4: fifospace register 
	7:0:	read data available in right channel
	15:8:	read data availalbe in left channel
	23:16	write space in right channel
	31:24	write space in left channel	
*/

.section .data
	sound_jump:	.incbin	"jump.wav"      #32 bit signed  2 channel 48kHz
	stop:	.byte	0x00

.section .text
.global _start
_start:
    movia	r6, audio	

	#clear both left and right read and write FIFOs 
	#enable read interrupt and write interrupt
	movi	r9, 0b1111
	stwio	r9, 0(r8)

	movia	r9, sound_jump
	movia	r10, stop
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
    br		end

end:
	br 		end

	


	
