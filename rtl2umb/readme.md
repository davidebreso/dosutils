## RTL2UMB.EXE

### Zero-resident enabler to use memory on an RTL8019AS-based ethernet card as upper memory.

The RTL8019AS ethernet ASIC includes support for writeable flash/eeprom memory devices in the boot ROM socket.
The signal to flash these devices is the same MEMW signal that RAM uses, so assuming the MEMW signal is
actually connected to the socket (this may vary depending on the PCB board used on your particular card)
this means it's possible to use a RAM chip in this socket as an upper memory block. However, there is
one catch: the setting to enable the ROM socket chip select is not "persistant"; it's not set based on
the configuration EEPROM contents, it needs to be specifically set "on", presumably by the program
used to flash new contents. Therefore you simply can't "set and forget it" for use as upper memory.

The RTL2UMB program uses the same "run from config.sys" EXE framework as the above to allow it to be loaded
from config.sys before a UMB provider program such as USE!UMBS.SYS. During execution the program stuffs
the necessary registers on the card to enable writes and exits. The program has been tested with a card
modified to "free" the MEMR and MEMW signals so they were connected to the bus signals instead of tied low
and up respectively, and works to provide a 64K upper memory block mapped according to the RTL's configuration
settings for the ROM socket base.

A possible limitation of this modification is DMA may not be supported to this RAM. This could cause
problems with floppy I/O if the DOS data area is loaded high. Per a discussion thread:

"I realized that moving the dos data segment in the UMB causes problem with floppy disks. DIR A: gets you garbage
and lots of disk fail errors. This happens with both DOSDATA=UMB (and no dosmax) and DOSMAX (and no dosdata), with
PC DOS 2000 and MS DOS 5 with a minimal configuration (floppy only, no hd nor XTIDE bios)... 

To have a working setup I must add /S+ to DOSMAX.SYS to keep the dos data segment in low memory and load only
the kernel high. This decreased free conventional to 619K, or 615K with the packet driver and etherdrv."

The RTL card only controls chip select to the ROM socket, not the MEMR/MEMW signals, so presumably the issue 
is the RTL gates itself on the AEN signal; this is common for port mapped devices but semi-erroneous to do
for memory devices.

It's unknown if this driver will work on other 8019 variants, it's only been tested on the 8019AS.
