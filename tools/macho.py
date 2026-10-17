#!/usr/bin/env python3
"""Minimal Mach-O reader: load commands, linked dylibs, undefined/defined symbols, sections."""
import struct, sys

LC_SEGMENT_64, LC_SYMTAB, LC_LOAD_DYLIB, LC_ID_DYLIB, LC_LOAD_WEAK_DYLIB, LC_REEXPORT_DYLIB = 0x19, 0x2, 0xC, 0xD, 0x80000018, 0x8000001F
LC_UUID, LC_BUILD_VERSION, LC_VERSION_MIN_MACOSX = 0x1B, 0x32, 0x24


def thin(data):
    magic = struct.unpack_from('>I', data)[0]
    if magic in (0xCAFEBABE, 0xCAFEBABF):
        n = struct.unpack_from('>I', data, 4)[0]
        wide = magic == 0xCAFEBABF
        for i in range(n):
            if wide:
                cpu, _, off, size = struct.unpack_from('>IIQQ', data, 8 + i * 32)[:4]
            else:
                cpu, _, off, size = struct.unpack_from('>IIII', data, 8 + i * 20)[:4]
            if cpu == 0x01000007:  # x86_64
                return data[off:off + size]
        raise SystemExit('no x86_64 slice')
    return data


def parse(path):
    d = thin(open(path, 'rb').read())
    magic, cpu, sub, ftype, ncmds, sizecmds, flags, _ = struct.unpack_from('<IiiIIIII', d)
    assert magic == 0xFEEDFACF, hex(magic)
    info = {'type': ftype, 'dylibs': [], 'sections': [], 'undef': set(), 'defined': set(), 'version': None}
    off = 32
    for _ in range(ncmds):
        cmd, size = struct.unpack_from('<II', d, off)
        if cmd in (LC_LOAD_DYLIB, LC_LOAD_WEAK_DYLIB, LC_REEXPORT_DYLIB, LC_ID_DYLIB):
            name_off = struct.unpack_from('<I', d, off + 8)[0]
            name = d[off + name_off:off + size].split(b'\0')[0].decode()
            kind = {LC_LOAD_DYLIB: 'load', LC_LOAD_WEAK_DYLIB: 'weak', LC_REEXPORT_DYLIB: 'reexport', LC_ID_DYLIB: 'id'}[cmd]
            info['dylibs'].append((kind, name))
        elif cmd == LC_SEGMENT_64:
            nsects = struct.unpack_from('<I', d, off + 64)[0]
            for s in range(nsects):
                so = off + 72 + s * 80
                sect = d[so:so + 16].split(b'\0')[0].decode()
                seg = d[so + 16:so + 32].split(b'\0')[0].decode()
                addr, size_, foff = struct.unpack_from('<QQI', d, so + 32)
                info['sections'].append((seg, sect, addr, size_, foff))
        elif cmd == LC_BUILD_VERSION:
            platform, minos, sdk = struct.unpack_from('<III', d, off + 8)
            info['version'] = ('build', platform, ver(minos), ver(sdk))
        elif cmd == LC_VERSION_MIN_MACOSX:
            minos, sdk = struct.unpack_from('<II', d, off + 8)
            info['version'] = ('min', 1, ver(minos), ver(sdk))
        elif cmd == LC_SYMTAB:
            symoff, nsyms, stroff, strsize = struct.unpack_from('<IIII', d, off + 8)
            for i in range(nsyms):
                strx, ntype, nsect, desc, value = struct.unpack_from('<IBBhQ', d, symoff + i * 16)
                if ntype & 0xE0:  # stab
                    continue
                name = d[stroff + strx:d.index(b'\0', stroff + strx)].decode(errors='replace')
                if (ntype & 0x0E) == 0 and (ntype & 1):
                    info['undef'].add(name)
                elif ntype & 1:
                    info['defined'].add(name)
        off += size
    info['data'] = d
    return info


def ver(v):
    return f'{v >> 16}.{(v >> 8) & 0xFF}.{v & 0xFF}'


if __name__ == '__main__':
    for path in sys.argv[1:]:
        i = parse(path)
        print(f'== {path}\n  type={i["type"]} version={i["version"]} undef={len(i["undef"])} defined={len(i["defined"])}')
        for kind, name in i['dylibs']:
            print(f'  {kind:8s} {name}')
