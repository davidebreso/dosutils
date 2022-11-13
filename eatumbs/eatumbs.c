/*
    eatumbs.c - A small program to reserve upper memory blocks

    Copyright (C) 2022 by github.com/davidebreso
*/

#include <dos.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>

#define MY_MEMORY_SIGNATURE "eatUMBS "
#define MY_VERSION_TEXT "v1.0"
#define MY_TSR_SIGNATURE "DB      eatUMBS "

/* these things are imported from the resident part */
extern void (interrupt far *far OldInt2D)();
extern void interrupt far int2d_handler();
extern void far END_int2d_handler(void);
extern unsigned char far MPlex;


#pragma pack (1)
/* Define structure for Interrupt Handler header */
struct TSR_Header {
    unsigned char  Entry;
    unsigned char  StartOffset;
    void far       *OldISR;
    unsigned int    Sig;
    unsigned char  HwInt;
    unsigned char  Reset;
};

/*
    this allocates a block of memory with the given strategy
*/
unsigned int AllocMemory(unsigned int residentsize, unsigned int strategy)
{
    union REGS r;
    int allocSeg;
    int oldlink,oldstrategy;

    r.x.ax = 0x5802;    /* get UMB link state */
    int86(0x21,&r,&r);
    oldlink = r.h.al;

    r.x.ax = 0x5800;    /* get allocation strategy */
    int86(0x21,&r,&r);
    oldstrategy = r.h.al;

    r.x.ax = 0x5803;    /* set UMB link state */
    r.x.bx = 1;         /* 0 = no UMB link, 1 = set UMB link */
    int86(0x21,&r,&r);

    r.x.ax = 0x5801;     /* set allocation strategy */
    r.x.bx = strategy;
    int86(0x21,&r,&r);

    r.x.ax = 0x4800;                       /* dosAllocMem */
    r.x.bx = (residentsize + 15) >> 4;     /* size in paragraphs */
    int86(0x21,&r,&r);

    if (r.x.cflag) return 0;

    allocSeg = r.x.ax;

    *(char far*)MK_FP(allocSeg-1, 1) = allocSeg;   /* makes it selfreferencing */
    _fmemcpy(MK_FP(allocSeg-1, 8), MY_MEMORY_SIGNATURE, 8);   /* mark our name */

    r.x.ax = 0x5803;     /* reset UMB link state */
    r.x.bx = oldlink;
    int86(0x21,&r,&r);

    r.x.ax = 0x5801;         /* reset UMB allocation strategy */
    r.x.bx = oldstrategy;
    int86(0x21,&r,&r);

    return allocSeg;
}

/*
 * Search for previously installed TSR
 *
 * returns 0 if not installed, 1 if installed, 2 if all multiplex ids are in use,
 * 'id' is modified to the multiplex id to use based on return value,
 * 'segment' point to the segment of the installed copy (if any)
 *
 */
unsigned int CheckIfInstalled(unsigned char *id, unsigned int *segment)
{
    unsigned int curr_id, free_id = 0x100;
    void far *signature;

	union  REGS r;

    /* Search for available multiplex interrupt */
    for(curr_id = 0; curr_id < 256; curr_id++)
    {
        r.h.al = 0;                 /* function 00h installation check */
        r.h.ah = curr_id & 0xFF;    /* AH = multiplex number */
        int86(0x2D, &r, &r);
        /* return: AL = 00h if free, FFh if in use */
        if(r.h.al == 0xFF) {
            /* DX:DI -> signature string */
            signature = MK_FP(r.x.dx, r.x.di);
            // printf("Signature for id %d at %04x:%04x\n", curr_id, FP_SEG(signature), FP_OFF(signature));
            if(_fmemcmp(signature, MY_TSR_SIGNATURE, 16) == 0) {
                /* found installed TSR, set id and segment */
                *id = curr_id;
                *segment = FP_SEG(signature);
                return 1;
            }       
        } else if(r.h.al == 0 && (free_id & 0x100)) {
            free_id = curr_id;
        }
    }
    if(free_id > 255) {
        return 2;
    } else {
        *id = free_id;
        return 0;
    }    
}

/*
 * Get previous Interrupt handler in the chain
 */
struct TSR_Header far *GetPrevHandler(void far *curr_handler)
{
    struct TSR_Header far *prev_handler;

	union  REGS r;
	struct SREGS sregs;
        
    /* Start from first INT 2D handler */
    prev_handler = (void far *)_dos_getvect(0x2d);
    // printf("First handler at %04x:%04x\n", FP_SEG(prev_handler), FP_OFF(prev_handler));
    if(prev_handler == curr_handler) return prev_handler;
    
    while(1)
    {
        /* 
            Run three tests to see if the ISR obeys the protocol.
            1) Entry should be a short jump (opcode 0EBh).
            2) Sig should equal a special value ("KB").
            3) Reset should be another short jump.
        */
        /* printf("handler @%04x:%04x: Entry %04x, Sig %04x, Reset %04x\n", 
                FP_SEG(prev_handler), FP_OFF(prev_handler), 
                prev_handler->Entry, prev_handler->Sig, prev_handler->Reset); */
        if(prev_handler->Entry == 0xeb && prev_handler->Sig == 0x424b && prev_handler->Reset == 0xeb)
        {
            /* Ok, looks like the ISR is following the Interrupt Sharing Protocol. */
            if(prev_handler->OldISR == curr_handler) {
                /* We have found the previous element, return */
                return prev_handler;
            }
            prev_handler = prev_handler->OldISR;
        } else {
            /* Uh, oh, somebody's not being very cooperative or we've hit DOS/BIOS */
            return NULL;
        }
    }
}

/*
 * Print usage information
 */
void usage()
{
	printf("eatUMBS " MY_VERSION_TEXT " [" __DATE__ "]\n" );
	printf("Usage:\n"
		   "   EATUMBS size - reserve 'size' bytes of upper memory\n"
		   "   EATUMBS U    - uninstall and release upper memory\n");
}

int main(int argc, char *argv[])
{
    unsigned int residentSeg, residentsize;
    unsigned int size = 400;
    int i, status;
	char *argptr;
    void far *orig2d, far *curr2d;
    struct TSR_Header far *prev2d;
    unsigned char my_id;
    
	union  REGS r;
	struct SREGS sregs;

	
	if(argc != 2) {
	    usage();
	    return 1;
	}
	
    argptr = argv[1];
    if(toupper(argptr[0]) == 'U')
    {
        /* Get current installation info */
        if(CheckIfInstalled(&my_id, &residentSeg) == 1)
        {
            orig2d = *(void far *far*)MK_FP(residentSeg,FP_OFF(&OldInt2D));
            curr2d = MK_FP(residentSeg, FP_OFF(int2d_handler));
            /* Get previous INT 2D handler */
            prev2d = GetPrevHandler(curr2d);
            if(prev2d == curr2d) {
                /* Restore old INT 2D handler */
                r.x.ax  = 0x252D;              /* dosSetVect */
                r.x.dx  = FP_OFF(orig2d);
                sregs.ds   = FP_SEG(orig2d);
                int86x(0x21,&r,&r,&sregs);
                // printf("INT 2D handler restored to %04x:%04x\n", FP_SEG(orig2d), FP_OFF(orig2d));
            } else if(prev2d != NULL) {
                // printf("Previous INT 2D handler at %04x:%04x\n", FP_SEG(prev2d), FP_OFF(prev2d));
                prev2d->OldISR = orig2d;
            } else {
                printf("ERROR: unable to remove from memory.");
                return 1;
		    }
            /* Release memory */
            _dos_freemem(residentSeg);
            // printf("eatUMBS uninstalled from segment %04x\n", residentSeg);
            return 0;
        } else {
            printf("ERROR: eatUMBS is not installed.\n");
            return 1;
        }
    }
    
    size = atoi(argptr);
    if(size == 0) {
            printf("ERROR: unknown argument %s\n", argptr);
            usage();
            return 1;        
    }
	residentsize = FP_OFF(END_int2d_handler);
	if(size < residentsize) {
	    printf("Memory block too small. \n"
	        "I need at least %d bytes for the INT 2D handler.\n", residentsize);
	    return 1;
	}

    /* Get first free multiplex ID */
    status = CheckIfInstalled(&my_id, &residentSeg);
    if(status == 1)    
    {
        printf("ERROR: eatUMBS is already installed\n");
        return 1;
    } else if(status != 0) {
        printf("ERROR: no multiplex id available\n");
        return 1;    
    }
    MPlex = my_id;
    residentSeg = AllocMemory(size, 0x40);
    if(residentSeg == 0) {
        printf("ERROR: cannot allocate memory\n");
        return 1;
    }
    // printf("%d bytes of memory allocated at %04x\n", size, residentSeg);

    /* Save existing INT 2D handler */
    OldInt2D = _dos_getvect(0x2d);
    orig2d = OldInt2D;
    // printf("Old INT 2D handler at %04x:%04x\n", FP_SEG(orig2d), FP_OFF(orig2d));

    /* Copy data to upper memory block */
	residentsize = FP_OFF(END_int2d_handler);
    						/* copy resident code and data up into (high) memory */
	_fmemcpy(MK_FP(residentSeg, 0),
		MK_FP(FP_SEG(int2d_handler),0),
		residentsize);    

    /* Install new INT 2D handler */
	r.x.ax  = 0x252d;                        /* dosSetVect */
	r.x.dx  = FP_OFF(int2d_handler);
	sregs.ds   = residentSeg;
	int86x(0x21,&r,&r,&sregs);
	// printf("INT 2D installed at %04x:%04x with ID %d\n", sregs.ds, r.x.dx, my_id);
    
    return 0;
}
