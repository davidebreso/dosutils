all:    prn2file.exe

!ifdef EBUG
LDFLAGS=/v
ASFLAGS=/zi
!endif

prn2file.exe: prn2file.obj
        tlink $(LDFLAGS) prn2file

prn2file.obj: prn2file.asm
        tasm $(ASFLAGS) prn2file

clean:
        @del *.obj
        @del *.map

