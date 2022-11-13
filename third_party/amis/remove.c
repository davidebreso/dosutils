/************************************************************************/
/*									*/
/* REMOVE.C	Remove a specific AMIS-compliant TSR			*/
/* Public Domain 1992,1995 Ralf Brown					*/
/* Version 0.92 							*/
/* Last Edit: 9/24/95							*/
/*                                                                      */
/* Must be compiled in a large data model (compact recommended)		*/
/* ex.  TCC -mc REMOVE FINDTSRS.OBJ UNINSTAL.OBJ			*/
/*									*/
/************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <conio.h>
#include <ctype.h>
#include <string.h>
#include <dos.h>

extern int find_TSRs(char *mpx_numbers, char *manuf, char *name) ;
extern int AMIS_uninstall(int mpx_number) ;

/************************************************************************/

void usage(void)
{
   printf("Usage:\tREMOVE product\n") ;
   printf("\tREMOVE manufacturer product\n") ;
   printf("\t\tboth <manufacturer> and <product> may be abbreviated\n") ;
   printf("\t\tif <product> is *, all TSRs will be removed\n") ;
   exit(1) ;
}

/************************************************************************/

int main(int argc,char **argv)
{
   char mpx_numbers[256] ;
   union REGS regs ;
   int found, i, status ;
   char *manuf, *name ;
   char far *sig ;
	  
   printf("REMOVE\tPublic Domain 1992,1995 Ralf Brown\n") ;
   if (argc == 1 || argc > 3)
      usage() ;
   if (argc == 2)
      {
      manuf = NULL ;
      name = argv[1] ;
      }
   else
      {
      manuf = argv[1] ;
      name = argv[2] ;
      }
   if (strcmp(name,"*") == 0)
      name = "" ;  /* remove ALL TSRs */
   found = find_TSRs(mpx_numbers,manuf,name) ;	
   switch (found)
      {
      case 0:
	 printf("No matching TSR found\n") ;
	 break ;
      default:
	 printf("The specified name matches the following TSRs:\n") ;
	 printf("   Manufact  Product\n") ;
	 printf("   -------- --------\n") ;
	 for (i = 0 ; i < found ; i++)
	    {
	    regs.h.ah = mpx_numbers[i] ;
	    regs.h.al = 0 ;
	    int86(0x2D,&regs,&regs) ;
	    sig = MK_FP(regs.x.dx,regs.x.di) ;
	    printf("   %8.8s %8.8s\n",sig,sig+8) ;
	    }
	 printf("Remove all? [Y/N] ") ;
	 fflush(stdout) ;
	 if (toupper(getch()) != 'Y')
	    break ;
	 printf("\n") ;
	 /* fall through */
      case 1:
	 for (i = 0 ; i < found ; i++)
	    {
	    regs.h.ah = mpx_numbers[i] ;
	    regs.h.al = 0 ;
	    int86(0x2D,&regs,&regs) ;	/* get TSR signature */
	    sig = MK_FP(regs.x.dx,regs.x.di) ;
	    printf("Attempting removal of %8.8s %8.8s.... ",sig,sig+8) ;
	    status = AMIS_uninstall(mpx_numbers[i]) ;
	    switch(status)
	       {
	       case 0:
	          printf("removal service not supported.\n") ;
	          break ;
	       case 1:
	          printf("removal unsuccessful.\n") ;
	          break ;
	       case 2:
	          printf("will remove itself when able.\n") ;
	          break ;
	       case 5:
	          printf("can't remove now, try again.\n") ;
	          break ;
	       case 3:  /* no resident remover, TSR still enabled */
	       case 4:  /* no resident remover, TSR now disabled */
	          /* these cases were handled by AMIS_uninstall */
	          /* fall through to 0xFF */
	       case 0xFF:
	          printf("successfully removed.\n") ;
	          break ;
	       default:
	          printf("unknown return code %2.02X\n",status) ;
	          break ;
	       }
	    }
	 break ;
      }
   return 0 ;
}
