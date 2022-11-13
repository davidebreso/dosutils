all: eatumbs.exe

# Utility TSR to reserve UMB memory
eatumbs.exe: eatumbs.c eatumbsr.asm
	wcl eatumbs.c eatumbsr.asm -fm=eatumbs

# cleanup
clean
	rm -f *.o
	rm -f *.lib
	rm -f *.bak
	rm -f *.map
	rm -f *.lst
	rm -f *.err
	rm -f *.exe
