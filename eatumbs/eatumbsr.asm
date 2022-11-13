I_GROUP group I_ASMTEXT

I_ASMTEXT SEGMENT PARA PUBLIC 'INIT'

ASSUME CS:I_ASMTEXT

public _MPlex, int2d_handler_, _OldInt2D, END_int2d_handler_

; SEGMENT_START:
TSR_Sig     db  'DB      ', 'eatUMBS ', 'limits available upper memory', 00
TSR_Ver     dw  (1 SHL 8) + 0   ; (major shl 8) + minor
_MPlex      db  ?               ; multiplex ID
HookTable   db  02dh
            dw  int2d_handler_

int2d_handler_:
    jmp short ahead     ; short jump ahead 16 bytes
_OldInt2D   dd 0        ; next ISR in chain
    dw  424bh           ; magic number
    db  0               ; 0 (80) if soft(hard)ware int
    jmp short hw_reset  ; short jump to hardware reset
    db  7 dup (0)       ; pad to 16 bytes
ahead:
    cmp       ah, cs:_MPlex     ; my multiplex ID?
	jz  for_me                  ; yes
	jmp [cs:_OldInt2D]          ; no, jump to next in chain
for_me:
    cmp al, 0                   ; Installation check?
    je  int2d_0                 ; yes
    cmp al, 2                   ; Uninstall ?
    jb  not_impl                ; function 1 not implemented
    je  int2d_2                 ; yes
    cmp al, 4                   ; determine chained interrupts?
    jne not_impl                ; no, not implemented
                                ; returns AL=04h
    mov dx, cs                  ; DX:BX points to interrupt hook list
    mov bx, offset HookTable
    jmp int2d_end    
int2d_0:                        ; Installation check
    dec al                      ; set AL = FF
    mov cx, cs:TSR_Ver          ; CH = major; CL = minor
    mov dx, cs                  ; DX:DI points to sig string
    mov di, offset TSR_Sig
    jmp int2d_end
int2d_2:                        ; Uninstall
;	mov	al,3			        ; safe to remove, no resident uninstaller
	inc	al			            ; AL was 02h, now 03h
	mov bx, cs                  ; BX = segment of memory block with resident code
    jmp int2d_end
not_impl:
    xor al, al                  ; returns AL=0 - not implemented
int2d_end:	
	iret

; Required for IBM Interrupt Sharing Protocol. Normally it is used
; only by hardware interrupt handlers.
hw_reset:
    retf
    
END_int2d_handler_:
	nop

I_ASMTEXT ENDS

END




