/************************************************************************/
/*									*/
/* AMITSRS.C	List TSRs using the alternate multiplex interrupt	*/
/* Public Domain 1992 Ralf Brown					*/
/* Version 0.90 							*/
/* Last Edit: 9/12/92							*/
/*                                                                      */
/* Must be compiled in a large data model (compact recommended)		*/
/* ex.  TCC -mc AMITSRS							*/
/*									*/
/************************************************************************/

#include <stdio.h>
#include <dos.h>
#include "amis.h"

char *scancodes[] =
   {
      0,		/* scan code 0 is "no key" */
      "Esc",
      "1",		/* scan code 2 */
      "2",
      "3",		/* scan code 4 */
      "4",
      "5",		/* scan code 6 */
      "6",
      "7",		/* scan code 8 */
      "8",
      "9",		/* scan code 10 */
      "0",
      "-",		/* scan code 12 */
      "=",
      "Backsp",		/* scan code 14 */
      "Tab",
      "Q",
      "W",
      "E",
      "R",
      "T",
      "Y",
      "U",
      "I",
      "O",
      "P",		/* scan code 25 */
      "[",
      "]",
      "Enter",
      "Ctrl",
      "A",
      "S",
      "D",
      "F",
      "G",
      "H",
      "J",
      "K",
      "L",
      ";",
      "'",		/* scan code 40 */
      "`",
      "LShift",
      "\\",
      "Z",
      "X",
      "C",
      "V",
      "B",
      "N",
      "M",
      ",",
      ".",
      "/",		/* scan code 53 */
      "RShift",
      "*",
      "Alt",
      "Space",
      "CapsLk",
      "F1",
      "F2",
      "F3",
      "F4",
      "F5",
      "F6",		/* scan code 64 */
      "F7",
      "F8",
      "F9",
      "F10",
      "NumLk",
      "ScrlLk",
      "Home",
      "Up",
      "PgUp",		/* scan code 73 */
      "Grey-",
      "Left",
      "KP5",
      "Right",
      "Grey+",
      "End",
      "Down",
      "PgDn",		/* scan code 81 */
      "Ins",
      "Del",
      "SysRq", 
      0,
      0,
      "F11",		/* scan code 87 */
      "F12",
   } ;

/************************************************************************/

void display_hotkeys(int mpx_number)
{
   union REGS regs ;
   char far *hotkeys ;
   int num_hotkeys, hotkey_type ;
   int shifts ;
   
   regs.h.ah = mpx_number ;
   regs.h.al = AMIS_HOTKEYS ;	/* get hotkeys */
   int86(0x2D,&regs,&regs) ;
   if (regs.h.al == AMIS_SUCCESSFUL) /* supported? */
      {
      hotkeys = MK_FP(regs.x.dx,regs.x.bx) ;
      hotkey_type = hotkeys[0] ;
      num_hotkeys = hotkeys[1] ;
      printf("%18s%d hotkey%s on ","",num_hotkeys,(num_hotkeys == 1)?"":"s") ;
      if ((hotkey_type & HK_INT09ENTRY) || (hotkey_type & HK_INT09EXIT))
	 printf("INT 09h  ") ;
      if ((hotkey_type & HK_INT15ENTRY) || (hotkey_type & HK_INT15EXIT))
	 printf("INT 15h") ;
      printf("\n") ;
      hotkeys += 2 ;		/* skip hotkey list header */
      while (num_hotkeys-- > 0)
	 {
	 shifts = *((int far *)(hotkeys+1)) ;
	 printf("%22s","") ;
	 if ((shifts & HK_ANYCTRL) == HK_ANYCTRL)
	    printf("Ctrl-") ;
	 else if ((shifts & HK_BOTHCTRL) == HK_BOTHCTRL)
	    printf("Ctrl-Ctrl-") ;
	 else if ((shifts & HK_LCTRL) == HK_LCTRL)
	    printf("LCtrl-") ;
	 else if ((shifts & HK_RCTRL) == HK_RCTRL)
	    printf("RCtrl-") ;
	 if ((shifts & HK_ANYSHIFT) == HK_ANYSHIFT)
	    printf("Shift-") ;
	 else if ((shifts & HK_BOTHSHIFT) == HK_BOTHSHIFT)
	    printf("Shift-Shift-") ;
	 else if ((shifts & HK_LSHIFT) == HK_LSHIFT)
	    printf("LShift-") ;
	 else if ((shifts & HK_RSHIFT) == HK_RSHIFT)
	    printf("RShift-") ;
	 if ((shifts & HK_ANYALT) == HK_ANYALT)
	    printf("Alt-") ;
	 else if ((shifts & HK_BOTHALT) == HK_BOTHALT)
	    printf("Alt-Alt-") ;
	 else if ((shifts & HK_LALT) == HK_LALT)
	    printf("LAlt-") ;
	 else if ((shifts & HK_RALT) == HK_RALT)
	    printf("RAlt-") ;
	 if (shifts & HK_SCROLLOCK)
	    printf("ScrlLk-") ;
	 if (shifts & HK_NUMLOCK)
	    printf("NumLk-") ;
	 if (shifts & HK_CAPSLOCK)
	    printf("CapsLk-") ;
	 if (shifts & HK_SYSREQ)
	    printf("SysRq-") ;
	 if (scancodes[*hotkeys])
	    printf("%s",scancodes[*hotkeys]) ;
	 else
	    printf("nokey") ;
	 if (shifts & HK_SCRLLOCK_ON)
	    printf(" (ScrlLk on)") ;
	 if (shifts & HK_NUMLOCK_ON)
	    printf(" (NumLk on)") ;
	 if (shifts & HK_CAPSLOCK_ON)
	    printf(" (CapsLk on)") ;
	 printf("\n") ;
	 }
      }
   else
      printf("%18sno hotkeys\n","") ;
   return ;
}

/************************************************************************/

int main(int argc,char **argv)
{
   int mpx ;
   int did_banner = 0, verbose = 0 ;
   union REGS regs ;
   char far *sig ;
   
   /* prevent 'unused parameters' warnings */
   (void)argv ;
   /**/
   /* if any commandline arguments, turn on verbose mode */
   /**/
   if (argc > 1)
      verbose = 1 ;
   /**/
   /* loop through all 256 multiplex numbers, listing each signature we find */
   /**/
   for (mpx = 0 ; mpx <= 255 ; mpx++)
      {
      regs.h.ah = mpx ;
      regs.h.al = AMIS_INSTCHECK ;  /* installation check */
      int86(0x2D,&regs,&regs) ;
      if (regs.h.al == AMIS_SUCCESSFUL) /* installed? */
	 {
	 if (!did_banner)
	    {
	    printf("Manufact  Product\t\tDescription\n") ;
	    printf("-------- -------- ----------------------------------------------\n") ;
	    did_banner = 1 ;
	    }
	 sig = MK_FP(regs.x.dx,regs.x.di) ;
	 printf("%8.8s %8.8s %.61s\n",sig,sig+8,sig+16) ;
	 /**/
	 /* if we were asked for a verbose display, also display TSR version */
	 /* and private API entry point (if present) on a second line	     */
	 /**/
	 if (verbose)
	    {
	    printf("%18sversion %d.%02d","",regs.h.ch,regs.h.cl) ;
	    regs.h.ah = mpx ;
	    regs.h.al = AMIS_ENTRYPOINT ;  /* get private entry point */
	    int86(0x2D,&regs,&regs) ;
	    if (regs.h.al == AMIS_SUCCESSFUL)
	       printf("   entry point %04.4X:%04.4X ",regs.x.dx,regs.x.bx) ;
	    else
	       printf("   no private entry point") ;
	    printf("\n") ;
	    display_hotkeys(mpx) ;
	    }
	 }
      }
   if (!did_banner)
      printf("No TSRs are using the alternate multiplex interrupt\n") ;
   return 0 ;
}
