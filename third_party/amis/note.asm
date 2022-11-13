;-----------------------------------------------------------------------
; NOTE.ASM	Public Domain 1992 Ralf Brown
;		You may do with this software whatever you want, but
;		common courtesy dictates that you not remove my name
;		from it.
;
; Popup to append one or more lines to a text file.  Demonstration of the
; use of DOS from within an AMIS-compliant TSR.
; Note: popup may be done from the commandline or via a hotkey; however,
; 	the hotkey support requires a newer BIOS which has the INT 15/4F
;	keyboard intercept
;
; Version 0.92
; LastEdit: 2/21/93
;-----------------------------------------------------------------------

__DEFAULT_MODEL__ equ __TINY__
	INCLUDE AMIS.MAC
	INCLUDE AMIPOPUP.MAC

	@Startup 3,00			; need DOS 3.00
					; this macro also takes care of declaring
					; all the segments in the required order

;-----------------------------------------------------------------------
;
VERSION_NUM equ 005Ch	; v0.92
VERSION_STR equ "0.92"

; comment out the following line to use the generic hotkey dispatcher, at a
; cost of an additional 80 bytes
;CUSTOM_HOTKEY_CODE equ 1

WINDOW_TOP    equ 0		; topmost row of TSR's popup window
WINDOW_LEFT   equ 5		; leftmost column of TSR's popup window
WINDOW_HEIGHT equ 3   		; height (including frame) of popup window
WINDOW_WIDTH  equ 70  		; width (including frame) of popup window
HOTKEY_SCAN   equ SCAN_N	; scan code for 'N' key
HOTKEY_NAME   equ "N"

screen_buffer_size equ (WINDOW_HEIGHT*WINDOW_WIDTH*2)
screen_buffer_para equ (screen_buffer_size+15)/16

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
; Since we need a PSP, but might be loaded into a UMB or at the top of
; conventional memory, we make a copy of the all-important first 64 bytes
; of the PSP here.  After relocation, this copy will start at offset 0
;
TSR_PSP	db 64 dup (?)

;-----------------------------------------------------------------------
; TSR's initialized data storage
;
TSRdata@
extrn $AMIS$DISK_BUSY:byte,$AMIS$WANT_POPUP:byte,$AMIS$WANT_SHUTDOWN:byte
extrn $AMIS$WANT_POPUP:byte,$AMIS$WANT_SHUTDOWN:byte,$AMIS$POPUP_INT28:byte

;;; add TSR-specific initialized data below

TSR_NAME	db "NOTE",0		; title for popup window

CRLF_buffer	db 13,10

TSRdataEnd@

;-----------------------------------------------------------------------
; TSR's uninitialized data storage
;
TSRbss@

;;; add TSR-specific uninitialized data below

notefile_handle dw ?

edit_buffer	db WINDOW_WIDTH-2 dup (?)
TSRbssEnd@


;-----------------------------------------------------------------------

public TSR_MAIN
TSR_MAIN proc near
	ASSUME	DS:TGROUP,ES:NOTHING
	xor	si,si			; SI stores line length
TSR_main_loop:
	MOVE_CURSOR ,,si
	GETKEY
	cmp	al,0Dh			; Enter pressed?
	je	TSR_main_line_end
	cmp	al,27			; Esc pressed?
	je	TSR_main_done
	cmp	al,8
	je	backspace
	cmp	al,0			; extended ASCII?
	je	TSR_main_loop		; if yes, ignore
	cmp	al,0E0h
	jne	got_char
	cmp	ah,0
	jne	TSR_main_loop
got_char:
	cmp	si,WINDOW_WIDTH-2
	jb	store_char
beep:
	mov	ax,0E07h		; beep
	int	10h
	jmp	TSR_main_loop
store_char:
	mov	edit_buffer[si],al
	inc	si			; remember that we got another char
	PUT_CHAR
	jmp	TSR_main_loop

backspace:
	or	si,si
	jz	beep
	dec	si
	MOVE_CURSOR ,,si
	PUT_CHAR ' '
	jmp	TSR_main_loop

TSR_main_line_end:
	mov	ah,40h
	mov	bx,notefile_handle
	mov	cx,si
	mov	dx,offset TGROUP:edit_buffer
	int	21h
	mov	ah,40h
	mov	cx,2
	mov	dx,offset TGROUP:CRLF_buffer
	int	21h
	CLEAR_WINDOW
	jmp	TSR_main		; restart for next line

TSR_main_done:
	mov	bx,notefile_handle
	mov	ah,45h			; DUP handle
	int	21h
	jc	TSR_main_exit		; quit now if unable to duplicate
	mov	bx,ax
	mov	ah,3Eh			; close duplicate
	int	21h
TSR_main_exit:
	ret
TSR_MAIN endp

;-----------------------------------------------------------------------
; Function that performs any necessary cleanup prior to the TSR being
; removed from memory.  At the time it is called, the TSR is effectively
; popped up, though it has not modified the screen.  If this routine needs
; to write on the screen, it must save and restore the screen contents
; itself
;
public TSR_SHUTDOWN
TSR_SHUTDOWN proc near
	mov	bx,notefile_handle
	mov	ah,3Eh			; close the file
	int	21h
	ret
TSR_SHUTDOWN endp

;-----------------------------------------------------------------------
; For this simple case, we simply fail all INT 21h calls which encounter
; a critical error
;
public TSR_INT24_HANDLER
TSR_INT24_HANDLER:
	mov	al,03h			; FAIL, for now
;	iret  ; save a byte by falling through to next handler

;-----------------------------------------------------------------------
; Simply ignore Ctrl-Break and Ctrl-C interrupts
;
public TSR_INT1B_HANDLER,TSR_INT23_HANDLER
TSR_INT1B_HANDLER:
TSR_INT23_HANDLER:
	iret

;=======================================================================
; It should not be necessary to make any changes between here and the
; end of the resident portion (other than the TSR identifier in the ALTMPX
; macro) in order to modify this code for a different purpose.
;=======================================================================

	DEFAULT_API_POPUP
	DEFAULT_API_REMOVE

;-----------------------------------------------------------------------
; Declare the interrupt vectors hooked by the program, then set up the
; Alternate Multiplex Interrupt Spec handler and the default interrupt
; handlers for the idle popups, disk lockout, and hotkey popup
;
	HOOKED_INTS 08h,13h,15h,28h

	HOTKEYS HK_INT15ENTRY
	HOTKEY	HOTKEY_SCAN,HK_BOTHSHIFT,<HK_ANYCTRL OR HK_ANYALT>
	HOTKEYS_DONE

	ALTMPX	'Ralf B','NOTE',VERSION_NUM,"Append notes to a file",,,API_popup,API_remove,Y,hotkey_list

	DEFAULT_INT08
	DEFAULT_INT13
	DEFAULT_INT15 HOTKEY_SCAN,HK_BOTHSHIFT
	DEFAULT_INT28

TSRcodeEnd@

;-----------------------------------------------------------------------

_TEXT SEGMENT PUBLIC 'CODE'
	ASSUME cs:_TEXT,ds:NOTHING,es:NOTHING,ss:NOTHING

extrn TSR_SET_WINDOW:DIST,$AMIS$GET_DOS_PTRS:DIST

banner 	         db 'NOTE v',VERSION_STR,'  Public Domain 1993 Ralf Brown',13,10,'$'
usage_msg	 db "Usage:",9,"NOTE -Ifile",9,"Install using <file> as notepad",13,10
		 db 9,"NOTE -R",9,9,"Remove from memory",13,10
		 db "$"
hotkey_msg	 db "Press Shift-Shift-",HOTKEY_NAME," to pop up",13,10,"$"
no_hotkey_msg	 db "Hotkey is not available on this machine",13,10,"$"
hotkey_used_msg	 db "Hotkey is already in use.",13,10,"$"
installed_msg	 db "Installed.",13,10,"$"
already_inst_msg db 13,10,"Already installed.",13,10,"$"
cant_remove_msg  db "Can't remove from memory.",13,10,"$"
uninstalled_msg  db "Removed.",13,10,"$"
cant_access_msg	 db "Unable to open or create notepad file",13,10,"$"

filename_len equ 80
filename_buf	db filename_len dup (?)



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
	cmp	al,'-'
	je	got_cmdline_switch
bad_cmdline:
	jmp	usage
got_cmdline_switch:
	lodsb_es			; get next character
	and	al,0DFh			; force to uppercase
	cmp	al,'R'
	jne	not_removing
	jmp	removing
not_removing:
	cmp	al,'I'
	jne	bad_cmdline
installing:
	;
	; place any necessary pre-initialization here
	;
	SET_WINDOW WINDOW_TOP,WINDOW_LEFT,WINDOW_HEIGHT,WINDOW_WIDTH,TGROUP:$AMIS$end_TSRcode,TGROUP:TSR_NAME
	mov	di,offset _TEXT:filename_buf
	mov	dx,di			; remember start of filename
	mov	cx,filename_len
	push	es
	pop	ds
	ASSUME	DS:_INIT
	push	cs
	pop	es
	ASSUME	ES:_TEXT
copy_filename_loop:
	lodsb
	cmp	al,' '
	jb	copy_filename_done
	stosb
	loop	copy_filename_loop
copy_filename_done:
	mov	al,0
	stosb
	push	cs
	pop	ds
	ASSUME	DS:_TEXT
	mov	ax,3DC1h		; open, no-inherit/DENYNONE/write-only
	int	21h
	jnc	open_successful
	mov	ax,3C00h		; if unable to open, try creating file
	xor	cx,cx			; no special attributes
	int	21h
	jnc	create_successful
	mov	dx,offset _TEXT:cant_access_msg
	jmp	exit_with_error
open_successful:
create_successful:
	push	cs
	pop	ds			; restore DS
	ASSUME	DS:_TEXT
	mov	bx,ax
	mov	ah,3Eh			; close the file again; we now know
	int	21h			;   we can access it
	;
	; find out whether keyboard intercept is available
	;
	stc
	mov	ah,0C0h
	int	15h			; get ROM BIOS configuration data
	ASSUME	ES:NOTHING
	mov	dx,offset _TEXT:no_hotkey_msg
	jc	no_kbd_intercept
	test	byte ptr es:[bx+5],10h	; have keyboard intercept?
	jz	no_kbd_intercept
	mov	dx,offset _TEXT:hotkey_msg
no_kbd_intercept:
	mov	ah,9
	int	21h
	call	$AMIS$GET_DOS_PTRS
	;
	; one last check: is there a hotkey conflict?
	;
	IF_HOTKEY_USED	hotkey_in_use
	;
	; now go install the TSR
	;
	push	cs
	pop	ds
	ASSUME	DS:_TEXT
;note: add TOPMEM following BEST to make TSR load at top of memory
	INSTALL_TSR screen_buffer_para,BEST,,inst_patch,already_installed

hotkey_in_use:
	push	cs
	pop	ds
	ASSUME	DS:_TEXT
	mov	dx,offset hotkey_used_msg
	jmp short exit_with_error

removing:
	ASSUME	DS:_TEXT
	UNINSTALL cant_uninstall
	push	cs
	pop	ds
	ASSUME	DS:_TEXT
	DISPLAY_STRING uninstalled_msg
        mov     ax,4C00h
	int	21h

already_installed:
	mov	dx,offset _TEXT:already_inst_msg
	jmp short exit_with_error

usage:
	ASSUME	DS:_TEXT
	mov	dx,offset _TEXT:usage_msg
	jmp short exit_with_error

cant_uninstall:
	mov	dx,offset _TEXT:cant_remove_msg
exit_with_error:
	push	cs
	pop	ds
	ASSUME	DS:_TEXT
	mov	ah,9
	int	21h
	mov	ax,4C01h
	int	21h

inst_patch:
	ASSUME	DS:NOTHING
	push	ds
        push    es
        mov     es,ax
	ASSUME	ES:TGROUP
	;
	; close all files which will not be used by the TSR
	;
	mov	bx,0			; for this TSR, don't need handles 0-4
close_file_loop:
	mov	ah,3Eh
	int	21h
	inc	bx
	cmp	bx,4
	jbe	close_file_loop
	;
	; now copy the PSP into the resident portion
	;
	mov	ds,__psp
	ASSUME	DS:_INIT
	xor	si,si
	xor	di,di
	mov	cx,size TSR_PSP
	cld
	rep	movsb
	mov	es:[36h],es		; adjust JFT pointer in copied PSP
	mov	bx,es
	mov	ah,50h			; set PSP segment so TSR owns file
	int	21h
	push	cs
	pop	ds
	ASSUME	DS:_TEXT
	mov	dx,offset _TEXT:filename_buf
        mov     ax,3DC1h                ; open, no-inherit/DENYNONE/write-only
	int	21h
	jnc	reopen_successful
	xor	ax,ax			; point at a closed handle
reopen_successful:
	mov	TGROUP:notefile_handle,ax
	mov	bx,ax
	xor	cx,cx
	xor	dx,dx
	mov	ax,4202h		; position to end of file
	int	21h
	mov	ah,50h			; restore PSP segment
	mov	bx,__psp
	mov	ds,bx
	ASSUME	DS:_INIT
	int	21h
	;
	; now, zero out the JFT in our PSP so that the exit won't close
	; the files that the TSR does need
	;
	mov	cx,ds:[0032h]		; size of JFT
	les	di,ds:[0034h]		; pointer to JFT
	mov	al,0FFh			; closed-file flag
	rep	stosb
	pop	es
	ASSUME	ES:NOTHING
	;
	; finally, announce that we are installed
	;
	push	cs
	pop	ds
	ASSUME	DS:_TEXT
	DISPLAY_STRING installed_msg
	pop	ds
	ASSUME	DS:NOTHING
	ret

_TEXT ENDS

     end INIT

