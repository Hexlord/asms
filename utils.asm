

	; Легенда:
	;
	; c_* - целочисленные константы, использовать с #
	; g_* - адресные константы (переменные)
	; gb_* - битовые адресные константы (битовые переменные)
	;
	; l_* - код метки, вызывается через ljmp
	; f_* - код функции, вызывается через lcall
	; fl_* - код метки функции, вызывается через ljmp только изнутри функции
	; i_* - код прерывания
	; il_* - код метки прерывания, вызывается только изнутри прерывания
	
	; Сохранение:
	
	; Перезапись:
	
	; Зависимости:
	
	; Константы:
	
	p4:							equ E8h 	
	p5:							equ F8h 	
	
	g_kb_out_array				equ 30h		; занимает 30h - 33h
	
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
	
	g_concat_dest_high			equ 49h		; адрес строки назначения для функции заполнения строки
	g_concat_dest_low			equ 50h		;
	g_concat_offset				equ 51h		; смещение в строке
	
	gb_i0_enabled				equ A8h		;
	gb_i1_enabled				equ AAh		;
	
	
	c_dec_modulo:				equ 10d		; основание десятичной системы счисления
	c_char_zero:				equ 30h		; ASCII смещение до символа нуля
	c_e:						equ 20h		; ASCII пустого символа
	c_char_not_a_dec_digit:		equ 20h		; ASCII символа обозначения не-десятичной цифры
	
	c_lcd_line_length:			equ 20d		; 
	g_lcd_line0:				db #c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e
	g_lcd_line1:				db #c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e

	; Код:
	
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
	
	setb et0							; 1 бит регистра разрешения прерываний IEN0
	setb tr0							; 4 бит регистра управления таймерами TCON
	
	ret
	
f_timer0_stop:
	clr tr0
	ret
	
f_timer1_start:
	clr tr1
	
	mov scon, #11010010b				; 9-битный асинхронный режим с переменной скоростью и флагом TI
	
	anl tmod, #00001111b				; режим работы автогенератора на основе 8 разр. TL.x
	orl tmod, #00100000b
	
	mov th1, #C6h						; 1200 бит/с
	
	anl D8H, #7Fh						; сброс BD в ADCON
	anl 87h, #7Fh						; сброс SMOD в PCON
	
	setb tr1
	ret
	
f_usart_start:
	setb es								; 4 бит регистра разрешения прерываний IEN0
	ret
	
f_interrupt_start:
	setb ea								; 7 бит регистра разрешения прерываний IEN0
	ret
	
	; input: a
	; output: r2, r1, r0 - разряды результата от старшего к младшему в десятичной системе счисления
f_a_number_to_digits:
	push a
	push b
	push psw
	
	clr c								; скорее всего не обязательно
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
	; output: a - ASCII код символа соответствующего цифре
f_a_digit_to_char:
	push a
	push psw
	
	clr c
	subb a, #c_dec_modulo
	jnc fi_a_digit_to_char_non_dec		; проверка <= 9
	
	pop psw
	pop a
	
	add a, #c_char_zero
	ret
fi_a_digit_to_char_non_dec:
	pop psw
	pop a
	
	mov a, #c_char_not_a_dec_digit
	ret
	
	; input: a - время ожидания
	; output: ждем push*2 + jz(false) + (dec + jnz(false)) * (a - 1) + (dec + jnz(true)) + pop*2 + ret
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
	mov a, #3h							; ждем недолго
	lcall f_sleep

	pop a
	ret
	
	; input: dptr - адрес начала строки
f_concat_start:
	mov g_concat_dest_high, dph
	mov g_concat_dest_low, dpl
	mov g_concat_offset, #0h
	
	ret
	
	; input: a - символ
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
	
	; input: a - символ, b - кол-во
f_concat_fill:
	push b
	cjne b, #0h
	dec b
	lcall f_concat_append
	pop b
	ret
	
	; input: b - число символов, dptr - источник
	; output: заполняет активную строку символами из источника
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
	
	; input: a = high, b = low, dptr = с чем сравниваем
	; output: z = 0 -> равны
f_cmp_16:
	push a
	push b
	
	clr c
	subb a, dph							; сравнили high
	jnz fl_cmp_16_end
	
	mov a, b
	subb a, dpl							; сравнили low
	
fl_cmp_16_end:
	pop a
	pop b

	; input: a - значение, b - режим отображения (0 - настройка, 1 - отрисовка)
	; output: на
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
	
	mov b, #1h							; отрисовка
	
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
		
	; переходим к line1
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
	; output: a - номер нажатой клавиши [1, 16], 0 если не нажата
f_scan_kb:
	push r0
	push r1
	mov r0, #g_kb_out_array
	orl p5, #0Fh						; настройка на ввод
	mov r1, #7Fh						; бегущий ноль 0111 1111
	
fl_scan_kb_loop:
	mov p5, r1							; подаем бегущий ноль
	
	mov a, p5							; считываем результат
	anl a, #0Fh
	
	mov @r0, a							; заполняем память
	inc r0
	
	mov a, r1							; следующий бегущий ноль
	rr a
	mov r1, a
	
	cjne a, #F7h, fl_scan_kb_loop		; остановимся на 1111 0111
	

	mov r0, #g_kb_out_array				; вычисляем номер нажатой клавиши
	mov r1, #1d							; первый столбец
	
fl_scan_kb_read:
	mov a, @r0							; выходной код
	xrl a, #0Fh							; если что-то нажато то не z
	jnz fl_scan_kb_number
	
	inc r1								; следующий столбец
	ljmp fl_scan_kb_next
	
fl_scan_kb_number:
	rrc a								; если правый бит 1 то мы на нужной строке
	jc fl_scan_kb_number_finish
	push a								; каждая следующая строка имеет номер на 4 больше
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
	mov a, #0d							; не нашли нажатую клавишу, возвращаем 0
		
fl_scan_kb_end:
	pop r1
	pop r0
	ret
	
	; input: a - число, b - делитель
	; output: a - результат (a % b)
f_modulo:
	push r0
fl_modulo_sub:
	mov r0, a
	subb a, b							; вычитаем пока не произойдет заем
	jnc fl_modulo_sub
	
	mov a, r0							; возвращаем последнее число без заема
	pop r0
	ret
