

	; �������:
	;
	; c_* - ������������� ���������, ������������ � #
	; g_* - �������� ��������� (����������)
	; gb_* - ������� �������� ��������� (������� ����������)
	;
	; l_* - ��� �����, ���������� ����� ljmp
	; f_* - ��� �������, ���������� ����� lcall
	; fl_* - ��� ����� �������, ���������� ����� ljmp ������ ������� �������
	; i_* - ��� ����������
	; il_* - ��� ����� ����������, ���������� ������ ������� ����������
	
	; ����������:
	
	; ����������:
	
	; �����������:
	
	; ���������:
	
	p4:							equ E8h 	
	p5:							equ F8h 	
	
	g_kb_out_array				equ 30h		; �������� 30h - 33h
	
	g_timer0_period_high		equ 3Fh		; 
	g_timer0_period_low			equ 40h		;
	
	g_timer0_cb_interrupt_high	equ 41h		;
	g_timer0_cb_interrupt_low	equ 42h		;
	
	g_usart_cb_interrupt_high	equ 43h		;
	g_usart_cb_interrupt_low	equ 44h		;
	
	g_i0_cb_interrupt_high		equ 45h		;
	g_i0_cb_interrupt_low		equ 46h		;
	g_i1_cb_interrupt_high		equ 47h		;
	g_i1_cb_interrupt_low		equ 48h		;
	
	g_concat_dest_high			equ 49h		; ����� ������ ���������� ��� ������� ���������� ������
	g_concat_dest_low			equ 50h		;
	g_concat_offset				equ 51h		; �������� � ������
	
	gb_i0_enabled				equ A8h		;
	gb_i1_enabled				equ AAh		;
	
	
	c_dec_modulo:				equ 10d		; ��������� ���������� ������� ���������
	c_char_zero:				equ 30h		; ASCII �������� �� ������� ����
	c_e:						equ 20h		; ASCII ������� �������
	c_char_not_a_dec_digit:		equ 20h		; ASCII ������� ����������� ��-���������� �����
	
	c_lcd_line_length:			equ 20d		; 
	g_lcd_line0:				db #c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e
	g_lcd_line1:				db #c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e

	; ���:
	
org 800Bh
	push dph
	push dpl
	mov dph, g_timer0_cb_interrupt_high
	mov dpl, g_timer0_cb_interrupt_low
	ljmp dptr

	
org 8003h
	push dph
	push dpl
	mov dph, g_i0_cb_interrupt_high
	mov dpl, g_i0_cb_interrupt_low
	ljmp dptr
org 8013h
	push dph
	push dpl
	mov dph, g_i1_cb_interrupt_high
	mov dpl, g_i1_cb_interrupt_low
	ljmp dptr
org 8023h
	push dph
	push dpl
	mov dph, g_usart_cb_interrupt_high
	mov dpl, g_usart_cb_interrupt_low
	ljmp dptr
	
f_timer0_start:
	clr tr0
	anl tmod, #11110000b
	orl tmod, #00000001b
	
	mov TH0, #ECh
	mov TL0, #77h
	mov g_tick_count, #0h			
	mov g_update_count, #0h		
	mov g_second_count, #0h			
	mov g_minute_count, #0h			
	
	setb et0							; 1 ��� �������� ���������� ���������� IEN0
	setb tr0							; 4 ��� �������� ���������� ��������� TCON
	
	ret
	
f_timer0_stop:
	clr tr0
	ret
	
f_timer1_start:
	clr tr1
	
	mov scon, #11010010b				; 9-������ ����������� ����� � ���������� ��������� � ������ TI
	
	anl tmod, #00001111b				; ����� ������ �������������� �� ������ 8 ����. TL.x
	orl tmod, #00100000b
	
	mov th1, #C6h						; 1200 ���/�
	
	anl D8H, #7Fh						; ����� BD � ADCON
	anl 87h, #7Fh						; ����� SMOD � PCON
	
	setb tr1
	ret
	
f_usart_start:
	setb es								; 4 ��� �������� ���������� ���������� IEN0
	ret
	
f_interrupt_start:
	setb ea								; 7 ��� �������� ���������� ���������� IEN0
	ret
	
	; input: a
	; output: r2, r1, r0 - ������� ���������� �� �������� � �������� � ���������� ������� ���������
f_a_number_to_digits:
	push a
	push b
	push psw
	
	clr c								; ������ ����� �� �����������
	mov b, #c_dec_modulo
	div ab
	mov r0, a
	mov a, b
	
	mov b, #c_dec_modulo
	div ab
	mov r1, a
	mov a, b
	
	mov b, #c_dec_modulo
	div ab
	mov r2, a
	
	pop psw
	pop b
	pop a
	
	ret
	
	; input: a
	; output: a - ASCII ��� ������� ���������������� �����
f_a_digit_to_char:
	push a
	push psw
	
	clr c
	subb a, #c_dec_modulo
	jnc fi_a_digit_to_char_non_dec		; �������� <= 9
	
	pop psw
	pop a
	
	add a, #c_char_zero
	ret
fi_a_digit_to_char_non_dec:
	pop psw
	pop a
	
	mov a, #c_char_not_a_dec_digit
	ret
	
	; input: a - ����� ��������
	; output: ���� push*2 + jz(false) + (dec + jnz(false)) * (a - 1) + (dec + jnz(true)) + pop*2 + ret
f_sleep:
	push a
	push psw
	
	jz fl_sleep_end
	
f_sleep_dec:
	dec a
	jnz f_sleep_dec
	
fl_sleep_end:
	pop psw
	pop a
	ret

f_sleep_lcd:
	push a
	mov a, #3h							; ���� �������
	lcall f_sleep

	pop a
	ret
	
	; input: dptr - ����� ������ ������
f_concat_start:
	mov g_concat_dest_high, dph
	mov g_concat_dest_low, dpl
	mov g_concat_offset, #0h
	
	ret
	
	; input: a - ������
f_concat_append:
	push dph
	push dpl
	
	mov dph, g_concat_dest_high
	mov dpl, g_concat_dest_low
	
	add dpl, g_concat_offset
	addc dph, #0h
	
	mov @dptr, a
	
	inc g_concat_offset
	
	pop dpl
	pop dph
	
	ret
	
	; input: a - ������, b - ���-��
f_concat_fill:
	push b
	cjne b, #0h
	dec b
	lcall f_concat_append
	pop b
	ret
	
	; input: b - ����� ��������, dptr - ��������
	; output: ��������� �������� ������ ��������� �� ���������
f_concat_copy:
	push b
	push dph
	push dpl
	cjne b, #0h
	dec b
	mov a, @dptr
	inc dptr
	lcall f_concat_append
	pop dpl
	pop dph
	pop b
	ret
	
	; input: a = high, b = low, dptr = � ��� ����������
	; output: z = 0 -> �����
f_cmp_16:
	push a
	push b
	
	clr c
	subb a, dph							; �������� high
	jnz fl_cmp_16_end
	
	mov a, b
	subb a, dpl							; �������� low
	
fl_cmp_16_end:
	pop a
	pop b

	; input: a - ��������, b - ����� ����������� (0 - ���������, 1 - ���������)
	; output: ��
f_lcd:
	push a
	push psw

	mov p4, a
	setb p1.7
	clr p1.6
	
	mov a, b
	mov c, acc.0
	mov p1.4, c
	
	lcall f_sleep_lcd
	clr p1.7
	
	lcall f_sleep_lcd
	setb p1.7
	
	pop psw
	pop a
	ret
	
f_display:
	push a
	push b
	
	mov b, #0h
	
	mov a, #38h
	lcall f_lcd
	
	mov a, #0Ch
	lcall f_lcd
	
	mov a, #80h
	lcall f_lcd
	
	mov b, #1h							; ���������
	
	; line0
	mov dptr, #g_lcd_line0
	
fl_display_loop0:
	movx a, @dptr
	lcall f_lcd
	
	inc dptr
	mov a, dph
	mov b, dpl
	
	push dph
	push dpl
	mov dptr, #g_lcd_line0
	clr c
	add dpl, #c_lcd_line_length
	addc dph, #0h
	
	lcall f_cmp_16
	jnz fl_display_loop0
		
	; ��������� � line1
	mov b, #0h 
	mov a, #C0h
	lcall f_lcd
	
	; line 1
	mov dptr, #g_lcd_line1
	
fl_display_loop1:
	movx a, @dptr
	lcall f_lcd
	
	inc dptr
	mov a, dph
	mov b, dpl
	
	push dph
	push dpl
	mov dptr, #g_lcd_line1
	clr c
	add dpl, #c_lcd_line_length
	addc dph, #0h
	
	lcall f_cmp_16
	jnz fl_display_loop1
	
	pop b
	pop a
	ret

	; input:
	; output: a - ����� ������� ������� [1, 16], 0 ���� �� ������
f_scan_kb:
	push r0
	push r1
	mov r0, #g_kb_out_array
	orl p5, #0Fh						; ��������� �� ����
	mov r1, #7Fh						; ������� ���� 0111 1111
	
fl_scan_kb_loop:
	mov p5, r1							; ������ ������� ����
	
	mov a, p5							; ��������� ���������
	anl a, #0Fh
	
	mov @r0, a							; ��������� ������
	inc r0
	
	mov a, r1							; ��������� ������� ����
	rr a
	mov r1, a
	
	cjne a, #F7h, fl_scan_kb_loop		; ����������� �� 1111 0111
	

	mov r0, #g_kb_out_array				; ��������� ����� ������� �������
	mov r1, #1d							; ������ �������
	
fl_scan_kb_read:
	mov a, @r0							; �������� ���
	xrl a, #0Fh							; ���� ���-�� ������ �� �� z
	jnz fl_scan_kb_number
	
	inc r1								; ��������� �������
	ljmp fl_scan_kb_next
	
fl_scan_kb_number:
	rrc a								; ���� ������ ��� 1 �� �� �� ������ ������
	jc fl_scan_kb_number_finish
	push a								; ������ ��������� ������ ����� ����� �� 4 ������
	mov a, r1
	add a, #4d
	mov r1, a
	pop a
	ljmp fl_scan_kb_number
	
fl_scan_kb_number_finish:
	mov a, r1
	ljmp fl_scan_kb_end
	
fl_scan_kb_next:
	inc r0
	cjne r0, #g_kb_out_array + 4, fl_scan_kb_read
	mov a, #0d							; �� ����� ������� �������, ���������� 0
		
fl_scan_kb_end:
	pop r1
	pop r0
	ret
	
	; input: a - �����, b - ��������
	; output: a - ��������� (a % b)
f_modulo:
	push r0
fl_modulo_sub:
	mov r0, a
	subb a, b							; �������� ���� �� ���������� ����
	jnc fl_modulo_sub
	
	mov a, r0							; ���������� ��������� ����� ��� �����
	pop r0
	ret
