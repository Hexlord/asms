

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
	
; main
	org 8100h
	lcall f_main
	
	; �����������:
	
	include asms\utils.asm
	
	; ���������:
	
	c_tick_per_upd:			equ 200d	; ����� � ����������
	c_tick_per_upd_dec:		equ 199d	; ����� � ���������� ����� 1
	c_upd_per_sec:			equ 10d		; ���������� � �������
	c_sec_per_min:			equ 60d		; ������ � ������

	c_debug_factor:			equ 50d		; 50 � ���������� �������

	c_timer_period_high		equ FEh		; ������� 2 ��� (500 ���)
	c_timer_period_low		equ 0Bh		;
		
	g_tick_count: 			equ 52h 	; ���-�� �����
	g_update_count:			equ 53h 	; ���-�� ����������
	g_second_count: 		equ 54h 	; ���-�� ������
	g_minute_count: 		equ 55h 	; ���-�� �����

	g_debug_tick_count:		equ 56h 	; ���-�� ���������� * c_debug_factor

	; ���:
	
f_main:
	mov dptr, #i_timer0_tick
	mov g_timer0_cb_interrupt_high, dph
	mov g_timer0_cb_interrupt_low, dpl
	
	mov dptr, #i_usart_tick
	mov g_usart_cb_interrupt_high, dph
	mov g_usart_cb_interrupt_low, dpl
	
	mov dptr, #i_interrupt0
	mov g_i0_cb_interrupt_high, dph
	mov g_i0_cb_interrupt_low, dpl
	
	mov dptr, #i_interrupt1
	mov g_i1_cb_interrupt_high, dph
	mov g_i1_cb_interrupt_low, dpl
	
	setb gb_i0_enabled
		
	lcall f_usart_start
	lcall f_interrupt_start
	lcall f_timer0_start
	
	; ����������
	mov a, #00010010b
	orl A9h, a
	mov a, #11101101b
	anl B9h, a
	mov a, #00000010b
	orl B9h, a
	
f_main_loop:

	lcall f_time_update
	
	mov a, g_minute_count
	lcall f_a_number_to_digits
	
	mov dptr, #g_lcd_line0
	lcall f_concat_start
	
	mov a, #c_e
	mov b, #c_lcd_line_length
	lcall f_concat_fill
	
	mov a, g_minute_count
	lcall f_a_number_to_digits			; r2 r1 r0 = ����� ����� � ����������
	
	mov a, r1
	lcall f_a_digit_to_char
	lcall f_concat_append
	mov a, r0
	lcall f_a_digit_to_char
	lcall f_concat_append
	
	mov a, #c_e
	lcall f_concat_append
	
	mov a, g_second_count
	lcall f_a_number_to_digits			; r2 r1 r0 = ����� ������ � ����������
	
	mov a, r1
	lcall f_a_digit_to_char
	lcall f_concat_append
	mov a, r0
	lcall f_a_digit_to_char
	lcall f_concat_append
	
	; ��� 15 ��������� ���� � line1
	
	lcall f_display
	
	ljmp f_main_loop
	
f_time_update:
	mov a, #c_tick_per_upd_dec
	clr c
	subb a, g_tick_count
	jnc fl_time_update_end				; �������� >= 200 ��������
	
	mov a, g_tick_count
	subb a, #c_tick_per_upd
	mov g_tick_count, a					; �������� 200 �� ����� �����
	
	lcall f_time_update
	ljmp time_loop

	inc g_update_count
	
	mov a, g_update_count				; ������� ��� ���� ����������
	mov b, #c_debug_factor
	mul ab
	mov g_debug_tick_count, a
	
	mov a, g_update_count
	
	; �������� �������
	cjne a, #c_upd_per_sec, fl_time_update_end
	inc g_second_count
	
	mov g_update_count, #0h			; ����� �������� ����������
	
	; �������� ������
	mov a, g_second_count
	cjne a, #c_sec_per_min, fl_time_update_end
	inc g_minute_count
	
	mov g_second_count, #0h			; ����� ������
	
fl_time_update_end:
	ret
	
i_timer0_tick:
	mov TH0, #c_timer_period_high
	mov TL0, #c_timer_period_low
	inc g_tick_count
	
	pop dpl
	pop dph
	reti
	
i_usart_tick:
	jnb ri, il_usart_end			; �������� ������� RI (���������� TI)
	
	push a							; ���������� ����� ����� (��������� ���������)
	push 0
	push psw
	lcall 128h
	clr ri
	pop psw
	pop 0
	pop a
	
il_usart_end:
	
	pop dpl
	pop dph
	reti
	
i_interrupt0:
	clr gb_i0_enabled
	setb gb_i1_enabled
	lcall f_timer0_start
	
	pop dpl
	pop dph
	reti
	
i_interrupt1:
	clr gb_i1_enabled
	setb gb_i0_enabled
	lcall f_timer0_stop
	
	pop dpl
	pop dph
	reti
	
