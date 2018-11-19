

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
	; r0, r1 � f_os_update �� ���������� �������
	
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
	
	c_max_message_length	equ 40d		;
		
	g_tick_count: 			equ 52h 	; ���-�� �����
	g_update_count:			equ 53h 	; ���-�� ����������
	g_second_count: 		equ 54h 	; ���-�� ������
	g_minute_count: 		equ 55h 	; ���-�� �����
	
	c_task_count			equ 2d		;
	c_symbol_timeout		equ 2d		; ������� �������� ������� � �������� (�� ����� 2, ��� ��� ����������� [0, -1))
			
	g_current_task			equ 56h		; 0, 1
	g_symbol_received_count equ 57h		; ������� ���������� ��������
	gb_symbols_finished		equ 58h		; ���� ��������� ������� (�������� 40 �������� ��� �����)
	g_last_symbol_time		equ 59h		; ����� ��������� ���������� ������� � ��������
	
	; ���������� �����
	g_line0:			db #c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e
	g_line1:			db #c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e

	; ���:
	
f_main:
	lcall f_init_os
	
	mov g_last_symbol_time, #0d
	mov g_symbols_received, #0d
	clr gb_symbols_finished
	
	mov dptr, #i_timer0_tick
	mov g_timer0_cb_interrupt_high, dph
	mov g_timer0_cb_interrupt_low, dpl
	
	lcall f_timer0_start
	ljmp l_prog0
	
f_load_descriptor_addr:
	push a
	push b
	mov dptr, #d_prog0
	mov a, g_current_task
	mov b, #18d						; ���������� �������� 18 ����
	mul ab
	
	clr c							; ���������� ��������
	add a, dpl
	mov dpl, a
	mov a, #0h
	add a, dph 						; � ������ ��������
	mov dph, a
	
	pop b
	pop a
	ret
	
f_os_update:
	push dph
	push dpl
	push psw
	push a
	push b
	push 0
	push 1
	
	lcall f_load_descriptor_addr
	
	mov r0, sp
	inc r0
	
	mov r1, #0h						; ����� � ������
fl_os_update_loop0:					; ���� ���������� ����������� ������� ����������
	mov a, @r1
	movx @dptr, a
	inc r1
	inc dptr
	djnz r0, fl_os_update_loop0
	
	mov a, g_current_task			; ������������ �����
	inc a
	mov b, #c_task_count
	lcall f_modulo
	mov g_current_task, a
	
	; ����� ���������
	lcall f_load_descriptor_addr
	
	mov r1, #0h
fl_os_update_loop1:					; ���� �������� ��������� �� �����������
	movx a, @dptr
	mov @r1, a
	inc r1
	inc dptr
	djnz r0, fl_os_update_loop1
	
	dec r1
	mov sp, r1
	pop 1
	pop 0
	pop b
	pop a
	pop psw
	pop dpl
	pop dph
	
	ret
	
i_timer0_tick:
	mov TH0, #c_timer_period_high
	mov TL0, #c_timer_period_low
	inc g_tick_count
	
	lcall f_time_update
	lcall f_os_update
	
	pop dpl
	pop dph
	reti
		
f_receive:
	jnb ri, f_receive					; ������� ����� ������ (������������)
	mov a, sbuf	
	clr ri
	ret
	
	; output: a - ����� � ��������
f_time:
	mov a, g_minute_count
	mov b, #c_sec_per_min
	mul ab
	
	ret
	
f_send:
	jnb ti, f_send						; ������� ���������� ����. �������� (������������)
	mov sbuf, a
	clr ti
	ret
	
	; input: a - ������
f_process_symbol:
	push dph
	push dpl
	
	mov dptr, #g_lcd_line0
	
	add dpl, g_symbol_received_count
	addc dph, #0d
	
	mov @dptr, a
	
	pop dpl
	pop dph
	ret
	
l_prog0:								; ��������� �����
	cpl p1.1
	
	; ��������� �������
	clr g_symbols_finished
	
	mov dptr, #g_line0					; ������� ������
	lcall f_concat_start
	
	mov a, #c_e
	mov b, #c_lcd_line_length
	lcall f_concat_fill
	lcall f_concat_fill
	
l_prog0_rcv_loop:
	lcall f_time
	mov g_last_symbol_time, a
	
	lcall f_receive
	lcall f_process_symbol
	lcall f_send
	jnb g_symbols_finished, l_prog0_rcv_loop
		
l_prog0_render:							; ���������
	mov dptr, #g_lcd_line0
	lcall f_concat_start
	
	mov dptr, #g_line0					; �������� ��������� � �����������
	mov b, #c_max_message_length
	lcall f_concat_copy
	
	lcall f_display
	
	ljmp l_prog0
	
f_error_text:
	mov dptr, #g_line0					; ������� ������
	lcall f_concat_start
	
	mov a, #c_e
	mov b, #c_lcd_line_length
	lcall f_concat_fill
	lcall f_concat_fill
	
	mov a, #??h;						; ������ ������
	lcall f_concat_append
	mov a, #??h;						; ������ ������
	lcall f_concat_append
	mov a, #??h;						; ������ ������
	lcall f_concat_append
	mov a, #??h;						; ������ ������
	lcall f_concat_append
	mov a, #??h;						; ������ ������
	lcall f_concat_append
	mov a, #??h;						; ������ ������
	lcall f_concat_append
	ret
	
l_prog1:								; ��������� �������� ������
	cpl p1.2
	
	jb g_symbols_finished, l_prog1		; ��� ��������� �������
	
	lcall f_time
	clr c
	subb a, g_last_symbol_time
	subb a, c_symbol_timeout + #1d
	jc l_prog1							; �������� �������� �� �������
	
	lcall f_error_text					; ��������� �� ������
	setb g_symbols_finished
	
	mov dptr, #l_prog0_render			; ���������� receive � ������� � ���������
	mov a, dph
	mov b, dpl
	mov dptr, #d_prog0 + #8d
	mov @dptr, b
	inc dptr
	mov @dptr, a
	
	ljmp l_prog1
	
f_init_os:
	mov g_current_task, #0h
	
	; ���������� ������ ������� � �����������
	mov dptr, #l_prog0
	mov a, dph
	mov b, dpl
	mov dptr, #d_prog0 + #8d
	mov @dptr, b
	inc dptr
	mov @dptr, a
	
	mov dptr, #l_prog1
	mov a, dph
	mov b, dpl
	mov dptr, #d_prog1 + #8d
	mov @dptr, b
	inc dptr
	mov @dptr, a
	
	ret
	
	; �������� ������� ��� ������ ��������� �����
d_prog0:	db 11h, 1,0,0,0,0,0,0, 00, 00, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

d_prog1:	db 11h, 1,0,0,0,0,0,0, 00, 00, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

	
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