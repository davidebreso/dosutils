;-----------------------------------------------------------------------
; FASTMOUS.ASM	Public Domain 1992, 1993, 1995 Ralf Brown
;		You may do with this software whatever you want, but
;		common courtesy dictates that you not remove my name
;		from it.
;
; Convert slow (on some systems) hardware reset mouse call into a fast
; software reset call.	This is a demonstration program to show just
; how small a useful program can be made and still be fully compliant
; with the alternate multiplex interrupt specification v3.4.  FASTMOUS
; contains just 128 bytes of resident code and data.
;
; Version 0.92
; LastEdit: 9/24/95
;-----------------------------------------------------------------------

	INCLUDE AMIS.MAC

	@Startup 2,00			; need DOS 2.00
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
	HOOKED_INTS 2Dh,33h		; it isn't actually necessary to list 2Dh
	ALTMPX	'Ralf B','FASTMOUS',VERSION_NUM

;-----------------------------------------------------------------------
; Now the meat of the resident portion, the mouse interrupt handler.
; We can save one byte by specifying the hardware reset handler set up by
; the ALTMPX macro above
;
	ISP_HEADER 33h,hw_reset_2Dh
	or	ax,ax			; hardware reset call?
	jne	use_old_int33		; skip if not
	push	ds
	mov	ds,ax         		; DS <- 0000h
	test	byte ptr ds:[417h],13h	; shift or scroll lock pressed?
	pop	ds
	jnz	use_old_int33		; skip if yes
	mov	al,21h			; do software reset instead
use_old_int33:
	jmp	ORIG_INT33h

TSRcodeEnd@

;-----------------------------------------------------------------------

_TEXT SEGMENT 'CODE'
	ASSUME cs:_TEXT,ds:_INIT,es:TGROUP,ss:NOTHING

banner 	db 'FASTMOUS v',VERSION_STR,'  Public Domain 1993 Ralf Brown  '
	db '[Type "FASTMOUS R" to remove]',13,10,"$"
installed_msg	 db "Installed.",13,10,"$"
already_inst_msg db "Already installed.",13,10,"$"
no_driver_msg	 db "No mouse driver -- can't install.",13,10,"$"
cant_remove_msg  db "Can't remove from memory.",13,10,"$"
uninstalled_msg  db "Removed.",13,10,"$"


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
	mov	si,81h			; SI -> command line
	cld				; ensure proper direction for string ops
cmdline_loop:
	lodsb_es
	cmp	al,' '			; skip blanks and tabs on commandline
	je	cmdline_loop
	cmp	al,9
	je	cmdline_loop
	and	al,0DFh			; force to uppercase
	cmp	al,'R'
	je	removing
installing:
	;
	; place any necessary pre-initialization here
	;
	mov	ax,3533h
	int	21h
	mov	ax,es
	or	ax,bx			; is INT 33h hooked already?
	mov	dx,offset _TEXT:no_driver_msg
	jz	exit_with_error		; if not hooked, we can't install
	;
	; OK, now ready to install
	;
	INSTALL_TSR ,BEST,TOPMEM,inst_notify,already_installed

removing:
	UNINSTALL cant_uninstall
	push	cs
	pop	ds
	ASSUME	DS:_TEXT
	DISPLAY_STRING uninstalled_msg
        mov     ax,4C00h
	int	21h

cant_uninstall:
	mov	dx,offset _TEXT:cant_remove_msg
	jmp short exit_with_error
already_installed:
	mov	dx,offset _TEXT:already_inst_msg
exit_with_error:
	mov	ah,9
	int	21h
	mov	ax,4C01h
	int	21h

inst_notify:
	DISPLAY_STRING installed_msg
	ret

_TEXT ENDS

     end INIT

