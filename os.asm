

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
	
	c_timer_period_high		equ FEh		; ������� 2 ��� (500 ���)
	c_timer_period_low		equ 0Bh		;
	
	c_task_count			equ 3d		;
			
	g_current_task			equ 52h		; 0, 1, 2
	g_pressed_key			equ 53h		; 0, [1, 16]
	g_pressed_key_char0		equ 54h		; 
	g_pressed_key_char1		equ 55h		; 

	; ���:
	
f_main:
	lcall f_init_os
	
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
	
	mov a, g_current_task
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
	
	lcall f_os_update
	
	pop dpl
	pop dph
	reti
	
l_prog0:								; ��������� ������ ������� �������
	cpl p1.1
	lcall f_scan_kb
	mov g_pressed_key, a
	ljmp l_prog0
	
l_prog1:								; ��������� �������������� � ASCII
	cpl p1.2
	mov a, g_pressed_key
	lcall f_a_number_to_digits			; r2 r1 r0 - ����� ������� �������
	
	mov a, r1 
	lcall f_a_digit_to_char
	mov g_pressed_key_char1, a
	
	mov a, r0 
	lcall f_a_digit_to_char
	mov g_pressed_key_char0, a
	
	ljmp l_prog1
	
l_prog2:								; ��������� ���������
	cpl p1.3
	
	mov dptr, #g_lcd_line0
	lcall f_concat_start
	
	mov a, #c_e
	mov b, #c_lcd_line_length
	lcall f_concat_fill
	
	mov a, g_pressed_key_char1
	lcall f_concat_append
	mov a, g_pressed_key_char0
	lcall f_concat_append
	
	; ��� 18 ��������� ���� � line1
	
	lcall f_display
	
	ljmp l_prog2
	
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
	
	mov dptr, #l_prog2
	mov a, dph
	mov b, dpl
	mov dptr, #d_prog2 + #8d
	mov @dptr, b
	inc dptr
	mov @dptr, a
	
	ret
	
	; �������� ������� ��� ������ ��������� �����
d_prog0:	db 11h, 1,0,0,0,0,0,0, 00, 00, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

d_prog1:	db 11h, 1,0,0,0,0,0,0, 00, 00, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

d_prog2:	db 11h, 1,0,0,0,0,0,0, 00, 00, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

	
