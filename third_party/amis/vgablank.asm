;-----------------------------------------------------------------------
; VGABLANK.ASM	Public Domain 1992, 1995 Ralf Brown
;		You may do with this software whatever you want, but
;		common courtesy dictates that you not remove my name
;		from it.
;
; Minimalist VGA screen blanker.
;
; Version 0.92
; LastEdit: 9/24/95
;-----------------------------------------------------------------------

	INCLUDE AMIS.MAC

	@Startup 2,00         		; need DOS 2.00                     
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
; Declare the additional segments we will use
;

BIOS_SEG SEGMENT AT 40h
	ORG 63h
video_base dw ?
BIOS_SEG ENDS

;-----------------------------------------------------------------------
; Useful definitions
;
VIDEO_DISABLE_BIT equ 20h
VGA_REG 	  equ 3C4h
TICKS_PER_MINUTE equ 0444h

;-----------------------------------------------------------------------
; Put the resident code into its own segment so that all the offsets are
; proper for the new location after copying it into a UMB or down into
; the PSP.
;
TSRcode@
start_TSRcode label byte

;-----------------------------------------------------------------------
; Declare the interrupt vectors hooked by the program, then set up the
; Alternate Multiplex Interrupt Spec handler
;
	HOOKED_INTS 09h,1Ch
	ALTMPX	'Ralf B','VGABLANK',VERSION_NUM

;-----------------------------------------------------------------------
; Now the meat of the resident portion, the keyboard and timer tick
; interrupt handlers.
; We can save two bytes by specifying the hardware reset handler set up by
; the ALTMPX macro above
;
time_count  dw 0			; patched to actual timeout tick count
video_state db 0

set_video_state:
	push	dx
	mov	dx,VGA_REG
	mov	al,1
	out	dx,al
	inc	dx
	in	al,dx
	dec	dx
	mov	video_state,ah
	and	al,not VIDEO_DISABLE_BIT
	or	ah,al
	mov	al,1
	out	dx,al
	inc	dx
	mov	al,ah
	out	dx,al
	pop	dx
	ret

ISP_HEADER 1Ch,hw_reset_2Dh
	sti				; allow interrupts
	dec	time_count		; count down, and each time we hit
	jnz	int1C_done		; zero, force the video off
	push	ax
	mov	ah,VIDEO_DISABLE_BIT
	call	set_video_state
	pop	ax
int1C_done:
	JMP	ORIG_INT1Ch

ISP_HEADER 09h,hw_reset_2Dh
	sti				; allow interrupts
        push    ax                      ; keystroke, so unblank display
	mov	ah,0
	cmp	ah,video_state		; don't unblank unless currently blanked
	je	int09_done		; because of sparkles on some displays
        call    set_video_state
int09_done:
	pop	ax
	mov	time_count,0FFFFh	; patched with actual timeout count
MAX_TIME equ word ptr ($-2)
	jmp	ORIG_INT09h

resident_code_size equ offset $

TSRcodeEnd@

;-----------------------------------------------------------------------

_TEXT SEGMENT 'CODE'
	ASSUME cs:_TEXT,ds:NOTHING,es:NOTHING,ss:NOTHING

banner	   db 'VGABLANK v',VERSION_STR,'  Public Domain 1992 Ralf Brown',13,10,'$'
usage_msg  db 'Usage:',9,'VGABLANK n',9,"(n=1-9) install to blank after 'n' minutes",13,10
	   db 9,'VGABLANK R',9,'remove from memory',13,10
	   db "$"
need_VGA_msg	 db "This program requires a VGA.",13,10,"$"
installed_msg    db "Installed.",13,10,"$"
already_inst_msg db "Different version already installed.",13,10,"$"
timeout_changed_msg db "Blanking time changed.",13,10,"$"
cant_remove_msg  db "Can't remove from memory.",13,10,"$"
uninstalled_msg  db "Removed.",13,10,"$"

timeout		dw ?


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
	cmp	al,'1'			; number of minutes specified?
	jb	not_digit
	cmp	al,'9'			; if digit, go install TSR
	jbe	installing
not_digit:
	and	al,0DFh			; force to uppercase
	cmp	al,'R'
	je	removing
usage:
	mov	dx,offset _TEXT:usage_msg
	jmp     exit_with_error

removing:
	UNINSTALL cant_uninstall
	;
	; force video back on in case we are called from a batch file while
	; the screen is blanked
	;
	mov	dx,VGA_REG
	mov	al,1
	out	dx,al
	inc	dx
	in	al,dx
	dec	dx
	and	al,not VIDEO_DISABLE_BIT
	mov	ah,al
	mov	al,1
	out	dx,al
	inc	dx
	mov	al,ah
	out	dx,al
	;
	; finally, announce that the resident part has been removed
	;
	push	cs
	pop	ds
	ASSUME	DS:_TEXT
	DISPLAY_STRING uninstalled_msg
successful_exit:
        mov     ax,4C00h
	int	21h

installing:
	sub	al,'0'
	cbw
	mov	bx,TICKS_PER_MINUTE
	mul	bx
	mov	timeout,ax		; and remember for later
	mov	ax,1A00h		; get display combination code
	int	10h
	cmp	al,1Ah			; supported? (i.e. VGA present?)
	mov	dx,offset _TEXT:need_VGA_msg
	jne	exit_with_error
	;
	; place any necessary pre-initialization here
	;
	INSTALL_TSR ,BEST,TOPMEM,inst_patch,already_installed

cant_uninstall:
	mov	dx,offset _TEXT:cant_remove_msg
exit_with_error:
	mov	ah,9
	int	21h
	mov	ax,4C01h
	int	21h

already_installed:
	cmp	cx,VERSION_NUM		; same version installed?
	jne	wrong_version
	mov	al,0			; request signature string
	int	2Dh
	mov	es,dx			; ES -> resident code
	ASSUME	ES:RESIDENT_CODE
	mov	ax,timeout
	mov	time_count,ax
	mov	MAX_TIME,ax
	DISPLAY_STRING timeout_changed_msg
	jmp	successful_exit

wrong_version:
	ASSUME	ES:NOTHING
	mov	dx,offset _TEXT:already_inst_msg
	jmp 	exit_with_error

inst_patch:
	push	es
	mov	es,ax
	ASSUME	ES:RESIDENT_CODE
	mov	ax,timeout
	mov	time_count,ax
	mov	MAX_TIME,ax
	pop	es
	ASSUME	ES:NOTHING
	DISPLAY_STRING installed_msg
	ret

_TEXT ENDS

     end INIT

