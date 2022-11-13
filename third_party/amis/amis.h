/*-----------------------------------------------------------------------*/
/* Alternate Multiplex Interrupt Specification Library			 */
/* AMIS.H  	Public Domain 1992 Ralf Brown				 */
/*      	You may do with this software whatever you want, but	 */
/*      	common courtesy dictates that you not remove my name	 */
/*      	from it.						 */
/*									 */
/* Version 0.90 							 */
/* LastEdit: 9/12/92							 */
/*-----------------------------------------------------------------------*/

#ifndef __AMIS_H
#define __AMIS_H

#define AMIS_VERSION 350    /* version 3.5 of the Alternate Multiplex Interrupt Spec */
#define AMISLIB_VERSION 90  /* version 0.90 of this library */

/*-----------------------------------------------------------------------*/
/* symbolic names for the AMIS API functions				 */
/*-----------------------------------------------------------------------*/

#define AMIS_INSTCHECK	0	/* installation check */
#define AMIS_ENTRYPOINT 1	/* get private entry point */
#define AMIS_REMOVE	2	/* request removal */
#define AMIS_POPUP	3	/* request popup */
#define AMIS_VECTORS	4	/* get interrupt vector usage */
#define AMIS_HOTKEYS	5	/* get hotkeys */

/*-----------------------------------------------------------------------*/
/* Return codes for various API calls					 */
/*-----------------------------------------------------------------------*/

/* general, applies to all standard calls */
#define AMIS_NOTIMPLEMENTED	0
#define AMIS_SUCCESSFUL		0xFF

/* additional return codes for Uninstall (function 02h) */
#define AMIS_UNINST_FAILED	1
#define AMIS_UNINST_WILL_DO	2
#define AMIS_UNINST_SAFE_ON	3
#define AMIS_UNINST_SAFE_OFF	4
#define AMIS_UNINST_TRYLATER 	5

/* additional return codes for Popup (function 03h) */
#define AMIS_POPUP_TRYLATER	1
#define AMIS_POPUP_WILLDO	2
#define AMIS_POPUP_BUSY		3
#define AMIS_POPUP_NEEDHELP	4

/* additional return codes for Check Interrupt Chained (function 04h) */
#define AMIS_CHAIN_DONTKNOW	1
#define AMIS_CHAIN_HOOKED	2
#define AMIS_CHAIN_HOOKED_ADDR	3
#define AMIS_CHAIN_HOOKLIST	4
#define AMIS_CHAIN_NOTUSED	0xFF

/* hotkey type bits returned by Get Hotkeys (function 05h) */
#define HK_INT09ENTRY	1    /* TSR checks keys before calling INT 09h */
#define HK_INT09EXIT	2    /* TSR checks keys after calling INT 09h */
#define HK_INT15ENTRY	4    /* TSR checks keys before chaining INT 15h/AH=4Fh */
#define HK_INT15EXIT	8    /* TSR checks keys after chaining INT 15h/AH=4Fh */
#define HK_INT16OLD	0x10 /* TSR checks on INT 16/AH=00h-02h */
#define HK_INT16NEW	0x20 /* TSR checks on INT 16/AH=10h-12h */

/* hotkey shift bits returned by Get Hotkeys (function 05h) */
#define HK_NONE 	0x0000	/* no shift keys */
#define HK_RSHIFT	0x0001
#define HK_LSHIFT	0x0002
#define HK_BOTHSHIFT	0x0003	/* both Shift keys must be pressed */
#define HK_ANYCTRL	0x0004	/* either Control key must be pressed */
#define HK_ANYALT	0x0008	/* either Alt key must be pressed */
#define HK_SCRLLOCK_ON	0x0010	/* ScrollLock must be on when hotkey pressed */
#define HK_NUMLOCK_ON	0x0020	/* NumLock must be on when hotkey pressed */
#define HK_CAPSLOCK_ON	0x0040	/* CapsLock must be on when hotkey pressed */
#define HK_ANYSHIFT	0x0080	/* either Shift key must be pressed */
#define HK_LCTRL	0x0100
#define HK_LALT 	0x0200
#define HK_RCTRL	0x0400
#define HK_RALT 	0x0800
#define HK_BOTHCTRL	0x0500	/* both Control keys must be pressed */
#define HK_BOTHALT	0x0A00	/* both Alt keys must be pressed */
#define HK_SCROLLOCK	0x1000	/* ScrollLock must be pressed with hotkey */
#define HK_NUMLOCK	0x2000	/* NumLock must be pressed with hotkey */
#define HK_CAPSLOCK	0x4000	/* CapsLock must be pressed with hotkey */
#define HK_SYSREQ	0x8000	/* SysRq must be pressed with hotkey */

/* hotkey flag bist returned by Get Hotkeys (function 05h) */
#define HK_CHAINBEFORE	1	/* TSR chains hotkey before processing it */
#define HK_CHAINAFTER	2	/* TSR chains hotkey after processing it */
#define HK_MONITOR	4	/* TSR monitors hotkey, it should be passed thru */
#define HK_NOPRESSRELEASE 8	/* hotkey won't activate if other keys pressed */
			        /* and released before hotkey combo completed */
#define HK_REMAPPED	0x10	/* this key is remapped into some other key */

#define HK_NOCHAIN	0	/* TSR swallows hotkey */

/* hotkey scan codes returned by Get Hotkeys (function 05h) */
#define SCAN_NONE	0
#define SCAN_ESC	1
#define SCAN_1		2
#define SCAN_2		3
#define SCAN_3		4
#define SCAN_4		5
#define SCAN_5		6
#define SCAN_6		7
#define SCAN_7		8
#define SCAN_8		9
#define SCAN_9		10
#define SCAN_0		11
#define SCAN_HYPHEN	12
#define SCAN_EQUAL	13
#define SCAN_BACKSP	14
#define SCAN_TAB	15
#define SCAN_Q		16
#define SCAN_W		17
#define SCAN_E		18
#define SCAN_R		19
#define	SCAN_T		20
#define SCAN_Y		21
#define SCAN_U		22
#define SCAN_I		23
#define SCAN_O		24
#define SCAN_P		25
#define SCAN_LBRACKET	26
#define SCAN_RBRACKET	27
#define SCAN_ENTER	28
#define	SCAN_CTRL	29
#define SCAN_A		30
#define SCAN_S		31
#define SCAN_D		32
#define SCAN_F		33
#define SCAN_G		34
#define SCAN_H		35
#define SCAN_J		36
#define SCAN_K		37
#define SCAN_L		38
#define SCAN_SEMICOLON	39
#define SCAN_SQUOTE	40
#define SCAN_BACKQUOTE	41
#define SCAN_LSHIFT	42
#define SCAN_BACKSLASH	43
#define SCAN_Z		44
#define SCAN_X		45
#define SCAN_C		46
#define SCAN_V		47
#define SCAN_B		48
#define SCAN_N		49
#define SCAN_M		50
#define SCAN_COMMA	51
#define SCAN_PERIOD	52
#define SCAN_SLASH	53
#define SCAN_RSHIFT	54
#define SCAN_GREYSTAR	55
#define SCAN_ALT	56
#define SCAN_SPACE	57
#define SCAN_CAPSLK	58
#define SCAN_F1		59
#define SCAN_F2		60
#define SCAN_F3		61
#define SCAN_F4		62
#define SCAN_F5		63
#define SCAN_F6		64
#define SCAN_F7		65
#define SCAN_F8		66
#define SCAN_F9		67
#define SCAN_F10	68
#define SCAN_NUMLK	69
#define SCAN_SCRLLK	70
#define SCAN_HOME	71
#define SCAN_UP		72
#define SCAN_PGUP	73
#define SCAN_GREYMINUS	74
#define SCAN_LEFT	75
#define SCAN_KP5	76
#define SCAN_RIGHT	77
#define SCAN_GREYPLUS	78
#define SCAN_END	79
#define SCAN_DOWN	80
#define SCAN_PGDN	81
#define SCAN_INS	82
#define SCAN_DEL	83
#define SCAN_SYSRQ	84
#define SCAN_F11	87
#define SCAN_F12	88
#define HK_ONRELEASE	0x80  /* hotkey activates on key release (add to scan code) */

/*-----------------------------------------------------------------------*/
/* installation flags for install_TSR()					 */
/*-----------------------------------------------------------------------*/

#define BEST_FIT   1		/* use best-fit rather than first-fit           */
#define UMB_ONLY   2		/* don't load into low memory, only into a UMB  */
#define LOW_ONLY   4		/* don't use UMB even if high memory available  */
			        /* (note: can't set both UMB_ONLY and LOW_ONLY) */
#define USE_TOPMEM 8		/* use the top of low memory if no high memory  */
				/* (this is not always the best place to load)  */
#define PATCH_RESIDENT 0x80	/* patch resident code with actual memblock addr */

/*-----------------------------------------------------------------------*/
/* type declarations							 */
/*-----------------------------------------------------------------------*/

typedef struct
   {
   int multiplex ;
   int version ;
   char far *signature ;
   char reserved[2] ;  /* used internally */
   } AMISREC ;
   
/*-----------------------------------------------------------------------*/
/* function prototypes							 */
/*-----------------------------------------------------------------------*/

#if 0
AMISREC *AMIS_find_TSR(char *manufacturer,char *name,int searchtype) ;
void far *AMIS_entrypoint(int multiplex) ;
int AMIS_uninstall(int multiplex) ;
int AMIS_popup(int multiplex,int *retcode) ;
char far *AMIS_hotkeys(int multiplex) ;
#endif /* 0 */

#endif /* __AMIS_H */
