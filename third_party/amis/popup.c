/************************************************************************/
/*									*/
/* POPUP.C	Request pop-up of a specific AMIS-compliant TSR  	*/
/* Public Domain 1992,1995 Ralf Brown					*/
/* Version 0.92 							*/
/* Last Edit: 9/24/95							*/
/*                                                                      */
/* Must be compiled in a large data model (compact recommended)		*/
/* ex.	TCC -mc POPUP FINDTSRS.OBJ					*/
/*									*/
/************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <alloc.h>
#include <string.h>
#include <dos.h>

extern int find_TSRs(char *mpx_numbers, char *manuf, char *name) ;

/************************************************************************/

#define lengthof(x) (sizeof(x)/sizeof(x[0]))

char *reasons[] =
   {
    "unknown failure",
    "interrupts pass through swapped memory",
    "swap-in failed",
    "(unknown return code)"
   } ;
   
/************************************************************************/

void usage(void)
{
   printf("Usage:\tPOPUP product\n") ;
   printf("\tPOPUP manufacturer product\n") ;
   printf("\t\tboth <manufacturer> and <product> may be abbreviated\n") ;
   exit(1) ;
}

/************************************************************************/

int main(int argc,char **argv)
{
   char mpx_numbers[256] ;
   union REGS regs ;
   int found, i ;
   char *manuf, *name ;

   printf("POPUP\tPublic Domain 1992,1995 Ralf Brown\n") ;
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
   found = find_TSRs(mpx_numbers,manuf,name) ;	
   switch (found)
      {
      case 0:
	 printf("No matching TSR found\n") ;
	 break ; 
      case 1:
	 printf("Requesting popup....\n") ;
	 regs.h.ah = mpx_numbers[0] ;
	 regs.h.al = 0x03 ;
	 int86(0x2D,&regs,&regs) ;
	 switch(regs.h.al)
	    {
	    case 0:
	       printf("TSR does not provide a popup service.\n") ;
	       break ;
	    case 1:
	       printf("Can't pop up now, try again later.\n") ;
	       break ;
	    case 2:
	       printf("Will pop up when able....\n") ;
	       break ;
	    case 3:
	       printf("TSR is busy.\n") ;
	       break ;
	    case 4:
	       printf("TSR requires user intervention before popup.\n") ;
	       if (regs.x.bx >= lengthof(reasons)-1)
		  regs.x.bx = lengthof(reasons)-1 ;
	       printf("Standard Reason: %s\n",reasons[regs.x.bx]) ;
	       printf("Application Reason Code %4.04X\n",regs.x.cx) ;
	       break ;
	    case 0xFF:
	       printf("TSR successfully popped up, return code %4.04X\n",
			      regs.x.bx) ;
	       break ;
	    default:
	       printf("Unknown return code %2.02X\n",regs.h.al) ;
	       break ;
	    }
	 break ;
      default:
	 printf("The specified name matches the following TSRs:\n") ;
	 printf("   Manufact  Product\n") ;
	 printf("   -------- --------\n") ;
	 for (i = 0 ; i < found ; i++)
	    {
	    char far *sig ;
	    
	    regs.h.ah = mpx_numbers[i] ;
	    regs.h.al = 0 ;
	    int86(0x2D,&regs,&regs) ;
	    sig = MK_FP(regs.x.dx,regs.x.di) ;
	    printf("   %8.8s %8.8s\n",sig,sig+8) ;
	    }
	 break ;
      }
   return 0 ;
}
