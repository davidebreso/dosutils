;**************************************************************************
;*									  *
;*   RBkeyswap	 v3.01	    9/24/95					  *
;*   (c) Copyright 1989, 1991, 1992, 1995 Ralf Brown			  *
;*									  *
;*   Permission is granted to redistribute unmodified copies in their	  *
;*   entirety.	Modified copies may be distributed provided that they	  *
;*   are clearly marked as modified and the original unmodified source	  *
;*   code is distributed together with the modification.		  *
;*									  *
;*   ------------------------------------------------------------------   *
;*									  *
;*   RBkeyswap is a program to fix the IBM's enhanced keyboard, which     *
;*   places the Escape, Control, and CapsLock keys in the wrong places.   *
;*   After running RBkeyswap, Escape and `/~ will be exchanged, as will   *
;*   the left control key and the CapsLock key.  The right control key	  *
;*   will be unaffected.						  *
;*									  *
;*   RBkeyswap loads itself high (no need for LOADHI or LH) into either   *
;*   an XMS upper memory block or a DOS 5.0 UMB.  If neither is avail-	  *
;*   able, RBkeyswap will go resident in low memory, using just 224	  *
;*   bytes (it needs a mere 160 bytes in high memory).  Note that it will *
;*   use 272 bytes under DOS 2.x, because those versions force all TSRs   *
;*   to leave at least that much resident.				  *
;*									  *
;*   You need a BIOS which provides the keyboard intercept on INT 15h.	  *
;*   If your BIOS does not support this, RBkeyswap will merely use up	  *
;*   memory without doing anything.					  *
;*									  *
;*   Usage:   RBKEYSWP I	install					  *
;*	      RBKEYSWP R	remove from memory			  *
;*									  *
;*   ------------------------------------------------------------------   *
;*									  *
;*   Rebuilding RBkeyswap:						  *
;*	  TASM RBKEYSWP 						  *
;*	  TLINK /T RBKEYSWP AMIS					  *
;*									  *
;**************************************************************************

	INCLUDE AMIS.MAC

	@Startup 2,00           	; need DOS 2.00
					; this macro also takes care of declaring
					; all the segments in the required order

;-----------------------------------------------------------------------
;
VERSION_NUM equ 0301h	; v3.01
VERSION_STR equ "3.01"

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
	HOOKED_INTS 15h
	ALTMPX	'Ralf B','RBkeyswp',VERSION_NUM

;-----------------------------------------------------------------------
; Now the meat of the resident portion, the keyboard intercept handler.
; We can save one byte by specifying the hardware reset handler set up by
; the ALTMPX macro above
;
ISP_HEADER 15h,hw_reset_2Dh
       cmp	ah,4Fh			; scan code translation?
       jne	not_ours		; if not, chain immediately
       cmp	al,0E1h 		; is it a special key such as "Pause"?
       je	int15_setbranch
       cmp	al,0E0h 		; or a right-{alt,ctrl}?
branch: 				; (if prev scan was E0h or E1h, we will
					;   branch unconditionally)
       je	int15_setbranch 	; the opcode here gets toggled between
					;   JE and JMP SHORT as needed
       shl	al,1			; move break bit into CF
       pushf				;   and remember it for later
       cmp	al,1Dh*2		; ctrl?
       je	ctrl_or_capslock
       cmp	al,3Ah*2		; capslock?
       je	ctrl_or_capslock
       cmp	al,01h*2		; ESC?
       je	esc_or_tilde
       cmp	al,29h*2		; backquote/tilde key?
       jne	int15_no_xlat
esc_or_tilde:
       xor	al,0Fh*2		; (AL xor 0F) xor 27 == (AL xor 28h)
					; 01h -> 29h, 29h -> 01h
					; thus esc and tilde swapped
ctrl_or_capslock:
       xor	al,27h*2		; 1Dh -> 3Ah, 3Ah -> 1Dh
					; thus left-ctrl and capslock swapped
int15_no_xlat:
       popf				; retrieve break bit in CF
       rcr	al,1			;   and add to translated scan code
       jmp short int15_done

int15_setbranch:
       xor	byte ptr cs:branch,(74h xor 0EBh) ; toggle between JE and JMP
int15_done:
       stc				; use the scan code
not_ours:
       jmp	ORIG_INT15h

TSRcodeEnd@

;-----------------------------------------------------------------------

_TEXT SEGMENT 'CODE'
	ASSUME cs:_TEXT,ds:NOTHING,es:NOTHING,ss:NOTHING

banner	db 'RBkeyswap v',VERSION_STR,'  (c) Copyright 1989,1991,1992 Ralf Brown',13,10
	db "$"
usage	db 9,'Swaps Esc/tilde and CapsLock/LeftCtrl',13,10
	db 'Usage:',9,'RBKEYSWP I',9,'install in memory',13,10
	db 9,'RBKEYSWP R',9,'remove from memory',13,10
	db '$'
installed_msg	 db "Installed.",13,10,"$"
already_inst_msg db "Already installed.",13,10,"$"
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
        cmp     al,'I'
        je      installing
	cmp	al,'R'
	je	removing
	jmp	show_usage
installing:
	;
	; place any necessary pre-initialization here
	;
	INSTALL_TSR ,BEST,TOPMEM,inst_notify,already_installed

removing:
	UNINSTALL cant_uninstall
	push	cs
	pop	ds
	DISPLAY_STRING uninstalled_msg
        mov     ax,4C00h
	int	21h

show_usage:
	mov	dx,offset _TEXT:usage
	jmp short exit_with_error
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

