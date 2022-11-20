/*
 * Simple MCB walker
 */
#include <dos.h>
#include <stdio.h>
#include <conio.h>
#include <string.h>

#pragma pack(1)

typedef unsigned char 	uint8_t;
typedef unsigned int	uint16_t;

typedef struct MCB
{
	uint8_t   	type;    	// 5Ah if last block in chain, otherwise 4Dh
	uint16_t	owner;      // PSP segment of owner or special flag value
	uint16_t	size;       // size of memory block in paragraphs
	uint8_t		unused[3];  // unused by MS-DOS
	char    	name[8];    // ASCII program name if PSP memory block or
							// DR DOS UMB, else garbage.
							// null-terminated if less than 8 characters
};

void print_mcb(struct MCB far *mcb)
{
	char name[9];
	unsigned long size = mcb->size * 16 + 16;
	struct MCB far *owner;

	printf("  Type: '%c'  Owner %04Xh  Size %lu bytes",
			mcb->type, mcb->owner, size);
	if(mcb->owner == 0x0008)
	{
		printf("  belongs to DOS");
	}
	else if (mcb->owner == FP_SEG(mcb) + 1)
	{
		_fstrncpy(name, mcb->name, 8);
		name[8] = 0;
		printf("  Name %s", name);
	}
	else if(mcb->owner == 0)
	{
		printf("  free");
	}
	else
	{
		owner = MK_FP(mcb->owner - 1, 0);
		if(owner->type == 'M' || owner->type == 'Z')
		{
			_fstrncpy(name, owner->name, 8);
			name[8] = 0;
			printf("  data of %s", name);
		} else {
			printf("  incorrect owner!");
		}
	}
}

int main()
{
	union REGS r;
	struct SREGS sr;
	uint16_t far *sysvars;
	uint16_t mcb_seg;
	struct MCB far *curr;
	uint16_t save_strategy;
	int count;

	/*
	 * Set link strategy to include UMBs
	 */
	r.x.ax = 0x5802;		// Get UMB link state
	int86(0x21, &r, &r);
	save_strategy = r.h.al;
	printf("Current link strategy is %u\n", save_strategy);

	r.x.ax = 0x5803;	// Set UMB link state
	r.x.bx = 1;			// 0 = no UMB link, 1 = UMB link
	int86(0x21, &r, &r);

	/*
	 * Get segment of first MCB from DOS list of lists
	 */
	r.x.ax = 0x5200;    /* Int 21/AH=52h - SYSVARS - GET LIST OF LISTS */
	int86x(0x21, &r, &r, &sr);
	sysvars = MK_FP(sr.es, r.x.bx);     // ES:BX -> DOS list of lists
										// segment of first memory control block
										// is at offset -2 (-1 words)
	mcb_seg = *(sysvars - 1);

	printf("Size of MCB is %d bytes\n", sizeof(struct MCB));
	printf("First MCB at segment %04Xh\n", mcb_seg);
	curr = MK_FP(mcb_seg, 0);
	print_mcb(curr);

	/*
	 * Walk the MCB list.
	 * The next MCB start immediately after the current one,
	 * that is, at segment mcb_seg + size + 1
	 * Valid MCBs have type 'M'. The last one has type 'Z'
	 */
	for(count = 2; curr->type == 0x4D; count++)
	{
		if(count > 11)
		{
			printf("\n.... press a key to continue ...");
			getch();
			count = 0;
		}
		mcb_seg = mcb_seg + curr->size + 1;
		printf("\nNext MCB at segment %04Xh\n", mcb_seg);
		curr = MK_FP(mcb_seg, 0);
		print_mcb(curr);
	}
	printf("\n");

	/*
	 * Restore saved link strategy
	 */
	r.x.ax = 0x5803;		// Set UMB link state
	r.x.bx = save_strategy;
	int86(0x21, &r, &r);

	return 0;
}
