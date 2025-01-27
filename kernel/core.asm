; core
;
; Routines used by pretty much all parts. You will want to include it first
; in your glue file.

; *** CONSTS ***
.equ	ASCII_BS	0x08
.equ	ASCII_CR	0x0d
.equ	ASCII_LF	0x0a
.equ	ASCII_DEL	0x7f

; *** DATA ***
; Useful data to point to, when a pointer is needed.
P_NULL:		.db 0

; *** REGISTER FIDDLING ***

; add the value of A into DE
addDE:
	push	af
	add	a, e
	jr	nc, .end	; no carry? skip inc
	inc	d
.end:
	ld	e, a
	pop	af
noop:				; piggy backing on the first "ret" we have
	ret

; copy (HL) into DE, then exchange the two, utilising the optimised HL instructions. 
; ld must be done little endian, so least significant byte first.
intoHL:
	push 	de
	ld 	e, (hl)
	inc 	hl
	ld 	d, (hl)
	ex 	de, hl
	pop 	de
	ret

intoDE:
	ex 	de, hl
	call 	intoHL
	ex 	de, hl		; de preserved by intoHL, so no push/pop needed
	ret

intoIX:
	push 	ix
	ex 	(sp), hl	;swap hl with ix, on the stack
	call 	intoHL
	ex 	(sp), hl	;restore hl from stack
	pop 	ix
	ret

; add the value of A into HL
; affects carry flag according to the 16-bit addition, Z, S and P untouched.
addHL:
	push	de
	ld 	d, 0
	ld	e, a
	add	hl, de
	pop	de
	ret


; subtract the value of A from HL
; affects flags according to the 16-bit subtraction.
subHL:
	push	de
	ld	d, 0
	ld	e, a
	or 	a		;reset carry flag
	sbc	hl, de		;There is no 'sub hl, de', so we must use sbc
	pop	de
	ret

; Compare HL with DE and sets Z and C in the same way as a regular cp X where
; HL is A and DE is X.
cpHLDE:
	push 	hl
	or 	a		;reset carry flag
	sbc 	hl, de		;There is no 'sub hl, de', so we must use sbc
	pop 	hl
	ret

; Write the contents of HL in (DE)
; de and hl are preserved, so no pushing/popping necessary
writeHLinDE:
	ex	de, hl 
	ld	(hl), e
	inc	hl
	ld	(hl), d
	dec	hl
	ex	de, hl
	ret

; Call the method (IX) is a pointer to. In other words, call intoIX before
; callIX
callIXI:
	push	ix
	call	intoIX
	call	callIX
	pop	ix
	ret

; jump to the location pointed to by IX. This allows us to call IX instead of
; just jumping it. We use IX because we seldom use this for arguments.
callIX:
	jp	(ix)

callIY:
	jp	(iy)

; Ensures that Z is unset (more complicated than it sounds...)
unsetZ:
	push	bc
	ld	b, a
	inc	b
	cp	b
	pop	bc
	ret

; *** STRINGS ***

; Fill B bytes at (HL) with A
fill:
	push	bc
	push	hl
.loop:
	ld	(hl), a
	inc	hl
	djnz	.loop
	pop	hl
	pop	bc
	ret

; Increase HL until the memory address it points to is equal to A for a maximum
; of 0xff bytes. Returns the new HL value as well as the number of bytes
; iterated in A.
; If a null char is encountered before we find A, processing is stopped in the
; same way as if we found our char (so, we look for A *or* 0)
; Set Z if the character is found. Unsets it if not
findchar:
	push	bc
	ld	c, a	; let's use C as our cp target
	ld	a, 0xff
	ld	b, a

.loop:	ld	a, (hl)
	cp	c
	jr	z, .match
	or	a		; cp 0
	jr	z, .nomatch
	inc	hl
	djnz	.loop
.nomatch:
	call	unsetZ
	jr	.end
.match:
	; We ran 0xff-B loops. That's the result that goes in A.
	ld	a, 0xff
	sub	b
	cp	a	; ensure Z
.end:
	pop	bc
	ret

; Format the lower nibble of A into a hex char and stores the result in A.
fmtHex:
	and	0xf
	cp	10
	jr	nc, .alpha	; if >= 10, we have alpha
	add	a, '0'
	ret
.alpha:
	add	a, 'A'-10
	ret

; Formats value in A into a string hex pair. Stores it in the memory location
; that HL points to. Does *not* add a null char at the end.
fmtHexPair:
	push	af

	; let's start with the rightmost char
	inc	hl
	call	fmtHex
	ld	(hl), a

	; and now with the leftmost
	dec	hl
	pop	af
	push	af
	and	0xf0
	rra \ rra \ rra \ rra
	call	fmtHex
	ld	(hl), a

	pop	af
	ret

; Compares strings pointed to by HL and DE up to A count of characters. If
; equal, Z is set. If not equal, Z is reset.
strncmp:
	push	bc
	push	hl
	push	de

	ld	b, a
.loop:
	ld	a, (de)
	cp	(hl)
	jr	nz, .end	; not equal? break early. NZ is carried out
				; to the called
	cp	0		; If our chars are null, stop the cmp
	jr	z, .end		; The positive result will be carried to the
	                        ; caller
	inc	hl
	inc	de
	djnz	.loop
	; We went through all chars with success, but our current Z flag is
	; unset because of the cp 0. Let's do a dummy CP to set the Z flag.
	cp	a

.end:
	pop	de
	pop	hl
	pop	bc
	; Because we don't call anything else than CP that modify the Z flag,
	; our Z value will be that of the last cp (reset if we broke the loop
	; early, set otherwise)
	ret

; Transforms the character in A, if it's in the a-z range, into its upcase
; version.
upcase:
	cp	'a'
	ret	c	; A < 'a'. nothing to do
	cp	'z'+1
	ret	nc	; A >= 'z'+1. nothing to do
	; 'a' - 'A' == 0x20
	sub	0x20
	ret

