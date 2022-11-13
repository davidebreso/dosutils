;-----------------------------------------------------------------------
; NOLPT.ASM	Public Domain 1992, 1995 Ralf Brown
;		You may do with this software whatever you want, but
;		common courtesy dictates that you not remove my name
;		from it.
;
; Trap output to a particular printer port and always return 'ready'
; or success, even if no printer is attached.
;
; Version 0.92
; LastEdit: 9/24/95
;-----------------------------------------------------------------------

	INCLUDE AMIS.MAC

	@Startup 2,00           	; need DOS 2.00                  
					; this macro also takes care of declaring
					; all the segments in the required order

;-----------------------------------------------------------------------
;
VERSION_NUM equ 005Ch	; v0.92
VERSION_STR equ "0.92"

;-----------------------------------------------------------------------
;
; useful macros
;
LODSB_ES MACRO
	DB 26h,0ACh	; LODSB ES:
	ENDM

;-----------------------------------------------------------------------
; Put the resident code into its own segment so that all the offsets are
; proper for the new location after copying it into a UMB or down into
; the PSP.
;
TSRcode@

;-----------------------------------------------------------------------
; Declare the interrupt vectors hooked by the program, then set up the
; Alternate Multiplex Interrupt Spec handler
;
	HOOKED_INTS 17h			; hooking INT 17h in add. to INT 2Dh
	ALTMPX	'Ralf B','NOLPT',VERSION_NUM,'Turn printer port into bit bucket',,,,,Y

;-----------------------------------------------------------------------
; Now the meat of the resident portion, the printer interrupt handler.
; We can save one byte by specifying the hardware reset handler set up by
; the ALTMPX macro above
;
	ISP_HEADER 17h,hw_reset_2Dh
printer_port equ byte ptr ($+2)
	cmp	dx,0			; will be patched to printer port
	jne	use_old_int17
        cmp     ah,0
        je      int17_func00
	cmp	ah,2
	je	int17_func02
use_old_int17:
	jmp	ORIG_INT17h

int17_func00:
	; don't output character, simply return 'ready'
	; (fall through to func02)
int17_func02:
	mov	ah,90h			; yes, printer is ready
	iret

TSRcodeEnd@

;-----------------------------------------------------------------------

_TEXT SEGMENT 'CODE'
	ASSUME cs:_TEXT,ds:NOTHING,es:NOTHING,ss:NOTHING

banner	db 'NOLPT v',VERSION_STR,'  Public Domain 1992 Ralf Brown',13,10,'$'
usage	db 'Usage:',9,'NOLPT 1',9,9,'disable LPT1',13,10
	db 9,'...',13,10
	db 9,'NOLPT 4',9,9,'disable LPT4',13,10
	db 9,'NOLPT 1U',9,'uninstall from LPT1',13,10
	db 9,'etc.',13,10
	db '$'
installed_msg	 db "Installed on LPT"
lpt_number	 db " "
		 db ".",13,10,"$"
cant_install_msg db "Unable to install.",13,10,"$"
already_inst_msg db "Already installed.",13,10,"$"
cant_remove_msg  db "Can't remove from memory.",13,10,"$"
removed_msg	 db "Removed.",13,10,"$"


	@Startup2	Y
	push	ds
	pop	es
	ASSUME	ES:_INIT
	push	cs
	pop	ds
	ASSUME	DS:_TEXT
	;
	; say hello 
	;
	DISPLAY_STRING banner
	mov	bx,1000h		; set memory block to 64K
	mov	ah,4Ah
	int	21h
	mov	si,81h
cmdline_loop:
	lodsb_es
	cmp	al,' '			; skip blanks and tabs on commandline
	je	cmdline_loop
	cmp	al,9
	je	cmdline_loop
	mov	dx,offset _TEXT:usage
        cmp     al,'1'
	jb	exit_with_message
	cmp	al,'4'
	ja	exit_with_message
	push	es			; save for later use
	mov	es,TGROUP@
	ASSUME	ES:TGROUP
        mov     byte ptr ALTMPX_SIGNATURE+14,al
	mov	byte ptr lpt_number,al
	sub	al,'1'
	mov	printer_port,al
	pop	es			; restore addressing to PSP
	ASSUME	ES:_INIT
        lodsb_es                        ; get next character
	and	al,0DFh			; force to uppercase
	cmp	al,'U'
	jne	installing
removing:
	UNINSTALL cant_uninstall
	DISPLAY_STRING removed_msg
        mov     ax,4C00h
	int	21h

cant_uninstall:
        mov     dx,offset _TEXT:cant_remove_msg
	jmp short exit_with_message
already_installed:
	mov	dx,offset _TEXT:already_inst_msg
exit_with_message:
	mov	ah,9
	int	21h
	mov	ax,4C01h
	int	21h

installing:
	;
	; place any necessary pre-initialization here
	;
	INSTALL_TSR ,BEST,,inst_notify,already_installed,cant_install

cant_install:
	mov	dx,offset _TEXT:cant_install_msg
	jmp	exit_with_message

inst_notify:
	DISPLAY_STRING installed_msg
	ret

_TEXT ENDS

     end INIT


