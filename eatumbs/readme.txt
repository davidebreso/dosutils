eatUMBS
=======

eatUMBS is a small TSR that can be used to take up upper memory. You specify how
many bytes of memory to reserve in the upper memory area; eatUMBS reserves the
memory and then goes resident. When you're done, you can uninstall eatUMBS to
get back where you started from.

Usage
-----

Type 'eatumbs <numbytes>' to reserve <numbytes> bytes of the upper memory area.
The position of the reserved upper memory block is selected with a "first fit" strategy. When you're done, type 'eatumbs u' to release the memory.

License
-------

eatUMBS is (c) 2022 Davide Bresolin and is distributable under the terms of the MIT license. See the LICENSE file for more details.

