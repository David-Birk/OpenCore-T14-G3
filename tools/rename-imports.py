#!/usr/bin/env python3
"""Rename imported symbols of a kext so it links against Tahoe's IOAcceleratorFamily2.

The TGL 11.0 accelerator imports 5 symbols that Tahoe renamed (same vtable slot,
see docs/TAHOE-PORT.md). New names are appended to the string table and the
symbol entries repointed; code, data and every file offset before the string
table stay untouched, so WhateverXe's offset-based patches keep working.

The input must be unsigned (`codesign --remove-signature`) so the string table
is the last thing in the file. Re-sign the kext bundle afterwards.

Usage: rename-imports.py IN OUT
"""
import struct, sys

TGL_TO_TAHOE = {
    '__ZN16IOAccelMemoryMap26_RESERVEDIOAccelMemoryMap0Ev':
        '__ZNK16IOAccelMemoryMap34getAssignedGPUVirtualAddressLengthEv',
    '__ZN16IOAccelResource225_RESERVEDIOAccelResource0Ev':
        '__ZN16IOAccelResource216dirtyBufferRangeEyy',
    '__ZN16IOAccelResource225_RESERVEDIOAccelResource1Ev':
        '__ZN16IOAccelResource218dirtyVendorCommandEjy',
    '__ZN16IOAccelResource217initSurfaceBufferEP20IOAccelLegacySurfacejjjjj':
        '__ZN16IOAccelResource217initSurfaceBufferEP14IOAccelSurfacejjjjj',
    '__ZN22IOGraphicsAccelerator214createDrawableEP20IOAccelLegacySurfaceP14IOAccelShared2b':
        '__ZN22IOGraphicsAccelerator214createDrawableEP14IOAccelSurfaceP14IOAccelShared2b',
}

LC_SEGMENT_64, LC_SYMTAB, LC_CODE_SIGNATURE = 0x19, 0x2, 0x1D


def main(src, dst):
    d = bytearray(open(src, 'rb').read())
    magic, _, _, _, ncmds = struct.unpack_from('<IiiII', d)
    if magic != 0xFEEDFACF:
        sys.exit('not a thin x86_64 Mach-O')
    off, symtab, linkedit = 32, None, None
    for _ in range(ncmds):
        cmd, size = struct.unpack_from('<II', d, off)
        if cmd == LC_CODE_SIGNATURE:
            sys.exit('signed binary: run `codesign --remove-signature` first')
        if cmd == LC_SYMTAB:
            symtab = off
        if cmd == LC_SEGMENT_64 and d[off + 8:off + 24].rstrip(b'\0') == b'__LINKEDIT':
            linkedit = off
        off += size
    symoff, nsyms, stroff, strsize = struct.unpack_from('<IIII', d, symtab + 8)
    if stroff + strsize != len(d):
        sys.exit('string table is not at the end of the file')

    strtab = bytes(d[stroff:stroff + strsize])
    todo = dict(TGL_TO_TAHOE)
    for i in range(nsyms):
        e = symoff + i * 16
        strx = struct.unpack_from('<I', d, e)[0]
        name = strtab[strx:strtab.index(b'\0', strx)].decode()
        if name in todo:
            new = todo.pop(name)
            struct.pack_into('<I', d, e, len(d) - stroff)
            d += new.encode() + b'\0'
            print(f'renamed {name}\n     -> {new}')
    if todo:
        sys.exit(f'not found: {sorted(todo)}')

    while len(d) % 8:
        d += b'\0'
    struct.pack_into('<I', d, symtab + 20, len(d) - stroff)
    fileoff = struct.unpack_from('<Q', d, linkedit + 40)[0]
    filesize = len(d) - fileoff
    struct.pack_into('<Q', d, linkedit + 48, filesize)  # filesize
    struct.pack_into('<Q', d, linkedit + 32, max(struct.unpack_from('<Q', d, linkedit + 32)[0],
                                                 (filesize + 0xFFF) & ~0xFFF))  # vmsize
    open(dst, 'wb').write(d)


if __name__ == '__main__':
    main(*sys.argv[1:3])
