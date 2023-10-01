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
            ; Check for EMM using the "open handle" technique
            mov     ax, 3D00h       ; open handle, read-only
            mov     dx, offset device_name  ; device/path name
            int     21h             ; call DOS
            jc      noemmQuit       ; open error if carry flag is set

            mov     bx, ax          ; save file handle in BX
            mov     ax, 4400h       ; IOCTL - get device information
            int     21h             ; call DOS
            jc      noemmQuit       ; error if carry flag is set

            test    dx, 80h         ; bit 7 of DX is 1 if device, 0 if file
            jz      noemmQuit       ;

            mov     ax, 4407h       ; IOCTL - get output status
            ;; file handle is already in BX
            int     21h             ; call DOS
            jc      noemmQuit       ; error if carry flag is set
            push    ax              ; save IOCTL status
            mov     ah, 3Eh         ; close handle
            int     21h             ; call DOS
            pop     ax              ; restore IOCTL status
            cmp     al, 0FFh        ; check for "device ready" status
            je      emmOk           ; continue if status = 0FFh
noemmQuit:
            disp_str noems_msg
            mov     al, 1           ; return code 1
            jmp     exeQuit         ; terminate

emmOk:
            mov     ax, 4000h       ; Check EMM status
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
            mov     al, 1       ; Return errcode 1

exeQuit:    mov     ah, 4Ch
            int     21h
main        endp

;========================================================= Data segment
;
.data

device_name db      'EMMXXXX0', 0
start_msg   db      'FixEMM v.0.1, (c) Davide Bresolin 2023.', 0dh, 0ah, '$'
noems_msg   db      'No Expanded Memory Manager! Aborting.', 0dh, 0ah, '$'
err_msg     db      'Error! Aborting.', 0dh, 0ah, '$'
ok_msg      db      'OS/E functions disabled.', 0dh, 0ah, '$'

end     main
