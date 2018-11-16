

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
	; r0, r1 в f_os_update по прерыванию таймера
	
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

	c_timer_period_high		equ FEh		; частота 2 КГц (500 мкс)
	c_timer_period_low		equ 0Bh		;
	
	c_max_message_length	equ 40d		;
		
	g_tick_count: 			equ 52h 	; кол-во тиков
	g_update_count:			equ 53h 	; кол-во обновлений
	g_second_count: 		equ 54h 	; кол-во секунд
	g_minute_count: 		equ 55h 	; кол-во минут
	
	c_task_count			equ 2d		;
	c_symbol_timeout		equ 2d		; таймаут ожидания символа в секундах (не менее 2, так как погрешность [0, -1))
			
	g_current_task			equ 56h		; 0, 1
	g_symbol_received_count equ 57h		; счетчик полученных символов
	gb_symbols_finished		equ 58h		; флаг окончания посылки (получены 40 символов или точка)
	g_last_symbol_time		equ 59h		; время получения последнего символа в секундах
	
	; полученный текст
	g_line0:			db #c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e
	g_line1:			db #c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e,#c_e

	; Код:
	
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
	mov b, #18d						; дескриптор занимает 18 байт
	mul ab
	
	clr c							; прибавляем смещение
	add a, dpl
	mov dpl, a
	mov a, #0h
	add a, dph 						; с учетом переноса
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
	
	mov r1, #0h						; адрес в памяти
fl_os_update_loop0:					; цикл перезаписи дескриптора текущим контекстом
	mov a, @r1
	movx @dptr, a
	inc r1
	inc dptr
	djnz r0, fl_os_update_loop0
	
	mov a, g_current_task			; переключение задач
	inc a
	mov b, #c_task_count
	lcall f_modulo
	mov g_current_task, a
	
	; смена контекста
	lcall f_load_descriptor_addr
	
	mov r1, #0h
fl_os_update_loop1:					; цикл загрузки контекста из дескриптора
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
	jnb ri, f_receive					; ожидаем конца приема (блокирование)
	mov a, sbuf	
	clr ri
	ret
	
	; output: a - время в секундах
f_time:
	mov a, g_minute_count
	mov b, #c_sec_per_min
	mul ab
	
	ret
	
f_send:
	jnb ti, f_send						; ожидаем завершения пред. передачи (блокирование)
	mov sbuf, a
	clr ti
	ret
	
	; input: a - символ
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
	
l_prog0:								; программа приёма
	cpl p1.1
	
	; получение посылки
	clr g_symbols_finished
	
	mov dptr, #g_line0					; очистим буффер
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
		
l_prog0_render:							; отрисовка
	mov dptr, #g_lcd_line0
	lcall f_concat_start
	
	mov dptr, #g_line0					; копируем сообщение в видеобуффер
	mov b, #c_max_message_length
	lcall f_concat_copy
	
	lcall f_display
	
	ljmp l_prog0
	
f_error_text:
	mov dptr, #g_line0					; очистим буффер
	lcall f_concat_start
	
	mov a, #c_e
	mov b, #c_lcd_line_length
	lcall f_concat_fill
	lcall f_concat_fill
	
	mov a, #??h;						; вводим Ошибка
	lcall f_concat_append
	mov a, #??h;						; вводим Ошибка
	lcall f_concat_append
	mov a, #??h;						; вводим Ошибка
	lcall f_concat_append
	mov a, #??h;						; вводим Ошибка
	lcall f_concat_append
	mov a, #??h;						; вводим Ошибка
	lcall f_concat_append
	mov a, #??h;						; вводим Ошибка
	lcall f_concat_append
	ret
	
l_prog1:								; программа контроля ошибки
	cpl p1.2
	
	jb g_symbols_finished, l_prog1		; нет ожидаемой посылки
	
	lcall f_time
	clr c
	subb a, g_last_symbol_time
	subb a, c_symbol_timeout + #1d
	jc l_prog1							; проверка набрался ли таймаут
	
	lcall f_error_text					; сообщение об ошибке
	setb g_symbols_finished
	
	mov dptr, #l_prog0_render			; прерывание receive и переход к отрисовке
	mov a, dph
	mov b, dpl
	mov dptr, #d_prog0 + #8d
	mov @dptr, b
	inc dptr
	mov @dptr, a
	
	ljmp l_prog1
	
f_init_os:
	mov g_current_task, #0h
	
	; записываем адреса програм в дескрипторы
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
	
	; запасёмся памятью для случая глубокого стека
d_prog0:	db 11h, 1,0,0,0,0,0,0, 00, 00, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

d_prog1:	db 11h, 1,0,0,0,0,0,0, 00, 00, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

	
f_time_update:
	
	mov a, #c_tick_per_upd_dec
	clr c
	subb a, g_tick_count
	jnc fl_time_update_end					; проверка >= 200 итераций
	
	mov a, g_tick_count
	subb a, #c_tick_per_upd
	mov g_tick_count, a						; вычитаем 200 из числа тиков

	inc g_update_count
	
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