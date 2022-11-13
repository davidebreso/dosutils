/************************************************************************/
/*									*/
/* FINDTSRS.C	Find all TSRs with signatures matching a given name	*/
/* Public Domain 1992 Ralf Brown					*/
/* Version 0.90 							*/
/* Last Edit: 9/12/92							*/
/*                                                                      */
/* Must be compiled in a large data model (compact recommended)		*/
/* ex.	TCC -mc -c FINDTSRS.C						*/
/*									*/
/************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dos.h>

/************************************************************************/

int find_TSRs(char *mpx_numbers,char *manuf,char *name)
{
   int found = 0 ;
   int mpx, len1, len2 ;
   char far *sig ;
   union REGS regs ;
   
   /**/
   /* loop through all 256 multiplex numbers, remembering each match we find */
   /**/
   for (mpx = 0 ; mpx <= 255 ; mpx++)
      {
      regs.h.ah = mpx ;
      regs.h.al = 0 ;  /* installation check */
      int86(0x2D,&regs,&regs) ;
      if (regs.h.al == 0xFF) /* installed? */
	 {
	 sig = MK_FP(regs.x.dx,regs.x.di) ;
	 if (manuf)
	    len1 = min(strlen(manuf),8) ;
	 len2 = min(strlen(name),8) ;
	 if ((manuf == NULL || (strnicmp(manuf,sig,len1) == 0)) &&
	     strnicmp(name,sig+8,len2) == 0)
	    mpx_numbers[found++] = mpx ;
	 }
      }
   return found ;
}

