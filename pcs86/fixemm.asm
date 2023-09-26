;======================================================================
; Program: fixemm.asm
;
; By Davide Bresolin
;
; A small program to disable LIM EMS functions 26, 28 and 30.
;
; A bug in either QEMM or the EMM driver of the Olivetti PCS 86
; hangs the system when EMS function 28 is called and both upper
; memory and EMS is available. This program fixes the issue
; by disabling functions 26, 28 and 30, as per the LIM EMS 4.0
; standard. Those functions are reserved for the operating system
; and are rarely used by programs. One exception is Windows 3.0
; that is affected by the bug.
;
; Assemble and link with TASM/TLINK, WASM/WLINK or JWASM.
;
;========================================================= Declarations
.8086 ; cpu type
.model small
.stack 200h ; Open Watcom linker requires a minimum stack of 512 bytes

;=============================================================== Macros
;
disp_str    macro   str_ofs     ; Print $-terminated string at str_ofs
            mov     ah, 09h
            mov     dx, offset str_ofs
            int     21h
            endm

;============================================================ MAIN CODE
;
.code

main        proc
            push    ds              ; save PSP value
            mov     ax, @data       ; point DS at the data segment
            mov     ds, ax
            disp_str start_msg
            mov     ax, 4000h       ; Check for EMM
            int     67h
            or      ah, ah
            jnz     errorQuit
            mov     ax, 5D01h       ; Disable functions 26, 28 and 30
            int     67h
            or      ah, ah          ; AH = 0 on success
            jnz     errorQuit
            disp_str ok_msg
            jmp     exeQuit

errorQuit:  disp_str err_msg

exeQuit:    mov     ax, 4C00h
            int     21h
main        endp

;========================================================= Data segment
;
.data

start_msg   db      'FixEMM v.0.1, (c) Davide Bresolin 2023.', 0dh, 0ah, '$'
err_msg     db      'Error! Aborting.', 0dh, 0ah, '$'
ok_msg      db      'OS/E functions disabled.', 0dh, 0ah, '$'

end     main
