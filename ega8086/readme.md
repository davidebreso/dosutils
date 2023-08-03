# EGA-on-8086

This is a patch for the color EGA driver that comes with Windows 3.0. The original driver contains a few 80186+ instructions that do not allow it to run on regular 8088/8086 CPU. The patch replaces such instructions and allow any XT computer with an EGA card to run Windows 3.0 at 640x350 resolution and 16 colors.

# INSTALLATION

Use the SETUP.EXE in the windows directory to install the regular EGA
driver. Once that's completed, put EGA8086.EXE into WINDOWS\SYSTEM and
run it. The executable applies the patch to EGA.DRV and then exit.
You can delete EGA8086.EXE once the patch is successfully applied,
since it is not needed to run Windows.

# HISTORY

A similar issue affects also the color VGA driver: a patched version of
the driver has been available thanks to the work of Montecarlo4tony at
VCFED

https://forum.vcfed.org/index.php?threads/windows-3-0-vga-color-driver-
for-8088-xt.35866

The EGA and VGA color drivers share most of the code, and thus the EGA
driver can be patched in the very same way as Tony did on the VGA
driver, with only a small difference in the offsets of the changes.

# PATCH DETAILS

- Replaced SHR DX, 3 at CodeSegment1:09CA with a call to end of segment
  and subsequent expansion. 
- Replaced SHR BX, 2 at CodeSegment1:172F with a call to end of segment. 
- Fixed the code at CSEG1:16EF--1702 of function starting at CSEG 1:153E 
  that generated code with ROR AL, n and ROL AL, n 
- Patched CALL 153E at CSEG1:0A6C with a call to end of segment. 
- Added CLI and STI around the CALL to 153E, to keep the stack compiler from 
  being interrupted. 
- Modified segment table to include extra bytes inserted at the end of CSEG 1.

# BUILD INSTRUCTIONS

The executable is generated with [jacpatch](https://github.com/jcross/jacpatch),
a  tool for making stand-alone binary patch programs created by @jcross.

To build your own executable, clone the [jacpatch](https://github.com/jcross/jacpatch) repository, put the 
`ega8086.jac` file in `patches/` and then run `make`.

