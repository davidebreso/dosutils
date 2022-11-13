all: eatumbs.exe

# Utility TSR to reserve UMB memory
eatumbs.exe: eatumbs.c eatumbsr.asm
	wcl eatumbs.c eatumbsr.asm -fm=eatumbs

# Create zipfile for release
release: eatumbs.exe .SYMBOLIC
	rm -f eatumbs.zip
	zip -j eatumbs.zip *.exe *.txt ../LICENSE

# cleanup
clean
	rm -f *.o
	rm -f *.lib
	rm -f *.bak
	rm -f *.map
	rm -f *.lst
	rm -f *.err
	
distclean: clean .SYMBOLIC
	rm -f *.exe
	rm -f *.zip
    
