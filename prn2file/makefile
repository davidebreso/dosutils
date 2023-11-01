all:    prn2file.exe

prn2file.exe: prn2file.obj
        tlink prn2file

prn2file.obj: prn2file.asm
        tasm prn2file

clean:
        @del *.obj
        @del *.map

