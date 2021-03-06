PUBLIC OUTPUT_BINARY_NUMBER
PUBLIC OUTPUT_OCTAL_NUMBER

EXTRN number: byte

SC1 SEGMENT para public 'CODE'
	assume CS:SC1
OUTPUT_BINARY_NUMBER proc near ; Процедура (Описание).
	MOV AX, seg number
	MOV ES, AX

	MOV CX, 4 ; Т.к. максимальное это FFFF.
	XOR BX, BX
	XOR SI, SI

	; Выводим \n.
	MOV AH, 02h
	MOV DL, 10
	INT 21h
	MOV DL, 13
	INT 21h

OUTPUT_B:	
	CMP ES:number[SI], '$'  
	; Если number[SI] == $ (Спец. символу),
	; То возвращаемся в main.
	JE END_OUTPUT_BINARY

	MOV BH, ES:number[SI]   

	; Сдвигаем BH влево на 4.
	; Это приведет к тому, что мы подвинем
	; значение на один бит влево.
	; Было: 0F Станет: F0.
	; Это нам нужно, потому что
	; Числа в массиве хранятся данным образом:
	; Записано значение в младшем бите,
	; Т.е. все числа там записаны от 00 (0) до 0F (15).
	MOV CL, 4
	SHL BH, CL
	MOV CL, 0

	; Теперь нам нужно вывести само 
	; Значение в 2-ом с.с., для этого
	; Мы сдвигаем значение 4 раза влево и
	; Во время каждого сдвига проверяем:
	; Если был перенос (Т.е. там была единица)
	; То выводим единицу.
	; Иначе там был ноль (Выводим ноль).
	; Пример: F представляется как 1111,
	; Тогда каждый раз, когда мы сдвигаем его влево 
	; У нас происходит перенос, мы это замечаем и выводим единицу.
	; Если же переноса не было - выводим ноль.
	MOV CX, 4
next_b:
	; Сдвигаем влево. 
	SHL BH, 1
	JC one
	; Если не было переноса (Помещаем в DL '0').
	MOV DL, '0'
	; Переходим к выводу.
	JMP print

one:
	; Если был перенос (Помещаем в DL '1').
	MOV DL, '1'

print:
	; Выводим то, что лежит в DL.
	MOV AH, 02h
	INT 21h
	LOOP next_b

	; Увеличиваем SI (Чтобы получить след. значение)
	INC SI
	JMP OUTPUT_B	 

END_OUTPUT_BINARY:
	RET
OUTPUT_BINARY_NUMBER endp ; Конец процедуры.
SC1 ENDS


SC1 SEGMENT para public 'CODE'
	assume CS:SC1
OUTPUT_OCTAL_NUMBER proc near
	MOV AX, seg number
	MOV ES, AX

	MOV CX, 4 
	XOR BX, BX
	XOR SI, SI

	; Выводим \n.
	MOV AH, 02h
	MOV DL, 10
	INT 21h
	MOV DL, 13
	INT 21h

    XOR AX, AX
	XOR DX, DX

	CMP ES:number[SI], '$'  
	; Если number[I] == $ (Спец. символу). то:
	JE end_output_8

	MOV AL, ES:number[SI]
	; Переводим в регистр (AX), то
	; Что лежит в массиве.
	; В массиве символы
	; Записанны данным образом: 
	; 0F 01 0A $   
	; Тогда мы итерируемся 
	; (Каждый раз увеличиваем SI)
	; По массиву до тех пор, пока что
	; Не встретим '$'.
	; В начале регистр выглядит следующим образом:
	; В AX лежит лежит первый символ из массива
	; 000X (Где X это 01 or 02 or ... or 0F)
	; Если в массиве есть еще символы,
	; То мы сдвигаем регистр (AX) 4 раза влево
	; Получаем 00X0
	; И к нему прибавляем, то, что лежит на 
	; Данной итерации в массиве, т.е.
	; 00X0 + 000Y = 00XY, Где X и Y значения массива. 
	; В итоге в регистре AX лежит значение, которое ввел пользователь.
translation:
	INC SI
	CMP ES:number[SI], '$'  
	JE break
	MOV CL, 4
	SHL AX, CL
	MOV	DL, ES:number[SI]
	ADD AX, DX
	JMP translation

	; Вывод числа в 8 с.с.
break:
	; Записываем наше число в BX.
	MOV BX, AX
	TEST BX, 8000h ;8000h == 1000 0000 0000 0000 (Чтобы узнать старший бит числа).
	JZ output ; Если ноль (значит число положительное), то сразу выводим его.

	; Если число отрицательное (Старший бит '1').
	; Выводим '-'. 
	MOV AH, 02h
    MOV DL, '-'
    INT 21h
	; Инвертируем и прибавляем единицу.
	NOT BX
	ADD BX, 1
	  

	; Вывод числа по триадам.
	; DL - явлеятся неким 'носителем' 
	; последних трех битов числа.	
	; CH - счетчик, чтобы потом знать, сколько цифр выводить.
	; Алгоритм:
	; Мы узнаем последие 3 бита числа.
	; Записываем их в стек 
	; (т.к. если выводить сразу, то они 
	; будут выводиться в обратном порядке)
	; После чего увеличиваем CH 
	; (Чтобы потом из стека достать CH раз (LOOP сделать CH раз)).
	; Потом сдвигаем число BX вправо 3 раза 
	; (Чтобы узнать следующий триад).
output:
	MOV CH, 0 ; Счетчик.

next:
	MOV DL, 7 ; Записываем в DL 0000 0000 0000 0111
	AND DL, BL ; Триады. Узнаем последние 3 бита числа. (Они будут лежать в DL).
	PUSH DX ; Помещаем их в стек.
	; Сдвигаем число на три позиции вправо.
	MOV CL, 3
	SHR BX, CL
	; Увеличиваем счетчик.
	INC CH
	CMP BX, 0
	JNE next ; Если BX != 0, продолжаем.

	; Непосредственно сам вывод:
	; Записываем в CX то, что насчитали.
	MOV CL, CH
	MOV CH, 0
    MOV AH, 02h ; Вывод на экран символ, который находится в DL.
output_8:
	; Достаем очередное значение из стека и записываем в DX.
	POP DX
	; Выводим DL в понятном для нас виде. 
    ADD DL, '0'
    INT 21h
	LOOP output_8 

end_output_8:
	RET
OUTPUT_OCTAL_NUMBER endp
SC1 ENDS
END




; 	; Вывод числа в 8 с.с. (С помощью стека) 
; break:
;     XOR CX, CX
;     MOV BX, 8 ; основание с.c.
; division:
; 	; Т.к. мы делим на регистр из 2 байт(BX)
; 	; То деление будет происходить следующим образом:
; 	; Процессор поделит число, старшие биты которого 
; 	; Хранит регистр dx, а младшие ax на значение,
; 	; Хранящееся в регистре bx.
; 	; Поэтому значение DX нам нужно занулить 
; 	; (Тогда при делении будет участвовать только AX).
;     XOR DX, DX
; 	; Делим число (AX) на основание с.с. (BX).
;     DIV BX
; 	; Результат от деления запишется в регистр AX.
; 	; В стек помещаем остаток (DX).
;     PUSH DX
; 	; Увеличиваем CX 
; 	; Счетчик нужен для того, чтобы знать
; 	; Сколько потом цифр выводить (Брать из стека).
;     INC CX

; 	; Команда TEST выполняет логическое И между
; 	; Всеми битами двух операндов. Результат никуда не 
; 	; Записывается, команда влияет только на флаги.
; 	; ZF будет установлен только в том случае
; 	; Если все биты равны 0 (Результат)
;     TEST AX, AX
; 	; ZF - флаг/признак нулевого результата (Zero),
; 	; Устанавливается в 1, если получен нулевой результат, иначе (ZF)=0.
;     JNZ division ; ZF != 0 (Если не ноль, продолжаем деление)

; 	; Вывод:
;     MOV AH, 02h
; OUTPUT_O:
; 	; Достаем очередное значение из стека.
; 	; И помещаем в DX.
;     POP DX
; 	; Выводим его в понятном для нас виде. 
;     ADD DL, '0'
;     INT 21h
; 	; Повторим ровно столько раз, сколько цифр насчитали. (Для этого увеличивали CX)
;     LOOP OUTPUT_O