#!/usr/bin/env python3
"""Point the TGL Metal driver's IOKit import at Moraea's impostor.dylib (like OCLP's SKL 12.5-25).

The 20A2314a AppleIntelTGLGraphicsMTLDriver from PatcherSupportPkg carries a code
cave right after its load commands (0x10d0-0x1ee7, entered from the telemetry
initializer), so the load commands must not grow. install_name_tool would grow
them and overwrite the cave (SIGILL at load). This rewrites the path inside the
existing LC_LOAD_DYLIB, keeping cmdsize: the new path must fit the old slot
(63 characters for IOKit's 88-byte command).

Usage: patch-mtldriver.py IN OUT [NEW_PATH]
Re-sign afterwards (codesign -f -s -).
"""
import struct, sys

OLD = '/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit'
NEW = '/System/Library/Extensions/AppleIntelTGLImpostor.dylib'
LC_LOAD_DYLIB, LC_CODE_SIGNATURE = 0xC, 0x1D


def main(src, dst, new=NEW):
    d = bytearray(open(src, 'rb').read())
    magic, _, _, _, ncmds = struct.unpack_from('<IiiII', d)
    if magic != 0xFEEDFACF:
        sys.exit('not a thin x86_64 Mach-O')
    off, done = 32, False
    for _ in range(ncmds):
        cmd, size = struct.unpack_from('<II', d, off)
        if cmd == LC_LOAD_DYLIB:
            name_off = struct.unpack_from('<I', d, off + 8)[0]
            room = size - name_off
            if d[off + name_off:off + size].split(b'\0')[0].decode() == OLD:
                if len(new) + 1 > room:
                    sys.exit(f'{new} needs {len(new) + 1} bytes, slot has {room}')
                d[off + name_off:off + size] = new.encode().ljust(room, b'\0')
                done = True
        off += size
    if not done:
        sys.exit(f'{OLD} not imported')
    open(dst, 'wb').write(d)
    print(f'{OLD}\n  -> {new}')


if __name__ == '__main__':
    main(*sys.argv[1:4])
