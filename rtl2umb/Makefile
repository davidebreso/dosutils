all: rtl2umb.exe

# Utility TSR to reserve UMB memory
rtl2umb.exe: rtl2umb.o
	wlink system dos file rtl2umb.o option map
	
rtl2umb.o: rtl2umb.asm
	wasm rtl2umb.asm

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

