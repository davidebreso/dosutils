;-----------------------------------------------------------------------
; SWITCHAR.ASM	Public Domain 1992,1995 Ralf Brown
;		You may do with this software whatever you want, but
;		common courtesy dictates that you not remove my name
;		from it.
;
; Provide the undocumented switch-character services which were removed
; from MSDOS 5.0.  The TSR is larger than necessary because it is
; illustrating the use of both private INT 2Dh functions and a private
; API entry point.
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
; Put the resident code into its own segment so that all the offsets are
; proper for the new location after copying it into a UMB or down into
; the PSP.
;
TSRcode@

;-----------------------------------------------------------------------
; Declare data storage for the TSR
;

switchar_active  db 1
current_switchar db '/'

;-----------------------------------------------------------------------
; Define the private API entry point handler
;
switchar_API proc far
	cmp	al,1
	ja	switchar_API_done
	xchg	byte ptr RESIDENT_CODE:switchar_active,al
switchar_API_done:
	ret
switchar_API endp

;-----------------------------------------------------------------------
; Define our private INT 2Dh function
;
private:
	cmp     al,10h			; INT 2D/AH=mpx/AL=10h is set-state
	jne	not_private_func
	mov	al,bl			; BL=new state
	push	cs
	call	near ptr switchar_API
	mov	ah,al			; return previous state
	mov	al,0FFh			; indicate success
	iret

not_private_func:
	mov	al,0			; indicate not supported
	iret

;-----------------------------------------------------------------------
; Define our removal code
;	deactivate, then report that we don't have a resident uninstaller
;	but are now disabled
;
remov:
	mov	RESIDENT_CODE:switchar_active,0
	mov	bx,0			; seg of block to free (will be patched)
ALTMPX$PSP equ word ptr ($-2)		; magic name of word to be patched with
					; actual memory block segment by TSR
					; installation code
	mov	al,4			; no resident remover, now disabled
	ret

;-----------------------------------------------------------------------
; Declare the interrupt vectors hooked by the program, then set up the
; Alternate Multiplex Interrupt Spec handler
; Note: the resident remover must precede the ALTMPX if it defines ALTMPX$PSP
;	otherwise ALTMPX$PSP will be multiply-defined
;
	HOOKED_INTS 21h			; hooking INT 21h in add. to INT 2Dh
	ALTMPX	'Ralf B','SWITCHAR',VERSION_NUM,'Switch-character support',private,switchar_API,,remov,Y

;-----------------------------------------------------------------------
; Now the meat of the resident portion, the MSDOS interrupt handler.
; We can save one byte by specifying the hardware reset handler set up by
; the ALTMPX macro above
;
	ISP_HEADER 21h,hw_reset_2Dh
	cmp	ah,37h			; switchar/availdev call?
	jne	use_old_int21
	cmp	switchar_active,0	; is TSR enabled?
	je	use_old_int21		; if not, pass through
	cmp	al,1			; check if switchar call
	ja	use_old_int21		; if not, pass through
	mov	al,0			; always return 'success'
	jb	get_switchar
set_switchar:
	mov	current_switchar,dl
	iret

get_switchar:
	mov	dl,current_switchar
	iret

use_old_int21:
	jmp	ORIG_INT21h

TSRcodeEnd@

;-----------------------------------------------------------------------

_TEXT SEGMENT 'CODE'
	ASSUME cs:_TEXT,ds:NOTHING,es:NOTHING,ss:NOTHING

banner	db 'SWITCHAR v',VERSION_STR,'  Public Domain 1992 Ralf Brown',13,10,'$'
usage	db 'Usage:',9,'SWITCHAR i',9,'install',13,10
	db 9,'SWITCHAR r',9,'remove from memory',13,10
	db 9,'SWITCHAR d',9,"disable TSR but don't unload",13,10
	db 9,'SWITCHAR e',9,'enable TSR',13,10
	db 9,'SWITCHAR <x>',9,'set switch character to <x>',13,10
	db '$'
not_installed_msg db "Not " ;continues on next line
installed_msg	 db "Installed.",13,10,"$"
cant_install_msg db "Unable to install.",13,10,"$"
already_inst_msg db "Already installed.",13,10,"$"
cant_remove_msg  db "Can't remove from memory.",13,10,"$"
removed_msg	 db "Removed.",13,10,"$"
switchar_set_msg db "Switch character has been set.",13,10,"$"
not_set_msg 	 db "Switch character has NOT been set.",13,10,"$"
not_supported_msg db "Switch character not supported.",13,10,"$"
enabled_msg	 db "SWITCHAR enabled $"
disabled_msg	 db "SWITCHAR disabled $"
was_on_msg	 db "(was enabled).",13,10,"$"
was_off_msg	 db "(was disabled).",13,10,"$"
cant_disable_msg db "Can't disable SWITCHAR.",13,10,"$"

entry_point dd ?

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
	mov	ah,4Ah			; to have some memory to allocate
	int	21h
	mov	si,81h			; SI -> commandline
	cld
cmdline_loop:
	lodsb_es
	cmp	al,' '			; skip blanks and tabs on commandline
	je	cmdline_loop
	cmp	al,9
	je	cmdline_loop
	mov	ah,al			; remember exact switch character
	and	al,0DFh			; force to uppercase
	cmp	al,'R'
	je	removing
	cmp	al,'I'
	je	installing
	cmp	al,'E'
	je	enabling
	cmp	al,'D'
	je	disabling
        cmp     ah,' '
	jbe	show_usage
	jmp	set_switch_char

show_usage:
	mov	dx,offset _TEXT:usage
	jmp	exit_with_error

removing:
	UNINSTALL cant_uninstall
	mov	dx,offset _TEXT:removed_msg
exit_with_message:
	mov	ah,9
	int	21h
        mov     ax,4C00h
	int	21h

enabling:
	IF_INSTALLED enable_TSR
not_installed:
	mov	dx,offset _TEXT:not_installed
	jmp	exit_with_error

disabling:
	IF_INSTALLED disable_TSR
	jmp	not_installed

installing:
	INSTALL_TSR ,BEST,,inst_notify,already_installed,cant_install

cant_uninstall:
        mov     dx,offset _TEXT:cant_remove_msg
	jmp short exit_with_error
already_installed:
	mov	dx,offset _TEXT:already_inst_msg
exit_with_error:
	mov	ah,9
	int	21h
	mov	ax,4C01h
	int	21h

set_switch_char:
	mov	dl,ah
	push	dx
	mov	ax,3701h
	int	21h
	pop	cx			; get back requested switch character
	mov	dx,offset _TEXT:not_supported_msg
	cmp	al,0			; supported?
	jne	set_switch_done		; branch if not
	mov	ax,3700h
	int	21h			; get current switch character
	cmp	dl,cl			; now same as request switch char?
	mov	dx,offset _TEXT:switchar_set_msg
	je	set_switch_done
	mov	dx,offset _TEXT:not_set_msg
set_switch_done:
	jmp	exit_with_message

cant_install:
	mov	dx,offset _TEXT:cant_install_msg
	jmp	exit_with_error

inst_notify:
	DISPLAY_STRING _TEXT:installed_msg
	ret

;-----------------------------------------------------------------------
; on entry, AH=multiplex number
;
; for this example program, the 'enable' call will be made via a private
; INT 2Dh function, while the 'disable' call will be made via the FAR
; CALL entry point.
;

enable_TSR proc
	mov	al,10h			; private func, "set state"
	mov	bl,1			; new state = enabled
	int	2Dh			; set state, returns AH=old state
	mov	al,ah
	mov	dx,offset _TEXT:enabled_msg
display_state_and_exit:
	push	ax			; remember prior state
	mov	ah,9			; display string
	int	21h
	pop	ax			; get back prior state
	mov	dx,offset _TEXT:was_on_msg
	cmp	al,0
	jne	display_state
	mov	dx,offset _TEXT:was_off_msg
display_state:
	jmp	exit_with_message
enable_TSR endp

;-----------------------------------------------------------------------
; on entry, AH=multiplex number
;
; for this example program, the 'enable' call will be made via a private
; INT 2Dh function, while the 'disable' call will be made via the FAR
; CALL entry point.
;

disable_TSR proc
	mov	al,1			; function "get API entry"
	int	2Dh	
	cmp	al,0FFh			; supported?
	jne	disable_not_supported
	mov	word ptr _TEXT:entry_point+2,dx
	mov	word ptr _TEXT:entry_point,bx
	mov	al,0			; function is disable
	call	dword ptr _TEXT:entry_point
	mov	dx,offset _TEXT:disabled_msg
	jmp	display_state_and_exit
disable_not_supported:
	mov	dx,offset _TEXT:cant_disable_msg
	jmp	exit_with_error
disable_TSR endp

;-----------------------------------------------------------------------

_TEXT ENDS

     end INIT


