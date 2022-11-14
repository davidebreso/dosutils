## RTL2UMB.EXE

### Zero-resident enabler to use memory on RTL8019AS-based ethernet cards

The program enables memory write operations for the RTL8019AS "flash ROM" chip and exits. With a SRAM chip placed in the socket
with the correct wiring this adds 16-64Kb UMB. No testing is performed; verify card works first. Set the size and position of the UMB with RSET8019.EXE

### Acknowledgments

Based on Astrowallaby's [ems2umb.asm](https://github.com/Astrowallaby/PaleozoicPC-stuff), originally based on skeleton code found on [pastebin.com](https://pastebin.com/w2Dh5SNZ).

ParseToken and HexToStr functions based on atoh2/hextoa functions from the [UCR Standard Library for 80x86 Assembly Language Programmers](https://www.plantation-productions.com/Webster/www.artofasm.com/DOS/index.html)
