#
#   fixbios.py
#
#   A python script to patch Olivetti PCS-86 BIOS Version 1.13
#

# 
#   module imports
import argparse
import sys
import os
from hashlib import md5


#
# Helper function to compute BIOS checksum
#
def get_bios_checksum(data):
    chksum = 0
    for i in range(len(data) - 1):
        chksum = (chksum + data[i]) & 0xFF
    return (0x100 - chksum) & 0xFF

def patch(data, offset, old, new):
    endpos = offset + len(old)
    if(data[offset:endpos] == old):
        data[offset:endpos] = new
    else:
        print("Data at offset", hex(offset), "do not match! Expected", old.hex(' '), "found", data[offset:endpos].hex(' '))
        sys.exit(1)
        

##################### MAIN #######################
parser = argparse.ArgumentParser()
parser.add_argument("infile", type=str, nargs='?',
                    help="Load system ROM bios from INFILE (default: sys_rom.bin).",
                    default="sys_rom.bin")
parser.add_argument("-o", "--outfile", type=str,
                    help="Save patched BIOS to OUTFILE (default: sys_rom_patched.bin).",
                    default="sys_rom_patched.bin")
parser.add_argument("-k", "--keyboard-patch", help="Apply keyboard patch.",
                    action="store_true")
parser.add_argument("-s", "--system-descriptor-patch", help="Apply system descriptor patch.",
                    action="store_true")
parser.add_argument("-x", "--xtide-bios", type=str, nargs='?',
                    help="Add XTIDE Universal BIOS option ROM (default: ide_xtp.bin).",
                    const="ide_xtp.bin", default=None)
args = parser.parse_args()

infile = args.infile
outfile = args.outfile
xubfile = args.xtide_bios

# Correct md5 of 1.13 BIOS dump goes here
md5_expected = '651e39f2e4add4a913d24446df6620fe'
anypatch = False

print("Reading system BIOS from", infile)
# Open,close, read file and calculate MD5 on system BIOS 
try:
    with open(infile, 'rb') as file_to_check:
        # read contents of the file
        data = bytearray(file_to_check.read())
        # pipe contents of the file through
        md5_returned = md5(data).hexdigest()
except:
    print("Error while reading", infile)
    sys.exit(1)
        
# Compare expected MD5 with freshly calculated
if md5_expected == md5_returned:
    print("MD5 verified.")
else:
    print("MD5 verification failed!.")
    sys.exit(1)

if args.keyboard_patch:
    # Apply keyboard fix patch:
    #   - at offset 0x1E13, change B4 F5 -> EB 04
    #   - at offset 0x1E2C, change B9 05 00 -> EB 10 90
    print("Applying keyboard patch.")
    patch(data, 0x1E13, bytes.fromhex('B4 F5'), bytes.fromhex('EB 04'))
    patch(data, 0x1E2C, bytes.fromhex('B9 05 00'), bytes.fromhex('EB 10 90'))
    anypatch = True

if args.system_descriptor_patch:
    print("Applying system descriptor patch.")
    patch(data, 0x2FD7, bytes.fromhex('90'), bytes.fromhex('94'))
    anypatch = True

if xubfile != None:
    print("Appling XUB integration patch.")
    xub_size = os.path.getsize(xubfile)
    if xub_size != 8*1024:
        print("Incorrect XUB file size: BIOS image must be 8K in size.")
        sys.exit(1)
    try:
        with open(xubfile, 'rb') as file_to_read:
            xubdata = file_to_read.read()
    except:
        print("Error while reading", xubfile)
        sys.exit(1)
        
    if xubdata[0:2] != b'\x55\xAA':
        print("Missing 55 AA signature in XUB image file.")
        sys.exit(1)
    xub_check = get_bios_checksum(xubdata)
    if xubdata[-1] != xub_check:
        print("Wrong checksum in XUB image file. Expected", xub_check, "found", xubdata[-1])
        sys.exit(1)
    # Replace instruction OR AL, 1 at offset 0x841 with AND AL, 0xFE to diable XTA controller
    patch(data, 0x0841, bytes.fromhex('0C 01'), bytes.fromhex('24 FE'))
    # replace MOV al, ds:75h at offset 0x851 with MOV al, 01 to return 1 HDD present
    patch(data, 0x851, bytes.fromhex('A0 75 00'), bytes.fromhex('B0 01 90'))
    # patch function check_hdd at offset 0x9F60
    patch(data, 0x9f60, 
          bytes.fromhex('33C08ED8 8EC0E8DD 04B84000 8ED8C606 740000C6 06750000'),
          bytes.fromhex('50531E06 EB00E421 509A0300 00FC58E6 21071F5B 58C30000'))
    # Insert XUB image at offset 0xC000
    data[0xC000:0xE000] = xubdata
    anypatch = True

if anypatch:
    chksum = get_bios_checksum(data)
    print("Calculated new BIOS checksum:", hex(chksum))
    data[-1] = chksum

    print("Saving patched BIOS at", outfile)
    try:
        with open(outfile, 'wb') as file_to_write:
            file_to_write.write(data)
    except:
        print("Error while writing", outfile)
        sys.exit(1)

sys.exit(0)
