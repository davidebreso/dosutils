
TASM=tasm.exe
TLINK=tlink.exe
ZIP=pkzip

INSTALLDIR=C:\DRIVERS
ZIPFILE=wdemm.zip

all: wdemm.exe fixemm.exe

#
# Expanded Memory Manager
#
wdemm.exe: wdemm.obj
	$(TLINK) wdemm

wdemm.obj: wdemm.asm wdemm.inc wdemm.mac
    $(TASM) wdemm.asm

#
# FixEMM
#
fixemm.exe: fixemm.obj
	$(TLINK) fixemm

fixemm.obj: fixemm.asm
    $(TASM) fixemm.asm

# ############## generic ##########################
#
# cleanup
#
clean:
	del  *.obj
	del  *.bak
	del  *.map
    del  *.err
#
# install
#
install: wdemm.exe fixemm.exe
    xcopy /y wdemm.exe $(INSTALLDIR)
    xcopy /y fixemm.exe $(INSTALLDIR)

# ############## end generic ##########################

