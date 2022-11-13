;--------------------------------------------------------------------------;
;  Program:    EatMem  .Asm                                                ;
;  Purpose:    TSR utility to limit available memory.                      ;
;  Notes:      Compiles under TURBO Assembler, v2.0.                       ;
;  Status:     Source released into the public domain. If you find this    ;
;                 program useful, please send a postcard.                  ;
;  Updates:    14-Apr-91, v1.0a, GAT                                       ;
;                 - initial version                                        ;
;              06-May-91, v1.0b, GAT                                       ;
;                 - added option for user to select multiplex ID.          ;
;              09-Nov-91, v1.1a, GAT                                       ;
;                 - revised include file names.                            ;
;                 - added pseudo-environment so program name will show up  ;
;                   with things like PMAP, MANIFEST, and MEM.              ;
;                 - uses INT 2D rather than 2F as per Ralf Brown's         ;
;                   Alternate Multiplex Interrupt proposal.                ;
;                 - shares interrupts as per IBM's Interrupt Sharing       ;
;                   Protocol.                                              ;
;              16-Nov-91, GAT                                              ;
;                 - made minor changes in return values from the Int 2d    ;
;                   handler to track Ralf's proposal.                      ;
;--------------------------------------------------------------------------;

;--------------------------------------------------------------------------;
;  Author:     George A. Theall                                            ;
;  Phone:      +1 215 662 0558                                             ;
;  SnailMail:  TifaWARE                                                    ;
;              506 South 41st St., #3M                                     ;
;              Philadelphia, PA.  19104   USA                              ;
;  E-Mail:     theall@gdalsrv.sas.upenn.edu (Internet)                     ;
;--------------------------------------------------------------------------;

%NEWPAGE
;--------------------------------------------------------------------------;
;                          D I R E C T I V E S                             ;
;--------------------------------------------------------------------------;
DOSSEG
MODEL     tiny

IDEAL
LOCALS
JUMPS

;
; This section comes from Misc.Inc.
;
@16BIT              EQU       (@CPU AND 8) EQ 0
@32BIT              EQU       (@CPU AND 8)
MACRO    ZERO     RegList                    ;; Zeros registers
   IRP      Reg, <RegList>
         xor      Reg, Reg
   ENDM
ENDM

;
; This section comes from DOS.Inc.
;
BELL                EQU       7
BS                  EQU       8
TAB                 EQU       9
CR                  EQU       13
LF                  EQU       10
ESCAPE              EQU       27             ; nb: ESC is a TASM keyword
SPACE               EQU       ' '
KEY_F1              EQU       3bh
KEY_F2              EQU       3ch
KEY_F3              EQU       3dh
KEY_F4              EQU       3eh
KEY_F5              EQU       3fh
KEY_F6              EQU       40h
KEY_F7              EQU       41h
KEY_F8              EQU       42h
KEY_F9              EQU       43h
KEY_F10             EQU       44h
KEY_HOME            EQU       47h
KEY_UP              EQU       48h
KEY_PGUP            EQU       49h
KEY_LEFT            EQU       4bh
KEY_RIGHT           EQU       4dh
KEY_END             EQU       4fh
KEY_DOWN            EQU       50h
KEY_PGDN            EQU       51h
KEY_INS             EQU       52h
KEY_DEL             EQU       53h
KEY_C_F1            EQU       5eh
KEY_C_F2            EQU       5fh
KEY_C_F3            EQU       60h
KEY_C_F4            EQU       61h
KEY_C_F5            EQU       62h
KEY_C_F6            EQU       63h
KEY_C_F7            EQU       64h
KEY_C_F8            EQU       65h
KEY_C_F9            EQU       66h
KEY_C_F10           EQU       67h
KEY_C_LEFT          EQU       73h
KEY_C_RIGHT         EQU       74h
KEY_C_END           EQU       75h
KEY_C_PGDN          EQU       76h
KEY_C_HOME          EQU       77h
KEY_C_PGUP          EQU       84h
KEY_F11             EQU       85h
KEY_F12             EQU       86h
KEY_C_F11           EQU       89h
KEY_C_F12           EQU       8ah
DOS                 EQU       21h            ; main MSDOS interrupt
STDIN               EQU       0              ; standard input
STDOUT              EQU       1              ; standard output
STDERR              EQU       2              ; error output
STDAUX              EQU       3              ; COM port
STDPRN              EQU       4              ; printer
TSRMAGIC            EQU       424bh          ; magic number
STRUC     ISR
          Entry     DW        10EBh          ; short jump ahead 16 bytes
          OldISR    DD        ?              ; next ISR in chain
          Sig       DW        TSRMAGIC       ; magic number
          EOIFlag   DB        ?              ; 0 (80) if soft(hard)ware int
          Reset     DW        ?              ; short jump to hardware reset
          Reserved  DB        7 dup (0)
ENDS
STRUC     ISRHOOK
          Vector    DB        ?              ; vector hooked
          Entry     DW        ?              ; offset of TSR entry point
ENDS
STRUC     TSRSIG
          Company   DB        8 dup (" ")    ; blank-padded company name
          Product   DB        8 dup (" ")    ; blank-padded product name
          Desc      DB        64 dup (0)     ; ASCIIZ product description
ENDS
GLOBAL at : PROC
GLOBAL errmsg : PROC
   GLOBAL ProgName : BYTE                    ; needed for errmsg()
   GLOBAL EOL : BYTE                         ; ditto
GLOBAL fgetc : PROC
GLOBAL fputc : PROC
GLOBAL fputs : PROC
GLOBAL getchar : PROC
GLOBAL getdate : PROC
GLOBAL getswtch : PROC
GLOBAL gettime : PROC
GLOBAL getvdos : PROC
GLOBAL getvect : PROC
GLOBAL isatty : PROC
GLOBAL kbhit : PROC
GLOBAL pause : PROC
GLOBAL putchar : PROC
GLOBAL setvect : PROC
GLOBAL sleep : PROC
GLOBAL find_NextISR : PROC
GLOBAL find_PrevISR : PROC
GLOBAL hook_ISR : PROC
GLOBAL unhook_ISR : PROC
GLOBAL free_Env : PROC
GLOBAL fake_Env : PROC
GLOBAL check_ifInstalled : PROC
GLOBAL install_TSR : PROC
GLOBAL remove_TSR : PROC

;
; This section comes from Math.Inc.
;
GLOBAL atoi : PROC
GLOBAL atou : PROC
GLOBAL utoa : PROC

;
; This section comes from String.Inc.
;
EOS                 EQU       0              ; terminates strings
GLOBAL isdigit : PROC
GLOBAL islower : PROC
GLOBAL isupper : PROC
GLOBAL iswhite : PROC
GLOBAL memcmp : PROC
GLOBAL strchr : PROC
GLOBAL strcmp : PROC
GLOBAL strlen : PROC
GLOBAL tolower : PROC
GLOBAL toupper : PROC


VERSION   equ       '1.1a'                   ; current version of program
                                             ; nb: change TSR_Ver too!
ERRH      equ       1                        ; errorlevel if help given
ERRVER    equ       5                        ; errorlevel if incorrect DOS ver
ERRINS    equ       10                       ; errorlevel if install failed
ERRUNI    equ       20                       ; errorlevel if uninstall failed
ERRNYI    equ       25                       ; errorlevel if not yet installed
OFF       equ       0
ON        equ       1

%NEWPAGE
;--------------------------------------------------------------------------;
;                        C O D E    S E G M E N T                          ;
;--------------------------------------------------------------------------;
CODESEG

ORG       0                                  ; address of code segment start
SegStart  DB        ?                        ;    used in when installing

ORG       80h                                ; address of commandline
CmdLen    DB        ?
CmdLine   DB        127 DUP (?)

ORG       100h                               ; start of .COM file
STARTUPCODE
          jmp       main


%NEWPAGE
;--------------------------------------------------------------------------;
;                        R E S I D E N T   D A T A                         ;
;--------------------------------------------------------------------------;
TSR_Sig   TSRSIG    <'TifaWARE', 'EATMEM  ', 'limits available memory'>
TSR_Ver   DW        (1 SHL 8) + 1            ; (minor shl 8) + major
MPlex     DB        ?                        ; multiplex ID
HookTbl   ISRHOOK   <2dh, do_Int2D>          ; 2d must be last!!!


%NEWPAGE
;--------------------------------------------------------------------------;
;                        R E S I D E N T   C O D E                         ;
;--------------------------------------------------------------------------;
;----  do_Int2D  ----------------------------------------------------------;
;  Purpose:    Handle INT 2D.                                              ;
;  Notes:      Only the install check is truly supported.                  ;
;  Entry:      AH = Multiplex ID,                                          ;
;              AL = function code                                          ;
;  Exit:       AL = FF in the case of an install check,                    ;
;              CX = TSR version,                                           ;
;              DX:DI points to resident copy of TSR signature.             ;
;  Calls:      n/a                                                         ;
;  Changes:    AL, CX, DX, DI                                              ;
;--------------------------------------------------------------------------;
PROC do_Int2D  FAR

; This structure is used to share intrrupts. The real entry point
; follows immediately after it.
my_Int2D  ISR       < , , , 0, ((@@hw_reset - $ - 2) SHL 8 + 0ebh), >

; Test if request is for me. Pass it along to next ISR in chain if not.
          cmp       ah, [cs:MPlex]           ; my multiplex ID?
          jz        SHORT @@forMe            ;   yes
          jmp       [cs:my_Int2d.OldISR]     ;   no, pass it along
                                             ;      nb: old vector issues IRET

; Check function as specified in AL.
@@forMe:
          cmp       al, 0                    ; installation check
          jz        SHORT @@InstallCheck
          cmp       al, 1                    ; get entry point
          jz        SHORT @@GetEntryPoint
          cmp       al, 2                    ; uninstall
          jz        SHORT @@Uninstall
          ZERO      al                       ; mark as not implemented
          jmp       SHORT @@Fin

@@InstallCheck:
          dec       al                       ; set AL = FF
          mov       cx, [cs:TSR_Ver]         ; CH = major; CL = minor
          mov       dx, cs                   ; DX:DI points to sig string
          mov       di, OFFSET TSR_Sig
          jmp       SHORT @@Fin

@@GetEntryPoint:
          ZERO      al                       ; mark as not supported
          jmp       SHORT @@Fin

@@Uninstall:
          ZERO      al                       ; not implemented in API
          jmp       SHORT @@Fin

@@Fin:
          iret                               ; return to caller

; Required for IBM Interrupt Sharing Protocol. Normally it is used
; only by hardware interrupt handlers.
@@hw_reset:
          retf
ENDP do_Int2D


;--------------------------------------------------------------------------;
;                E N D   O F   R E S I D E N T   S E C T I O N             ;
;--------------------------------------------------------------------------;
LastByte  =         $                        ; end of resident section


%NEWPAGE
;--------------------------------------------------------------------------;
;                       T R A N S I E N T   D A T A                        ;
;--------------------------------------------------------------------------;
ProgName  DB        'eatmem: '
          DB        EOS
EOL       DB        '.', CR, LF
          DB        EOS
HelpMsg   DB        CR, LF
          DB        'TifaWARE EATMEM, v', VERSION, ', ', ??Date
          DB        ' - TSR utility to limit available memory.', CR, LF
          DB        'Usage: eatmem [-options] Kbytes', CR, LF, LF
          DB        'Options:', CR, LF
          DB        '  -r    = remove from memory', CR, LF
          DB        '  -?    = display this help message', CR, LF, LF
          DB        'Kbytes is the amount of conventional memory to reserve.'
          DB        CR, LF, EOS
ErrMsgOpt DB        'illegal option -- '
OptCh     DB        ?                        ; room for offending character
          DB        EOS
ErrMsgArg DB        'invalid argument'
          DB        EOS
ErrMsgVer DB        'DOS v1 is not supported'
          DB        EOS
ErrMsgRes DB        'unable to go resident'
          DB        EOS
ErrMsgRem DB        'unable to remove from memory'
          DB        EOS
ErrMsgNYI DB        'not yet installed'
          DB        EOS
InstalMsg DB        'TifaWARE EATMEM, v', VERSION
          DB        ' now installed. Type "eatmem -r" when finished.'
          DB        CR, LF, EOS
RemoveMsg DB        'successfully removed'
          DB        EOS

SwitCh    DB        '-'                      ; char introducing options
HFlag     DB        0                        ; flag for on-line help
IFlag     DB        0                        ; flag for installing TSR
RFlag     DB        0                        ; flag for removing TSR
KBytes    DW        0                        ; amount of memory to leave free


%NEWPAGE
;--------------------------------------------------------------------------;
;                       T R A N S I E N T   C O D E                        ;
;--------------------------------------------------------------------------;
;----  go_Resident  -------------------------------------------------------;
;  Purpose:    Attempts to make TSR resident.                              ;
;  Notes:      Aborts if there's not enough memory to satisfy request.     ;
;              This procedure ONLY EXITS ON ERROR.                         ;
;  Entry:      DS = segment address of program's PSP, which also holds     ;
;                   HookTbl, a structure of type ISRHOOK.                  ;
;  Exit:       none                                                        ;
;  Calls:      check_ifInstalled, fputs, fake_Env, install_TSR, errmsg     ;
;  Changes:    AX, BX, CX, DX, DI, SI, ES                                  ;
;--------------------------------------------------------------------------;
PROC go_Resident

; See if there's already a copy resident. nb: only interested in AX
; on return from the install check.
          mov       si, OFFSET TSR_SIG
          call      check_ifInstalled        ; -> AX, CX, and DX:DI
          cmp       al, 2                    ; out of multiplex ids?
          jz        SHORT @@Abort            ;   yes, abort
          cmp       al, 1                    ; already loaded?
          jz        SHORT @@Abort            ;   yes
          mov       [MPlex], ah              ; save mplex id

; Calculate how many paragraphs to reserve when going resident.
; NB: DOS reserved largest chunk of memory when loading COM files.
; The size of this block is stored as a word at offset 3 in the MCB,
; which is located at the segment before the PSP.
          mov       bx, [KBytes]
          mov       cl, 6                    ; effectively multiplies by 64
          shl       bx, cl                   ; 1K * 64 = number of paragraphs

; Make sure enough memory is available to satisfy this request.
          mov       ax, ds                   ; point to PSP
          dec       ax                       ; and now to MCB
          mov       es, ax
          mov       dx, [WORD PTR es:3]      ; number of paragraphs reserved
          inc       ax
          mov       es, ax                   ; ES = PSP needed later
          sub       dx, bx                   ; # paragraphs to reserve
          dec       dx                       ; adjust for endpoint
          jc        SHORT @@Abort            ; abort if not enough

; Make sure enough memory is left for my ISR. Note that DX
; is the number of paragraphs to reserve from above.
          cmp       dx, (LastByte - SegStart + 16) SHR 4
          jb        SHORT @@Abort
          push      dx                       ; # paragraphs to reserve

; This is the point of no-return -- if we get here we're going resident.
          mov       bx, STDOUT
          mov       dx, OFFSET InstalMsg
          call      fputs

; Create a fake environment and free existing one.
          ZERO      cx                       ; tells fake_Env to fake it
          call      fake_Env

; Ok, all that's left is to go resident. Note that at this point
; ES = DS, and that HookTbl is relative to that.
          mov       bx, OFFSET HookTbl       ; pointer to ISRHOOK structure
          pop       dx                       ; recover # paragraphs to reserve
          call      install_TSR              ; never returns

; Execution gets here only on error because:
;  - all multiplex ids are in use! 
;  - the TSR is already resident.
;  - there is less than KBytes of memory currently free.
;  - reserving KBytes would not leave room for the TSR itself.
@@Abort:
          mov       dx, OFFSET ErrMsgRes     ; "unable to go resident"
          call      errmsg
          ret
ENDP go_Resident


;----  clear_Resident  ----------------------------------------------------;
;  Purpose:    Attempts to remove a TSR from memory.                       ;
;  Notes:      none                                                        ;
;  Entry:      DS = segment address of program's PSP.                      ;
;  Exit:       AL = 0 if removal succeeded; ERRNYI if not installed;       ;
;                   ERRUNI otherwise.                                      ;
;  Calls:      check_ifInstalled, remove_TSR, errmsg                       ;
;  Changes:    AX, BX, CX, DX, DI, SI, ES                                  ;
;--------------------------------------------------------------------------;
PROC clear_Resident

; See if there's already a copy resident.
          mov       si, OFFSET TSR_SIG
          call      check_ifInstalled        ; DS:SI -> AX, CX, DX:DI
          cmp       al, 1                    ; already loaded?
          jz        SHORT @@Removal          ;   yes
          mov       al, ERRNYI               ;   no, set return code
          mov       dx, OFFSET ErrMsgNYI     ;     "not yet installed"
          jmp       SHORT @@Fin

; Try to remove it.
@@Removal:
          mov       bx, OFFSET HookTbl       ; HookTbl in resident data area
          mov       es, dx                   ; install check returns DX:DI
          call      remove_TSR               ; ES:BX -> n/a
          jc        SHORT @@Abort
          ZERO      al
          mov       dx, OFFSET RemoveMsg
          jmp       SHORT @@Fin

@@Abort:
          mov       al, ERRUNI
          mov       dx, OFFSET ErrMsgRem     ; "unable to remove"

@@Fin:
          call      errmsg
          ret
ENDP clear_Resident


;----  skip_Spaces  -------------------------------------------------------;
;  Purpose:    Skips past spaces in a string.                              ;
;  Notes:      Scanning stops with either a non-space *OR* CX = 0.         ;
;  Entry:      DS:SI = start of string to scan.                            ;
;  Exit:       AL = next non-space character,                              ;
;              CX is adjusted as necessary,                                ;
;              DS:SI = pointer to next non-space.                          ;
;  Calls:      none                                                        ;
;  Changes:    AL, CX, SI                                                  ;
;--------------------------------------------------------------------------;
PROC skip_Spaces

          jcxz      SHORT @@Fin
@@NextCh:
          lodsb
          cmp       al, ' '
          loopz     @@NextCh
          jz        SHORT @@Fin              ; CX = 0; don't adjust

          inc       cx                       ; adjust counters if cx > 0
          dec       si

@@Fin:
          ret
ENDP skip_Spaces


;----  get_Opt  -----------------------------------------------------------;
;  Purpose:    Get a commandline option.                                   ;
;  Notes:      none                                                        ;
;  Entry:      AL = option character,                                      ;
;              CX = count of characters left in commandline,               ;
;              DS:SI = pointer to argument to process.                     ;
;  Exit:       CX = count of characters left _after_ processing,           ;
;              DS:SI = pointer to whitespace _after_ argument.             ;
;  Calls:      tolower, errmsg                                             ;
;  Changes:    DX,                                                         ;
;              [OptCh], [HFlag], [RFlag].                                  ;
;--------------------------------------------------------------------------;
PROC get_Opt

          mov       [OptCh], al              ; save for later
          call      tolower                  ; use only lowercase in cmp.
          cmp       al, 'r'
          jz        SHORT @@OptR
          cmp       al, '?'
          jz        SHORT @@OptH
          mov       dx, OFFSET ErrMsgOpt     ; unrecognized option
          call      errmsg                   ; then *** DROP THRU *** to OptH

; Various possible options.
@@OptH:
          mov       [HFlag], ON              ; set help flag
          jmp       SHORT @@Fin

@@OptR:
          mov       [RFlag], ON              ; remove from memory

@@Fin:
          ret
ENDP get_Opt


;----  get_Arg  -----------------------------------------------------------;
;  Purpose:    Reads a number from the commandline. Prints message and     ;
;                   sets HFlag if number is invalid.                       ;
;  Notes:      none                                                        ;
;  Entry:      CX = count of characters left in commandline,               ;
;              DS:SI = pointer to argument to process.                     ;
;  Exit:       cf = 0 if no errors in conversion,                          ;
;              AX = digit read (garbage if cf = 1),                        ;
;              CX = count of characters left _after_ processing,           ;
;              DS:SI = pointer to whitespace _after_ argument.             ;
;  Calls:      isdigit, atou, errmsg                                       ;
;  Changes:    AX, CX, DX, SI,                                             ;
;              [HFlag]                                                     ;
;--------------------------------------------------------------------------;
PROC get_Arg

          call      isdigit                  ; if not a digit, trouble!
          jz        SHORT @@ReadNum

          mov       dx, si                   ; flag arg as bad
          xchg      di, si
          mov       al, ' '
          repne     scasb                    ; find end of argument
          xchg      di, si
          jne       SHORT @@BadNum
          dec       si                       ; overshot so back up 1 char
          inc       cx
          jmp       SHORT @@BadNum           ; tell user it's bad

@@ReadNum:
          mov       dx, si                   ; save to adjust CX and if error
          call      atou
          pushf                              ; preserve flags
          add       cx, dx                   ; adjust counter
          sub       cx, si
          popf                               ; restore flags
          jnc       SHORT @@Fin

@@BadNum:
          mov       dx, OFFSET ErrMsgArg     ; invalid argument
          call      errmsg
          mov       [HFlag], ON
          stc                                ; flag error

@@Fin:
          ret
ENDP get_Arg


;----  process_CmdLine  ---------------------------------------------------;
;  Purpose:    Processes commandline arguments.                            ;
;  Notes:      A switch character by itself is ignored.                    ;
;              No arguments whatsoever causes help flag to be set.         ;
;  Entry:      n/a                                                         ;
;  Exit:       n/a                                                         ;
;  Calls:      skip_Spaces, get_Opt, get_Arg                               ;
;  Changes:    AX, CX, SI,                                                 ;
;              [IFlag], [KBytes],                                          ;
;              DX, [OptCh], [HFlag], [RFlag] (get_Opt)                     ;
;              Direction flag is cleared.                                  ;
;--------------------------------------------------------------------------;
PROC process_CmdLine

          cld                                ; forward, march!
          ZERO      ch
          mov       cl, [CmdLen]             ; length of commandline
          mov       si, OFFSET CmdLine       ; offset to start of commandline

          call      skip_Spaces              ; check if any args supplied
          or        cl, cl
          jnz       SHORT @@ArgLoop

          mov       [HFlag], ON              ; assume user needs help
          jmp       SHORT @@Fin

; For each blank-delineated argument on the commandline...
@@ArgLoop:
          lodsb                              ; next character
          dec       cl
          cmp       al, [SwitCh]             ; is it the switch character?
          jnz       SHORT @@NonOpt           ;   no

; Isolate each option and process it. Stop when a space is reached.
@@OptLoop:
          jcxz      SHORT @@Fin              ; abort if nothing left
          lodsb
          dec       cl
          cmp       al, ' '
          jz        SHORT @@NextArg          ; abort when space reached
          call      get_Opt
          jmp       @@OptLoop

; Process the current argument, which is *not* an option.
; Then, *drop thru* to advance to next argument.
@@NonOpt:
          dec       si                       ; back up one character
          inc       cl
          call      get_Arg
          jc        SHORT @@NextArg          ; error reading number?
          mov       [IFlag], ON
          mov       [KBytes], ax

; Skip over spaces until next argument is reached.
@@NextArg:
          call      skip_Spaces
          or        cl, cl
          jnz       @@ArgLoop

@@Fin:
          ret
ENDP process_CmdLine


;----  main  --------------------------------------------------------------;
;  Purpose:    Main section of program.                                    ;
;  Notes:      none                                                        ;
;  Entry:      Arguments as desired                                        ;
;  Exit:       Return code as follows:                                     ;
;                   0 => program ran successfully,                         ;
;                   ERRH => on-line help supplied,                         ;
;                   ERRDOS => incorrect DOS version,                       ;
;                   ERRINS => install failed,                              ;
;                   ERRUNI => uninstall failed,                            ;
;                   ERRNYI => program was not yet installed.               ;
;  Calls:      getvdos, errmsg, process_CmdLine, fputs, go_Resident,       ;
;                   clear_Resident                                         ;
;  Changes:    n/a                                                         ;
;--------------------------------------------------------------------------;
main:

; Must be running at least DOS v2.x.
          call      getvdos
          cmp       al, 2
          jae       SHORT @@ReadCmds
          mov       dx, OFFSET ErrMsgVer     ; gotta have at least DOS v2
          call      errmsg

; Parse commandline.
@@ReadCmds:
          call      process_CmdLine          ; process commandline args
          cmp       [HFlag], ON              ; user needs help?
          je        SHORT @@GiveHelp
          cmp       [IFlag], ON              ; install it?
          je        SHORT @@Install
          cmp       [RFlag], ON              ; remove it?
          je        SHORT @@Remove

; Display help if we get to this point. NB: errmsg is not used
; because it would write "eatmem: " first.
@@GiveHelp:
          mov       bx, STDERR               ; user must need help
          mov       dx, OFFSET HelpMsg
          call      fputs
          mov       al, ERRH
          jmp       SHORT @@Fin

@@Install:
          call      go_Resident              ; returns on error only
          mov       al, ERRINS
          jmp       SHORT @@Fin

@@Remove:
          call      clear_Resident

; Terminate the program using as return code what's in AL.
@@Fin:
          mov       ah, 4ch
          int       DOS
EVEN
;-------------------------------------------------------------------------;
;  Purpose:    Writes an ASCIIZ string to specified device.
;  Notes:      A zero-length string doesn't seem to cause problems when
;                 this output function is used.
;  Requires:   8086-class CPU and DOS v2.0 or better.
;  Entry:      BX = device handle,
;              DS:DX = pointer to string.
;  Exit:       Carry flag set if EOS wasn't found or handle is invalid.
;  Calls:      strlen
;  Changes:    none
;-------------------------------------------------------------------------;
PROC fputs

   push     ax cx di es
   mov      ax, ds
   mov      es, ax
   mov      di, dx
   call     strlen                        ; set CX = length of string
   jc       SHORT @@Fin                   ; abort if problem finding end
   mov      ah, 40h                       ; MS-DOS raw output function
   int      DOS
@@Fin:
   pop      es di cx ax
   ret

ENDP fputs


EVEN
;-------------------------------------------------------------------------;
;  Purpose:    Writes an error message to stderr.
;  Notes:      none
;  Requires:   8086-class CPU and DOS v2.0 or better.
;  Entry:      DS:DX = pointer to error message.
;  Exit:       n/a
;  Calls:      fputs
;  Changes:    none
;-------------------------------------------------------------------------;
PROC errmsg

   push     bx dx
   mov      bx, STDERR
   mov      dx, OFFSET ProgName           ; display program name
   call     fputs
   pop      dx                            ; recover calling parameters
   push     dx                            ; and save again to avoid change
   call     fputs                         ; display error message
   mov      dx, OFFSET EOL
   call     fputs
   pop      dx bx
   ret

ENDP errmsg


EVEN
;-------------------------------------------------------------------------;
;  Purpose:    Gets version of DOS currently running.
;  Notes:      none
;  Requires:   8086-class CPU and DOS v2.0 or better.
;  Entry:      n/a
;  Exit:       AL = major version number,
;              AH = minor version number (2.1 = 10).
;  Calls:      none
;  Changes:    AX
;-------------------------------------------------------------------------;
PROC getvdos

   push     bx cx                         ; DOS destroys bx and cx!
   mov      ah, 30h
   int      DOS
   pop      cx bx
   ret

ENDP getvdos


EVEN
;--------------------------------------------------------------------------;
;  Purpose:    Gets address of an interrupt handler.
;  Notes:      none
;  Requires:   8086-class CPU and DOS v2.0 or better.
;  Entry:      AL = interrupt of interest.
;  Exit:       ES:BX = address of current interrupt handler
;  Calls:      none
;  Changes:    ES:BX
;--------------------------------------------------------------------------;
PROC getvect

   push     ax
   mov      ah, 35h                       ; find address of handler
   int      DOS                           ; returned in ES:BX
   pop      ax
   ret
ENDP getvect


;--------------------------------------------------------------------------;
;  Purpose:    Sets an interrupt vector.
;  Notes:      none
;  Requires:   8086-class CPU and DOS v1.0 or better.
;  Entry:      AL = interrupt of interest,
;              DS:DX = address of new interrupt handler
;  Exit:       n/a
;  Calls:      none
;  Changes:    none
;--------------------------------------------------------------------------;
PROC setvect

   push     ax
   mov      ah, 25h                       ; set address of handler
   int      DOS
   pop      ax
   ret
ENDP setvect


EVEN
;--------------------------------------------------------------------------;
;  Purpose:    Finds the next in a chain of ISRs.
;  Notes:      ISRs must be shared according to the IBM Interrupt
;                 Sharing Protocol.
;  Requires:   8086-class CPU.
;  Entry:      ES:BX = entry point for a given ISR.
;  Exit:       ES:BX = entry point for next ISR in the chain,
;              cf = 1 on error
;  Calls:      none
;  Changes:    BX, ES, cf
;--------------------------------------------------------------------------;
PROC find_NextISR

; Save DS, then set it to ES. This will avoid segment overrides below.
   push     ds es
   pop      ds

; Run three tests to see if the ISR obeys the protocol.
;1) Entry should be a short jump (opcode 0EBh).
;2) Sig should equal a special value ("KB").
;3) Reset should be another short jump.
   cmp      [BYTE PTR (ISR PTR bx).Entry], 0ebh
   jnz      SHORT @@Abort
   cmp      [(ISR PTR bx).Sig], TSRMAGIC
   jnz      SHORT @@Abort
   cmp      [BYTE PTR (ISR PTR bx).Reset], 0ebh
   jnz      SHORT @@Abort

; Ok, looks like the ISR is following the Interrupt Sharing Protocol.
; nb: cf will be clear as a result of the last comparison.
   les      bx, [(ISR PTR bx).OldISR]
   jmp      SHORT @@Fin

; Uh, oh, somebody's not being very cooperative or we've hit DOS/BIOS.
@@Abort:
   stc                                    ; flag error

@@Fin:
   pop      ds
   ret

ENDP find_NextISR


;--------------------------------------------------------------------------;
;  Purpose:    Finds the previous in a chain of ISRs.
;  Notes:      ISRs must be shared according to the IBM Interrupt
;                 Sharing Protocol.
;  Requires:   8086-class CPU and DOS v2.0 or better.
;  Entry:      AL = vector hooked,
;              ES:BX = entry point for a given ISR.
;  Exit:       ES:BX = entry point for next ISR in the chain,
;              cf = 1 on error
;  Calls:      getvect, find_NextISR
;  Changes:    BX, ES, cf
;--------------------------------------------------------------------------;
PROC find_PrevISR

   push     ax cx dx

; Stack holds previous ISR. Initialize it to a null pointer.
   ZERO     cx
   push     cx cx

; Point CX:DX to current ISR, then get first ISR in the chain.
   mov      cx, es
   mov      dx, bx
   call     getvect                       ; AL -> ES:BX
   jmp      SHORT @@Cmp

; Cycle through ISRs until either a match is found or we can't go further.
@@Next:
   add      sp, 4                         ; get rid of two words on stack
   push     es bx                         ; now save ES:BX
   call     find_NextISR                  ; ES:BX -> ES:BX
   jc       SHORT @@Fin                   ; abort on error
@@Cmp:
   mov      ax, es                        ; are segs the same?
   cmp      ax, cx
   jnz      SHORT @@Next
   cmp      dx, bx                        ; what about offsets?
   jnz      SHORT @@Next

@@Fin:
   pop      bx es                         ; pointer to previous ISR
   pop      dx cx ax
   ret

ENDP find_PrevISR


;--------------------------------------------------------------------------;
;  Purpose:    Hooks into an ISR and keeps track of previous ISR.
;  Notes:      none
;  Requires:   8086-class CPU and DOS v2.0 or better.
;  Entry:      AL = vector to hook,
;              ES:BX = pointer to a structure of type ISR.
;  Exit:       n/a
;  Calls:      getvect, setvect
;  Changes:    n/a
;--------------------------------------------------------------------------;
PROC hook_ISR

   push     bx dx bp ds es

; Save old vector to it can be restored later. Then set new hook.
   push     es bx                         ; need them later
   call     getvect                       ; AL -> ES:BX
   pop      dx ds                         ; recover pointer to ISR
   mov      bp, dx                        ; use BP for indexing
   mov      [WORD (ISR PTR bp).OldISR], bx
   mov      [WORD ((ISR PTR bp).OldISR)+2], es
   call     setvect                       ; uses DS:DX

   pop      es ds bp dx bx
   ret

ENDP hook_ISR


;--------------------------------------------------------------------------;
;  Purpose:    Unhooks an ISR if possible.
;  Notes:      Unhooking an ISR is more complicated than hooking one
;                 because of the need to support interrupt sharing.
;  Requires:   8086-class CPU and DOS v2.0 or better.
;  Entry:      AL = vector hooked,
;              ES:BX = entry point of current ISR.
;  Exit:       cf = 1 on error
;  Calls:      find_PrevISR, setvect
;  Changes:    cf
;--------------------------------------------------------------------------;
PROC unhook_ISR

   push     bx cx dx ds es

; Point DS:DX to next ISR, then ES:BX to previous ISR in the chain.
   lds      dx, [(ISR PTR es:bx).OldISR]
   call     find_PrevISR                  ; ES:BX -> ES:BX
   jc       SHORT @@Fin                   ; abort on error

; If find_PrevISR() returned a null pointer, then the current ISR
; is first in the chain; just use DOS to reassign the vector.
; Otherwise, update the OldISR entry in the previous handler.
   mov      cx, es                        ; did find_PrevISR() ...
   or       cx, bx                        ; return null pointer?
   jnz      SHORT @@Update                ;   no. update OldISR
   call     setvect                       ;   yes, hook AL to DS:DX
   jmp      SHORT @@Fin
@@Update:
   mov      [WORD (ISR PTR es:bx).OldISR], dx
   mov      [WORD ((ISR PTR es:bx).OldISR)+2], ds

@@Fin:
   pop      es ds dx cx bx
   ret

ENDP unhook_ISR


EVEN
AMI         equ      2dh                  ; Alternate Multiplex Interrupt
ENVBLK      equ      2ch                  ; ptr in PSP to environment block


;--------------------------------------------------------------------------;
;  Purpose:    Frees up a program's environment block.
;  Notes:      Programs such as PMAP or MEM scan environment blocks to
;                 learn names of TSRs. Freeing it means such programs
;                 will not be able to identify the TSR.
;              It's ASSUMED the ENV BLOCK has NOT ALREADY been FREED.
;  Requires:   8086-class CPU and DOS v2.0 or better.
;  Entry:      ES = segment of program's PSP.
;  Exit:       none
;  Calls:      none
;  Changes:    none
;--------------------------------------------------------------------------;
PROC free_Env

   push     ax ds es

   push     es                            ; point DS to PSP too
   pop      ds
   mov      es, [ENVBLK]                  ; pointer to env block
   mov      ah, 49h                       ; free memory block
   int      DOS
   mov      [WORD PTR ENVBLK], 0          ; make it 0

   pop      es ds ax
   ret

ENDP free_Env


;--------------------------------------------------------------------------;
;  Purpose:    Replaces a program's real environment with a smaller, fake
;                 one to save space. Programs like PMAP and MEM though
;                 will still be able to identify TSRs.
;  Notes:      If run with DOS version lower than v3.10, the environment
;                 block is merely freed.
;  Requires:   8086-class CPU and DOS v2.0 or better.
;  Entry:      CX = size in bytes of pseudo-environment block (if 0 
;                 one is created containing just program name/args),
;              DS:SI = pointer to pseudo-environment block,
;              ES = segment of program's PSP.
;  Exit:       none
;  Calls:      getvdos, free_Env, strlen
;  Changes:    none
;--------------------------------------------------------------------------;
PROC fake_Env

   push     ax bx cx di si ds es
   pushf

; Make sure DOS is v3.10 or better. If not, just free environment.
; nb: I could code this to handle old versions so long as caller
; supplies a real block, but why bother?
   call     getvdos                       ; get DOS version
   xchg     al, ah
   cmp      ax, (3 SHL 8) + 10            ; v3.10 or better?
   jae      SHORT @@FindEnv               ;   yes
   call     free_Env                      ;   no, just free it
   jmp      SHORT @@Fin

; Locate environment block.
@@FindEnv:
   mov      bx, [es:ENVBLK]               ; pointer to env block
   mov      es, bx

; If CX is zero, point DS:SI to just the program name/args in the
; current environment. This format was introducted with DOS v3.10.
;
; nb: Refer to _Undocumented DOS, p 399 for format of environment block.
   cld                                    ; scasb and movsb must go forward
   or       cx, cx                        ; is CX zero?
   jnz      SHORT @@GetMem                ;   no
   mov      ds, bx                        ; point DS to env block too
   ZERO     al                            ; ends of ASCIIz strings
   ZERO     di                            ; start at offset 0
@@NextString:
   call     strlen                        ; find length of string at ES:DI
   add      di, cx                        ; update DI
   inc      di                            ;   and past EOS
   scasb                                  ; are we at another 0?
   jne      SHORT @@NextString            ;   no
   mov      si, di                        ; point SI to
   dec      si                            ;   EOS in ...
   dec      si                            ;   last string
   mov      [WORD PTR es:di], 1           ; only want prog name/args
   inc      di                            ; point to start of string
   inc      di
   call     strlen                        ; find its length
   add      cx, di                        ; get # bytes to move
   sub      cx, si
   inc      cx

; At this point, CX holds number of bytes to allocate and DS:SI point
; to a copy of the pseudo-environment block.
@@GetMem:
   ZERO     di                            ; either way, destination = 0
   mov      bx, cx                        ; from # bytes
   REPT     4
      shr      bx, 1                      ; get # paragraphs
   ENDM
   inc      bx                            ; think what if CX < 0fh
   push     bx                            ; must save BX if DOS fails
   mov      ah, 48h                       ; allocate memory
   int      DOS                           ; returns block in AX
   pop      bx
   jc       SHORT @@JustResize            ; cf => failure

; Memory allocation succeeded so: (1) Copy to new block. (2) Adjust
; pointer in program's PSP. (3) Free old block.
   push     es                            ; points to old env block
   mov      es, ax                        ; new block
   rep      movsb
   mov      ah, 62h                       ; get program's PSP
   int      DOS                           ; returns it in BX
   mov      ds, bx
   mov      [ENVBLK], es                  ; pointer to new env block
   pop      es                            ; recover pointer to old env
   mov      ah, 49h                       ; free it
   int      DOS
   jmp      SHORT @@Fin

; Memory allocation failed so we'll use existing block and resize it.
@@JustResize:
   rep      movsb
   mov      ah, 4ah                       ; modify allocation
   int      DOS

@@Fin:
   popf
   pop      es ds si di cx bx ax
   ret

ENDP fake_Env


;--------------------------------------------------------------------------;
;  Purpose:    Checks if a TSR has been installed in memory.
;  Notes:      For a description of the steps followed here, see Ralf
;                 Brown's alternate multiplex proposal.
;              This procedure MUST BE RUN before going resident and
;                 the multiplex id returned SHOULD BE SAVED in the
;                 resident data area.
;  Requires:   8086-class CPU
;  Entry:      DS:SI = pointer to TSR's signature string.
;  Exit:       AL = 0 if not installed, = 1 if installed, = 2 if all
;                 multiplex ids are in use,
;              AH = multiplex id to use based on AL,
;              CX = TSR version number if installed,
;              DX:DI = pointer to resident copy of TSR's sig if AL = 1.
;  Calls:      getvect, memcmp
;  Changes:    AX, CX, DX, DI
;--------------------------------------------------------------------------;
PROC check_ifInstalled

   push     bx es

; Do a quick check to see if 2d is hooked. 
   mov      al, AMI                       ; alternate multiplex interrupt
   call     getvect                       ; handler address in ES:BX
   ZERO     ax
   cmp      [BYTE PTR es:bx], 0cfh        ; is it IRET opcode?
   jz       SHORT @@Fin                   ;   yes, return with AX = 0

; Do an install check on each possible multiplex id. 
   ZERO     bx                            ; marks 1st unused mplex id
@@CheckIt:
   ZERO     al                            ; be sure to do install check
   int      AMI                           ; might trash CX and DX:DI
   or       al, al                        ; is AL zero still?
   jnz      SHORT @@CmpSigs               ;   no, multiplex's in use

; It's not in use. Save if it's the first.
   or       bl, bl                        ; 1st available id found already?
   jnz      SHORT @@NextMPlex             ;   yes
   inc      bl                            ;   no, but flag it now
   mov      bh, ah                        ;     and hold onto mplex
   jmp      SHORT @@NextMPlex

; Compare first 16 bytes of sigs. DS:SI points to a known sig;
; DX:DI to one somewhere in resident code.
@@CmpSigs:
   push     cx                            ; save TSR version number
   mov      cx, 16                        ; # bytes in sigs to compare
   mov      es, dx                        ; memcmp() needs ES:DI and DS:SI
   call     memcmp
   pop      cx                            ; recover TSR version number
   jnz      SHORT @@NextMPlex
   mov      al, 1
   jmp      SHORT @@Fin

; Move on to next multiplex number.
@@NextMPlex:
   add      ah, 1                         ; sets zf if AH was 255. Done?
   jnz      SHORT @@CheckIt               ;   no, back for more
   mov      ah, bh                        ;   yes, AH = 1st available id
   or       dl, bl                        ;   did we run out?
   jnz      SHORT @@Fin                   ;     no
   mov      al, 2                         ;     yes

@@Fin:
   pop      es bx
   ret

ENDP check_ifInstalled


;--------------------------------------------------------------------------;
;  Purpose:    Installs a TSR in memory.
;  Notes:      This procedure never returns.
;              No changes are made here to the environment block.
;              Entry points are assumed relative to ES.
;              Call check_ifInstalled() to determine which multiplex
;                 id will be used.
;  Requires:   8086-class CPU and DOS v2.0 or better.
;  Entry:      DX = number of paragraphs to reserve,
;              ES:BX = pointer to a structure of ISRHOOK.
;  Exit:       n/a
;  Calls:      hook_ISR
;  Changes:    n/a
;--------------------------------------------------------------------------;
PROC install_TSR

; Set hooks as specified by ISRHOOK structure. 
   mov      bp, bx                        ; BX needed when hooking ISRs
@@NextHook:
   mov      al, [(ISRHOOK PTR bp).Vector]
   mov      bx, [(ISRHOOK PTR bp).Entry]
   call     hook_ISR                      ; AL, ES:BX -> n/a
   add      bp, SIZE ISRHOOK
   cmp      al, AMI                       ; at end of table?
   jnz      SHORT @@NextHook              ;   no

; And now go resident. Note that DX already holds # paragraphs to keep.
   mov      ax, 3100h                     ; terminate/stay resident, rc = 0
   int      DOS                           ; via DOS
   ret                                    ; ***never reached***

ENDP install_TSR


;--------------------------------------------------------------------------;
;  Purpose:    Removes a TSR if possible.
;  Notes:      Caller should use check_ifInstalled() to make sure the
;                 TSR has first been installed.
;              Entry points are assumed to be relative to ES.
;  Requires:   8086-class CPU and DOS v2.0 or better.
;  Entry:      ES:BX = pointer to a structure of ISRHOOK.
;  Exit:       cf set if operation failed
;  Calls:      find_PrevISR, unhook_ISR
;  Changes:    AX, cf
;--------------------------------------------------------------------------;
PROC remove_TSR

   push     bx dx bp ds es                ; save registers

; Set DS to ES to avoid segment overrides. Also, use BP for indexing into 
; the hook table, and save it in DX as it's needed later.
   push     es
   pop      ds
   mov      bp, bx
   mov      dx, bx

; For each vector in the hook table, make sure the ISR can be unhooked.
@@NextVect:
   mov      al, [(ISRHOOK PTR bp).Vector]
   mov      bx, [(ISRHOOK PTR bp).Entry]
   push     es                            ; hang onto this
   call     find_PrevISR                  ; able to find it?
   pop      es
   jc       SHORT @@Fin                   ;   no, abort
   add      bp, SIZE ISRHOOK
   cmp      al, AMI                       ; at end of table?
   jnz      SHORT @@NextVect              ;   no

; It's possible to unhook all vectors, so go to it. 
   mov      bp, dx
@@NextHook:
   mov      al, [(ISRHOOK PTR bp).Vector]
   mov      bx, [(ISRHOOK PTR bp).Entry]
   call     unhook_ISR                    ; AL, ES:BX -> n/a
   jc       SHORT @@Fin                   ; it had better succeed!
   add      bp, SIZE ISRHOOK
   cmp      al, AMI                       ; at end of table?
   jnz      SHORT @@NextHook              ;   no

; Now free TSR's memory.
   mov      bx, [ENVBLK]
   or       bx, bx                        ; any environment block?
   jz       SHORT @@MainMem               ;   no
   mov      es, bx                        ;   yes, free it
   mov      ah, 49h
   int      DOS                           ; trashes AH
   jc       SHORT @@Fin                   ; shouldn't be necessary
@@MainMem:
   mov      ah, 49h
   mov      bx, ds                        ; free TSR's memory
   mov      es, bx
   int      DOS

@@Fin:
   pop      es ds bp dx bx                ; pop registers
   ret

ENDP remove_TSR


EVEN
;-------------------------------------------------------------------------;
;  Purpose:    Converts string of digits to an *unsigned* integer in
;              range [0, 65535].
;  Notes:      Conversion stops with first non-numeric character.
;  Requires:   8086-class CPU.
;  Entry:      DS:SI = pointer to string of digits.
;  Exit:       AX = unsigned integer (garbage if cf = 1),
;              DS:SI = pointer to first non-digit found,
;              cf = 1 if number is too big.
;  Calls:      none
;  Changes:    AX, SI
;              flags
;-------------------------------------------------------------------------;
PROC atou

   push     bx cx dx                      ; DX destroyed by MUL below
   ZERO     ax                            ; AX = digit to convert
   ZERO     bx                            ; BX = integer word
   mov      cx, 10                        ; CX = conversion factor

@@NextCh:
   mov      bl, [si]                      ; get character
   cmp      bl, '0'                       ; test if a digit
   jb       SHORT @@Fin
   cmp      bl, '9'
   ja       SHORT @@Fin
   inc      si                            ; bump up pointer
   mul      cx                            ; multiply old result by 10
   jc       SHORT @@Overflow
   sub      bl, '0'                       ; convert digit
   add      ax, bx                        ; add current value
   jnc      @@NextCh                      ; continue unless result too big

@@Overflow:
   ZERO     cx                            ; denotes overflow
   jmp      @@NextCh

@@Fin:
   cmp      cx, 10                        ; cf = (cx != 10)
   pop      dx cx bx
   ret

ENDP atou


EVEN
;-------------------------------------------------------------------------;
;  Purpose:    Tests if character is a valid ASCII digit.
;  Notes:      none
;  Requires:   8086-class CPU.
;  Entry:      AL = character to be tested.
;  Exit:       Zero flag set if true, cleared otherwise.
;  Calls:      none 
;  Changes:    flags
;-------------------------------------------------------------------------;
PROC isdigit

   cmp      al, '0'                       ; if < '0' zf = 0
   jb       SHORT @@Fin
   cmp      al, '9'                       ; if > '9' zf = 0
   ja       SHORT @@Fin
   cmp      al, al                        ; set Z flag
@@Fin:
   ret

ENDP isdigit


;-------------------------------------------------------------------------;
;  Purpose:    Tests if character is lowercase.
;  Notes:      none
;  Requires:   8086-class CPU.
;  Entry:      AL = character to be tested.
;  Exit:       Zero flag set if true, cleared otherwise.
;  Calls:      none 
;  Changes:    flags
;-------------------------------------------------------------------------;
PROC islower

   cmp      al, 'a'                       ; if < 'a' zf = 0
   jb       SHORT @@Fin
   cmp      al, 'z'                       ; if > 'z' zf = 0
   ja       SHORT @@Fin
   cmp      al, al                        ; set Z flag
@@Fin:
   ret

ENDP islower


;-------------------------------------------------------------------------;
;  Purpose:    Tests if character is uppercase.
;  Notes:      none
;  Requires:   8086-class CPU.
;  Entry:      AL = character to be tested.
;  Exit:       Zero flag set if true, cleared otherwise.
;  Calls:      none 
;  Changes:    flags
;-------------------------------------------------------------------------;
PROC isupper

   cmp      al, 'A'                       ; if < 'A' zf = 0
   jb       SHORT @@Fin
   cmp      al, 'Z'                       ; if > 'Z' zf = 0
   ja       SHORT @@Fin
   cmp      al, al                        ; set Z flag
@@Fin:
   ret

ENDP isupper


;-------------------------------------------------------------------------;
;  Purpose:    Tests if character is an ASCII whitespace.
;  Notes:      none
;  Requires:   8086-class CPU.
;  Entry:      AL = character to be tested.
;  Exit:       Zero flag set if true, cleared otherwise.
;  Calls:      none 
;  Changes:    flags
;-------------------------------------------------------------------------;
PROC iswhite

   cmp      al, SPACE                     ; if == SPACE then zf = 1
   jz       SHORT @@Fin
   cmp      al, TAB                       ; if == TAB then zf = 1
   jz       SHORT @@Fin
   cmp      al, LF                        ; if == LF then zf = 1
   jz       SHORT @@Fin
   cmp      al, CR                        ; if == CR then zf = 1
@@Fin:
   ret

ENDP iswhite


EVEN
;-------------------------------------------------------------------------;
;  Purpose:    Converts character to lowercase.
;  Notes:      none
;  Requires:   8086-class CPU.
;  Entry:      AL = character to be converted.
;  Exit:       AL = converted character.
;  Calls:      none
;  Changes:    AL
;              flags
;-------------------------------------------------------------------------;
PROC tolower

   cmp      al, 'A'                       ; if < 'A' then done
   jb       SHORT @@Fin
   cmp      al, 'Z'                       ; if > 'Z' then done
   ja       SHORT @@Fin
   or       al, 20h                       ; make it lowercase
@@Fin:
   ret

ENDP tolower


;-------------------------------------------------------------------------;
;  Purpose:    Converts character to uppercase.
;  Notes:      none
;  Requires:   8086-class CPU.
;  Entry:      AL = character to be converted.
;  Exit:       AL = converted character.
;  Calls:      none
;  Changes:    AL
;              flags
;-------------------------------------------------------------------------;
PROC toupper

   cmp      al, 'a'                       ; if < 'a' then done
   jb       SHORT @@Fin
   cmp      al, 'z'                       ; if > 'z' then done
   ja       SHORT @@Fin
   and      al, not 20h                   ; make it lowercase
@@Fin:
   ret

ENDP toupper


EVEN
;--------------------------------------------------------------------------;
;  Purpose:    Compares two regions of memory.
;  Notes:      none
;  Requires:   8086-class CPU.
;  Entry:      CX = number of bytes to compare,
;              DS:SI = start of 1st region of memory,
;              ES:DI = start of 2nd region.
;  Exit:       zf = 1 if equal.
;  Calls:      none
;  Changes:    zf
;--------------------------------------------------------------------------;
PROC memcmp

   push     cx di si
   pushf                                  ; save direction flag
   cld
   repe     cmpsb                         ; compare both areas
   popf                                   ; recover direction flag
   dec      di
   dec      si
   cmpsb                                  ; set flags based on final byte
   pop      si di cx
   ret

ENDP memcmp


EVEN
;-------------------------------------------------------------------------;
;  Purpose:    Calculates length of an ASCIIZ string.
;  Notes:      Terminal char is _not_ included in the count.
;  Requires:   8086-class CPU.
;  Entry:      ES:DI = pointer to string.
;  Exit:       CX = length of string,
;              cf = 0 and zf = 1 if EOS found,
;              cf = 1 and zf = 0 if EOS not found within segment.
;  Calls:      none
;  Changes:    CX,
;              flags
;-------------------------------------------------------------------------;
PROC strlen

   push     ax di
   pushf
   cld                                    ; scan forward only
   mov      al, EOS                       ; character to search for
   mov      cx, di                        ; where are we now
   not      cx                            ; what's left in segment - 1
   push     cx                            ; save char count
   repne    scasb
   je       SHORT @@Done
   scasb                                  ; test final char
   dec      cx                            ; avoids trouble with "not" below

@@Done:
   pop      ax                            ; get original count
   sub      cx, ax                        ; subtract current count
   not      cx                            ; and invert it
   popf                                   ; restore df
   dec      di
   cmp      [BYTE PTR es:di], EOS
   je       SHORT @@Fin                   ; cf = 0 if equal
   stc                                    ; set cf => error

@@Fin:
   pop      di ax
   ret

ENDP strlen


END
