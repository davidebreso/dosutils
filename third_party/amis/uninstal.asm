;-----------------------------------------------------------------------
; Alternate Multiplex Interrup Specification Library
; AMIS.ASM	Public Domain 1992,1995 Ralf Brown
;		You may do with this software whatever you want, but
;		common courtesy dictates that you not remove my name
;		from it.
;
; Version 0.92
; LastEdit: 9/24/95
;-----------------------------------------------------------------------

	INCLUDE AMIS.MAC

;-----------------------------------------------------------------------

_TEXT SEGMENT PUBLIC BYTE 'CODE'
	ASSUME	CS:_TEXT

;-----------------------------------------------------------------------

resident_seg	dw 0	; location of TSR code after relocation
alloc_strat	dw 0
link_state	db 0	; are UMBs part of memory chain?

;-----------------------------------------------------------------------
; Call the XMS driver
;
; entry: all registers as needed for XMS call
; exit:	 registers as returned by XMS driver
;	 ZF set if successful, ZF clear if failure
;
XMS proc near
	db	09Ah	; FAR CALL
xms_entry dd	0	; XMS driver's entry point
	cmp	ax,1
	ret
XMS endp

;-----------------------------------------------------------------------
; Determine entry point of XMS driver and initialize procedure XMS to call
; that entry point
;
; exit: CF set if no XMS driver or other failure
;	CF clear if initialization successful
;
get_XMS_entry proc near
	push	es
	mov	ax,352Fh
	int	21h			; find out whether INT 2F is valid
	mov	ax,es
	or	ax,bx			; don't try XMS if INT 2F is NULL
	jz	no_XMS_driver		; (could be case under DOS 2.x)
	mov	ax,4300h		; see if XMS is installed
	int	2Fh
	cmp	al,80h			; did XMS respond?
	jnz	no_XMS_driver
	mov	ax,4310h		; if XMS present, get its entry point
	int	2Fh
	mov	word ptr xms_entry,bx
	mov	word ptr xms_entry+2,es ; and store entry point for call
	pop	es
	clc
	ret
no_XMS_driver:
	pop	es
	stc
	ret
get_XMS_entry endp

;-----------------------------------------------------------------------
; entry: nothing
; exit:	 CF set if not available, clear if available
;	 AX,BX,CX,DX destroyed
;	 if available, DOS5 UMBs have been linked into the memory chain
;
check_if_DOS5_UMBs proc near
	mov	ax,5800h
	int	21h			; get current allocation strategy
	mov	alloc_strat,ax		;   and remember it for later restore
	mov	ax,5802h		; get current state of UMB linkage
	int	21h
	mov	link_state,al
	mov	ax,3000h		; get DOS version
	int	21h
	cmp	al,5			; DOS 5.0 or higher?
	jb	no_DOS5_UMBs
	cmp	al,10			; but make sure not OS/2 penalty box
	jae	no_DOS5_UMBs
	mov	ax,2B01h
	mov	cx,4445h
	mov	dx,5351h
	int	21h			; check if DESQview running
	cmp	al,0FFh			; if yes, no UMB's to be allocated
	jne	no_DOS5_UMBs
	mov	ax,5803h
	mov	bx,1			; try to link in UMBs
	int	21h
	mov	ax,5802h		; get new link state
	int	21h
	cmp	al,1
	jne	no_DOS5_UMBs
	clc				; yes, we have UMBs
	ret

no_DOS5_UMBs:
	stc
	ret
check_if_DOS5_UMBs endp

;-----------------------------------------------------------------------
; entry: DS:SI -> hooked interrupt list
; exit:	 AX, BX, CX, DX destroyed
;	 CF set if unable to unhook all vectors
;	 CF clear if successful
;
public unhook_interrupts
unhook_interrupts proc DIST
	push	es
	push	ds
	push	di
	push	si
	cld
chk_unhook_loop:
	lodsb
	mov	dx,[si]			; get offset of interrupt handler
	inc	si			;   and skip that field in the hook
	inc	si			;   list
	cmp	al,2Dh
	je	all_unhookable
	mov	ah,35h
	int	21h			; get interrupt vector
	mov	ax,es
	mov	cx,ds
	cmp	ax,cx			; check segment agains of vectors
	jne	chk_isp_loop
	cmp	dx,bx			; check offset of vector against ours
	je	chk_unhook_loop		; this int is unhookable if same
chk_isp_loop:
	cmp	word ptr es:[bx],10EBh	; handler starts with JMP SHORT $+12 ?
	jne	not_unhookable
	cmp	word ptr es:[bx+6],424Bh ; valid signature?
	jne	not_unhookable
	cmp	byte ptr es:[bx+9],0EBh ; hardware reset must also be JMP SHORT
	jne	not_unhookable
	cmp	cx,word ptr es:[bx+4]	; check segment of next ptr against ours
	jne	chk_next_isp
	cmp	dx,word ptr es:[bx+2]	; check offset of next ptr against ours
	je	chk_unhook_loop		; this int is unhookable if same
chk_next_isp:
	les	bx,es:[bx+2]		; advance to next ISP header
	jmp	chk_isp_loop		;   and test it

not_unhookable:
	stc
unhook_ints_done:
	pop	si
	pop	di
	pop	ds
	pop	es
	ret

all_unhookable:
	pop	si			; get back start of hook list
	push	si			; and preserve SI for return
unhook_loop:
	lodsb
	mov	dx,[si]
	inc	si
	inc	si
	push	ds
	push	ax
	mov	ah,35h
	int	21h			; get interrupt vector
	mov	ax,es
	mov	cx,ds
	cmp	ax,cx			; check segments of vectors
	jne	isp_loop
	cmp	dx,bx			; check offsets of vectors
	jne	isp_loop
	lds	dx,[bx+2]		; get our old_int?? pointer
	pop	ax
	push	ax
	mov	ah,25h			; set interrupt vector
	int	21h
	jmp short unhooked_interrupt
isp_next:
	les	bx,es:[bx+2]		; advance to next ISP header
isp_loop:
;
; no need to check for a valid ISP header, as we already know all chains reach
; our header before non-ISP code
;
	cmp	cx,es:[bx+4]		; check segment of 'previous' ptr
	jne	isp_next
	cmp	dx,es:[bx+2]		; check offset of 'previous' ptr
	jne	isp_next
	xchg	bx,dx
	lds	bx,[bx+2]
	xchg	bx,dx			; ES:BX -> previous ISP
					; DS:DX -> next ISP
	mov	es:[bx+2],dx		; prev->next = curr->next
	mov	es:[bx+4],ds		;    thus, we are now unhooked
unhooked_interrupt:
	pop	ax
	pop	ds
	cmp	al,2Dh
	jne	unhook_loop
	clc				; indicate success
	jmp	unhook_ints_done
unhook_interrupts endp

;-----------------------------------------------------------------------
; entry: AX = segment of TSR code within the calling executable
; exit:	 CF clear if successful
;	 CF set on error
;
public _AMIS_uninstall
_AMIS_uninstall proc DIST
	push	bp
	mov	bp,sp
ifidni <DIST>,<FAR>
 @mpx_number = byte ptr [bp+6]
ELSE
 @mpx_number = byte ptr [bp+4]
ENDIF
	;
	; first, see whether the TSR can uninstall itself
	;
	mov	ah,@mpx_number
	mov	al,2
	mov	dx,cs			; load return address for success
	mov	bx,offset _TEXT:uninstall_successful
	int	2Dh
	cmp	al,0FFh			; successful?
	je	uninstall_successful
	cmp	al,02h  		; unsupp, unsucc, or unable to remove?
	jbe     uninstall_done
	cmp	al,05h			; unknown return code?
	jae	uninstall_failed
	;
	; TSR said it is safe to uninstall, but not able to do so itself,
	; so now we unhook its interrupts and free its memory
	;
	mov	resident_seg,bx		; remember which memory block to free
	mov	ah,@mpx_number
	mov	al,4
	mov	bl,0			; start with INT 00h
	int	2Dh
	cmp	al,1			; function unsupported or can't determine?
	jbe	uninstall_failed
	cmp	al,4
	jne	uninstall_failed	; sorry, can't handle returns 02h/03h yet
go_uninstall:
	push	ds
	push	si
	mov	ds,dx			; DS:SI -> hook list
	mov	si,bx
	call	unhook_interrupts
	pop	si
	pop	ds
	jc	uninstall_failed
	cmp	resident_seg,0B000h	; regular DOS memblk if below video
	jae	uninstall_highmem
	mov	es,resident_seg
	mov	ah,49h			; free memory block
	int	21h
uninstall_successful:
	mov	al,0FFh			; indicate success
	jmp short uninstall_done
uninstall_failed:
	mov	al,1			; status = unsuccessful
uninstall_done:
	mov	ah,0			; return AX=uninstall status code
	pop	bp
	ret

uninstall_highmem:
	call	check_if_DOS5_UMBs	; check if UMBs, and link them in
	jc	uninstall_XMS
	mov	es,resident_seg		; free the memory block
	mov	ah,49h
	int	21h
restore_link_state:
	mov	ax,5801h
	mov	bx,alloc_strat		; restore allocation strategy
	int	21h
	mov	ax,5803h		; and restore UMB link status
	mov	bh,0
	mov	bl,link_state
	int	21h
	jmp	uninstall_successful

uninstall_XMS:
	call	get_XMS_entry
	jc	uninstall_failed	; no XMS driver!?!?!
	mov	ah,11h			; release UMB
	mov	dx,resident_seg
	call	XMS
	jne	uninstall_failed	; we deallocation successful?
	jmp	uninstall_successful
_AMIS_uninstall endp

;-----------------------------------------------------------------------

_TEXT ENDS
	END

