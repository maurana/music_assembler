SECTION .text
	org 0x100

_main:
	mov ah, 0x09
	mov dx, welcome_msg
	int 0x21

	mov ax, 0x3509
	int 0x21
	mov word [ds:_backup+2], es
	mov word [ds:_backup], bx
	
	mov ah, 0x25
	mov al, 0x09
	mov dx, _cool_int9
	int 0x21

	mov cx, 0x0
	call _infinite

	mov ax, 0x2509
	mov dx, [ds:_backup]
	push ds
	push word [ds:_backup+2]
	pop ds
	int 0x21
	pop ds

	mov ah, 0x09
	mov dx, quit_msg
	int 0x21
    jmp _sysexit

_infinite:
	inc cx
	mov ax, cx
	mov ah, 0x02
	mov dl, 0x09
	int 0x21
	call buf_pop
	call dump_byte
	call magic
	call print_newline
	cmp al, [ExitScanCode]
	jne _infinite
	call speaker_off
	ret

magic:
	push ax
	cmp al, 0x80
	jb keypress
	jae keyrelease

	keypress:
		cmp al, 0x39
		je magic_stop
		cmp al, 0x58
		je magic_music
		cmp al, 0x10
		jb endmagic
		cmp al, 0x1B
		jbe oct1_press

		cmp al, 0x1C
		je oct2_press
		cmp al, 0x1E
		jb endmagic
		cmp al, 0x28
		jbe oct2_press

		cmp al, 0x2A
		je oct3_press
		cmp al, 0x2C
		jb endmagic
		cmp al, 0x36
		jbe oct3_press
		ja endmagic

		oct1_press:
			mov ah, 1
			call key_push
			call make_noise
			jmp endmagic

		oct2_press:
			mov ah, 2
			call key_push
			cmp al, 0x1C
			je _oct2_enter
			add al, 2
			jmp _oct2_ok
			_oct2_enter:
				mov al, 0x2B
			_oct2_ok:
			call make_noise
			jmp endmagic

		oct3_press:
			mov ah, 3
			call key_push
			cmp al, 0x2A
			je _oct3_lshift
			add al, 5
			jmp _oct3_ok
			_oct3_lshift:
				mov al, 0x30
			_oct3_ok:
			call make_noise
			jmp endmagic

		magic_stop:
			mov ah, 0
			call make_noise
			jmp endmagic

		magic_music:
			call speaker_off
			call play_music
			jmp endmagic			

	keyrelease:
		and al, 0x7F
		cmp al, 0x10
		jb endmagic
		cmp al, 0x1B
		jbe oct1_release

		cmp al, 0x1C
		je oct2_release
		cmp al, 0x1E
		jb endmagic
		cmp al, 0x28
		jbe oct2_release

		cmp al, 0x2A
		je oct3_release
		cmp al, 0x2C
		jb endmagic
		cmp al, 0x36
		jbe oct3_release
		ja endmagic

		oct1_release:
			mov ah, 1
			call key_pop
			call make_noise
			jmp endmagic

		oct2_release:
			mov ah, 2
			call key_pop
			cmp al, 0x1C
			je _oct2_enter_
			add al, 2
			jmp _oct2_ok_
			_oct2_enter_:
				mov al, 0x2B
			_oct2_ok_:
			call make_noise
			jmp endmagic

		oct3_release:
			mov ah, 3
			call key_pop
			cmp al, 0x2A
			je _oct3_lshift_
			add al, 5
			jmp _oct3_ok_
			_oct3_lshift_:
				mov al, 0x30
			_oct3_ok_:
			call make_noise
			jmp endmagic

	endmagic:
	pop ax
	ret

key_push:
	push bx
	mov bx, keys
	dec bx
	_try_push:
		inc bx
		cmp bx, keys_end
		je _sysexit
		cmp byte [bx], al
		je _key_push_end
		cmp byte [bx], 0x0
		jne _try_push
	mov [bx], al
	call dump_keybuf
	_key_push_end:
	pop bx
	ret

key_pop:
	push bx
	mov bx, keys
	dec bx
	_try_pop:
		inc bx
		cmp bx, keys_end
		je _key_pop_end
		cmp [bx], al
		jne _try_pop
	call _shift_left
	call dump_keybuf
	_key_pop_end:
	mov bx, keys
	dec bx
	_try_find:
		inc bx
		cmp byte [bx], 0x0
		jne _try_find
	dec bx
	cmp bx, keys-1
	je _not_found
	mov al, [bx]
	jmp _key_pop_finally_end

	_not_found:
		mov ah, 0
	_key_pop_finally_end:
	pop bx
	ret
_shift_left:
	push ax
	push bx
	dec bx
	_shift_loop:
		inc bx
		mov ax, [bx+1]
		mov [bx], ax
		cmp byte [bx], 0
		jne _shift_loop
	pop bx
	pop ax
	ret
make_noise:
	push ax
	push bx
	push cx
	push dx
	push ax
	mov ah, 0x09
	mov dx, tone_msg
	int 0x21
	pop ax
	call dump_byte
	call print_newline

	cmp ah, 0
	je _stop
	cmp ah, 1
	je _oct1
	cmp ah, 2
	je _oct2
	cmp ah, 3
	je _oct3

	_stop:
		call speaker_off
		jmp make_noise_end

	_oct1:
		sub al, 0x10
		mov bx, oct1
		jmp make_noise_ok
	_oct2:
		sub al, 0x20
		mov bx, oct2
		jmp make_noise_ok
	_oct3:
		sub al, 0x30
		mov bx, oct3	
		jmp make_noise_ok

	make_noise_ok:
	shl al, 1
	mov ah, 0
	add bx, ax
	mov ax, [bx]
	call speaker_on

	make_noise_end:
	pop dx
	pop cx
	pop bx
	pop ax
	ret

speaker_on:
	push ax
	push ax
	mov al, 0b10110110
	out 0x43, al
	pop ax
	out 0x42, al
	mov al, ah
	out 0x42, al
	in al, 0x61
	or al, 0b000011
	out 0x61, al
	pop ax
	ret

speaker_off:
	push ax
	in al, 0x61
	and al, 0b11111100
	out 0x61, al
	pop ax
	ret

play_music:
	push ax
	push bx
	push cx
	push dx
	push si
	push di

	mov ax, 0x3508
	int 0x21
	mov word [ds:_backup2+2], es
	mov word [ds:_backup2], bx
	
	mov ah, 0x25
	mov al, 0x08
	mov dx, _cool_int8
	int 0x21

	mov cx, [m_count]
	mov di, m_notes
	mov si, m_delays
	_player:
		mov al, [di]
		call simplify
		call make_noise
		call dump_word
		mov ax, [si]
		call print_newline
		push di
		push si
		mov [delay], ax
		_alala:
			cmp [delay], word 0
			ja _alala
		pop si
		pop di
		inc di
		add si, 2
		loop _player
	call speaker_off

	mov ax, 0x2508
	mov dx, [ds:_backup2]
	push ds
	push word [ds:_backup2+2]
	pop ds
	int 0x21
	pop ds

	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop ax
	ret

simplify:
	cmp al, 0
	je s_silent
	cmp al, 13
	jbe s_1
	cmp al, 113
	jbe s_2
	cmp al, 213
	jbe s_3
	jmp s_silent

	s_silent:
		mov ax, 0x0000
		jmp s_end
	s_1:
		mov ah, 0x01
		add al, 15
		jmp s_end
	s_2:
		mov ah, 0x02
		sub al, 69
		jmp s_end
	s_3:
		mov ah, 0x03
		sub al, 153
		jmp s_end
	s_end:
	ret

_cool_int9:
	_waitbuffer:
		in al, 0x64
		test al, 0b10
		jne _waitbuffer
	in al, 0x60
	call buf_push
	mov [tail], di

	in al, 61h
	mov ah,al
	or al, 10000000b
	out 61h, al
	mov al, ah
	out 61h, al
	mov al, 20h
	out 20h, al
	iret

_cool_int8:
	pushf
	cmp word [cs:delay], 0
	je _lol
	dec word [cs:delay]
	_lol:
	popf
	jmp far [cs:_backup2]
	iret

dump_keybuf:
	ret
	push ax
	push bx
	push dx
	mov bx, keys
	dec bx
	mov ah, 0x02
	mov dl, 0x3C
	int 0x21
	mov ah, 0x02
	mov dl, 0x20
	int 0x21
	_dump_repeat:
		inc bx
		mov al, [bx]
		call dump_byte
		mov ah, 0x02
		mov dl, 0x20
		int 0x21
		cmp bx, keys_end-1
		jb _dump_repeat

	mov ah, 0x02
	mov dl, 0x3E
	int 0x21
	pop dx
	pop bx
	pop ax
	ret

buf_push:
	mov si, [head]
	mov di, [tail]
	mov [di], byte al
	;push ax
	;mov ax, di
	;call dump_word
	;mov ax, [buf_end]
	;call dump_word
	;pop ax
	inc di
	cmp di, [buf_end]
	je _just_round
	jmp _just_end
	_just_round:
		sub di, [buf_size]
		jmp _just_end
	_beep:
		mov ah, 0x02
		mov dl, 0x14
		int 0x21
		call print_newline
		jmp _just_end
	_just_end:

	mov [tail], di
	ret

buf_pop:
	mov si, [head]
	mov di, [tail]
	_wait_for_data:
		cmp si, di
		je _wait_for_data
	mov al, [si]
	inc si 
	cmp si, [buf_end]
	je read_round
	jmp _read_end

	read_round:
		sub si, [buf_size]
	
	_read_end:
		mov [head], si
	ret

print_newline:
	push ax
	push dx
	mov ah, 0x09
	mov dx, newline
	int 0x21
	pop dx
	pop ax
	ret

dump_word:
	xchg al, ah
	call dump_byte
	xchg al, ah
	call dump_byte
	ret

dump_byte:
	push bx
	push cx
	push dx
	push ax
	push ax

	lea bx, [cs:symbols]
	shr al, 4
	xlat
	mov dl, al
	mov ah, 2
	int 21h
	pop ax
	and al, 0Fh
	xlat
	mov dl, al
	mov ah, 2
	int 21h
	
	pop ax
	pop dx
	pop cx
	pop bx
	ret

_sysexit:
    mov ax, 0x4c00
    int 0x21
    ret

SECTION .data
        symbols db '0123456789ABCDEF$'
        newline db 13,10,'$'
        welcome_msg db "Music initialized.",13,10,"$"
        tone_msg db "Tone:	","$"
		quit_msg db "End of line, program.",13,10,"$"
		ExitScanCode db 0x01
		buffer times 0x10 db 0
		head dw buffer
		tail dw buffer
		buf_end dw head
		buf_size dw head - buffer
		keys db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
		keys_trailing_zero db 0
		keys_end db $-1
		oct1 dw	9121,8609,8126,7670,7239,6833,6449,6087,5746,5423,5119,4831
		oct2 dw	4560,4304,4063,3834,3619,3416,3224,3043,2873,2711,2559,2415
		oct3 dw 2280,2152,2031,1917,1809,1715,1612,1521,1436,1355,1292,1207
		delay dw 0x0018
		m_notes  db  103,0, 103,0,103,0,103,0, 105,0, 105,0, 107,0, 103,0, 105,0
		 		 db  103,0, 103,0,103,0,103,0, 105,0, 105,0, 107,0, 103,0, 105,0
		 		 db  5,101,0, 103,101,0, 12,11,0, 8,7,0,    3,13,0,  101,13,0

		m_delays dw  3, 5,  1,2,  1,2,  1,2,     4,6, 4,5,   4,5,   4,6,   10,8
				 dw  3, 5,  1,2,  1,2,  1,2,     4,6, 4,5,   4,5,   4,6,   10,8
				 dw  2,4,3,    2,4,3,    2,4,3,   2,7,4,    2,4,3,   2,4,3

		m_count dw m_delays - m_notes

SECTION .bss
		_backup resd 1
		_backup2 resd 1