all:    prn2file.exe

prn2file.exe: prn2file.obj
        tlink /v prn2file

prn2file.obj: prn2file.asm
        tasm /zi prn2file

clean:
        @del *.obj
        @del *.map

