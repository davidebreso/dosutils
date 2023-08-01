# Makefile to create RTL2UMB.EXE
# tools used:
# - GNU make
# - JWasm v2.12pre

# Macros for building, deleting ########################################

AS=jwasm
RM=rm -f

# Targets ##############################################################

all: rtl2umb.exe

rtl2umb.exe: rtl2umb.asm
	$(AS) -mz -Fo rtl2umb.exe rtl2umb.asm
	
# Clean up #############################################################

clean:
	$(RM) *.o
	$(RM) *.lib
	$(RM) *.bak
	$(RM) *.map
	$(RM) *.lst
	$(RM) *.err
	
distclean: clean
	$(RM) *.exe
	$(RM) *.zip

