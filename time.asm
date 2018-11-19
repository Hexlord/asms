

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

	c_timer_period_high		equ FEh		; ������� 2 ��� (500 ���)
	c_timer_period_low		equ 0Bh		;
		
	g_tick_count: 			equ 52h 	; ���-�� �����
	g_update_count:			equ 53h 	; ���-�� ����������
	g_second_count: 		equ 54h 	; ���-�� ������
	g_minute_count: 		equ 55h 	; ���-�� �����

	; ���:
	
f_main:
	mov dptr, #i_timer0_tick
	mov g_timer0_cb_interrupt_high, dph
	mov g_timer0_cb_interrupt_low, dpl
	
	lcall f_timer0_start
	
fl_main_loop:
	
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
	
	ljmp fl_main_loop
	
f_time_update:
	
	mov a, #c_tick_per_upd_dec
	clr c
	subb a, g_tick_count
	jnc fl_time_update_end					; �������� >= 200 ��������
	
	mov a, g_tick_count
	subb a, #c_tick_per_upd
	mov g_tick_count, a						; �������� 200 �� ����� �����

	inc g_update_count
	
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
	
