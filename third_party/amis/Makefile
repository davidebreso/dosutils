######################################################################
#
# Makefile for the Alternate Multiplex Interrupt Specification library
#
# Public Domain 1992,1993 Ralf Brown
# Version 0.92
# Last Edit: 9/24/95
#
######################################################################

# the C compiler to invoke
CC = tcc
# memory model
MDL = c
# the flags to pass to the C compiler
CFLAGS = -m$(MDL)

# the linker to invoke
LINK = tlink
# the flags to pass to the linker
LFLAGS = /t /m

# the assembler to invoke
ASM = tasm
AMDL = __TINY__
AMDL_C = __COMPACT__
AFLAGS = /Mx

# the object library to invok
LIB = tlib
LIBFLAGS = /c/0

# default rule for making a .EXE from a C source file
.c.exe:
	$(CC) $(CFLAGS) $<

# default rule for making a .COM from an object module
.obj.com:
	$(LINK) $(LFLAGS) $<,,,amis$(MDL)

# default rule for making an object module from a C source file
.c.obj:
	$(CC) $(CFLAGS) -c $<

# default rule for making an object module from an assembler source file
.asm.obj:
	$(ASM) $(AFLAGS) /D$(AMDL) $*

all:  amitsrs.exe popup.exe remove.exe \
      fastmous.com nolpt.com switchar.com vgablank.com note.com rbkeyswp.com

amis.obj:	amis.asm amis.mac
amishotk.obj:	amishotk.asm amis.mac
amisutil.obj:	amisutil.asm amis.mac
amipopup.obj:	amipopup.asm amis.mac

amis$(MDL).lib:	amis.obj amishotk.obj amisutil.obj amipopup.obj
	del amis$(MDL).lib
	$(LIB) $(LIBFLAGS) amis$(MDL) +amis+amishotk+amipopup+amisutil

amitsrs.exe:	amitsrs.c
popup.exe:	popup.c findtsrs.obj
	$(CC) $(CFLAGS) popup.c findtsrs.obj
remove.exe:	remove.c findtsrs.obj uninstal.obj
	$(CC) $(CFLAGS) remove.c findtsrs.obj uninstal.obj

fastmous.com:	fastmous.obj amis$(MDL).lib
nolpt.com:	nolpt.obj amis$(MDL).lib
rbkeyswp.com:	rbkeyswp.obj amis$(MDL).lib
switchar.com:	switchar.obj amis$(MDL).lib
vgablank.com:	vgablank.obj amis$(MDL).lib
note.com:	note.obj amis$(MDL).lib

uninstal.obj:	uninstal.asm amis.mac
	$(ASM) $(AFLAGS) /D$(AMDL_C) uninstal.asm

findtsrs.obj:   findtsrs.c
fastmous.obj:	fastmous.asm amis.mac
nolpt.obj:	nolpt.asm amis.mac
note.obj:	note.asm amis.mac amipopup.mac
rbkeyswp.obj:	rbkeyswp.asm amis.mac
switchar.obj:	switchar.asm amis.mac
vgablank.obj:	vgablank.asm amis.mac
