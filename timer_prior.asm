

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
	
; main
	org 8100h
	lcall f_main
	
	; Зависимости:
	
	include asms\utils.asm
	
	; Константы:
	
	c_tick_per_upd:			equ 200d	; тиков в обновлении
	c_tick_per_upd_dec:		equ 199d	; тиков в обновлении минус 1
	c_upd_per_sec:			equ 10d		; обновлений в секунде
	c_sec_per_min:			equ 60d		; секунд в минуте

	c_debug_factor:			equ 50d		; 50 в десятичной системе

	c_timer_period_high		equ FEh		; частота 2 КГц (500 мкс)
	c_timer_period_low		equ 0Bh		;
		
	g_tick_count: 			equ 52h 	; кол-во тиков
	g_update_count:			equ 53h 	; кол-во обновлений
	g_second_count: 		equ 54h 	; кол-во секунд
	g_minute_count: 		equ 55h 	; кол-во минут

	g_debug_tick_count:		equ 56h 	; кол-во обновлений * c_debug_factor

	; Код:
	
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
	
	; приоритеты
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
	lcall f_a_number_to_digits			; r2 r1 r0 = число минут в десятичной
	
	mov a, r1
	lcall f_a_digit_to_char
	lcall f_concat_append
	mov a, r0
	lcall f_a_digit_to_char
	lcall f_concat_append
	
	mov a, #c_e
	lcall f_concat_append
	
	mov a, g_second_count
	lcall f_a_number_to_digits			; r2 r1 r0 = число секунд в десятичной
	
	mov a, r1
	lcall f_a_digit_to_char
	lcall f_concat_append
	mov a, r0
	lcall f_a_digit_to_char
	lcall f_concat_append
	
	; еще 15 свободных мест в line1
	
	lcall f_display
	
	ljmp f_main_loop
	
f_time_update:
	mov a, #c_tick_per_upd_dec
	clr c
	subb a, g_tick_count
	jnc fl_time_update_end				; проверка >= 200 итераций
	
	mov a, g_tick_count
	subb a, #c_tick_per_upd
	mov g_tick_count, a					; вычитаем 200 из числа тиков
	
	lcall f_time_update
	ljmp time_loop

	inc g_update_count
	
	mov a, g_update_count				; счетчик для окон управления
	mov b, #c_debug_factor
	mul ab
	mov g_debug_tick_count, a
	
	mov a, g_update_count
	
	; проверка секунды
	cjne a, #c_upd_per_sec, fl_time_update_end
	inc g_second_count
	
	mov g_update_count, #0h			; сброс счетчика обновлений
	
	; проверка минуты
	mov a, g_second_count
	cjne a, #c_sec_per_min, fl_time_update_end
	inc g_minute_count
	
	mov g_second_count, #0h			; сброс секунд
	
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
	jnb ri, il_usart_end			; проверка запроса RI (игнорируем TI)
	
	push a							; безопасный сеанс связи (сохраняем состояние)
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
	
