JACPATCH This patch fixes the color EGA driver that comes with Windows 3.0 to make it run on a 8088/8086.
EGA.DRV
; File size
71344
; Modified segment table to include extra bytes inserted at the end of CSEG 1
0442
03
15
0446
03
15
; Replaced SHR DX, 3 at CodeSegment1:09CA with a call to end of segment
152A
C1 EA 03
E8 36 22
; Patched CALL 153E at CSEG1:0A6C with a call to end of segment.
15CC
E8 CF 0A
E8 A0 21
; Fixed the code at CSEG1:16EF--1702 of function starting at CSEG 1:153E 
; that generated code with ROR AL, n and ROL AL, n
2250
C0 C0
D0 C0
225E
AB 8A C1 AA
F3 AB 8A CE
; Replaced SHR BX, 2 at CodeSegment1:172F with a call to end of segment
228F
C1 EB 02
E8 D8 14
; Added expansion of SHR, ROL at end of segment 
; Added CLI and STI around the CALL to 153E
3760
0000C309 000300D0 2A0100FA 07030043 21010035 23030164 0A0200B1 00030032 
0000C3D1 EAD1EAD1 EAC3D1EB D1EBC3FA E82BE9FB C3090003 00D02A01 00FA0703
3780
1B0100C5 14030008 1AFF005A 00030003 1AFF005B 000301FE 2B010064 00050159 
00432101 00352303 01640A02 00B10003 00321B01 00C51403 00081AFF 005A0003
37A0
1B0200AE 000501E0 260200B2 00000000 00000000 00000000 00000000 00000000
00031AFF 005B0003 01FE2B01 00640005 01591B02 00AE0005 01E02602 00B20000
