#!/usr/bin/env python3
"""Dump C++ vtables from kexts and compare their slot layout.

Handles two pointer formats:
  * classic kext relocations (Big Sur 11.0 standalone kexts, e.g. the TGL driver)
  * chained kernel-collection pointers (kexts extracted from a Tahoe KC with `ipsw kernel extract`)

Usage:
  vtables.py dump  BIN CLASS [--kc SYSKC_KEXT... --boot BOOTKC_KEXT...]
  vtables.py diff  TGL_BIN TAHOE_BIN PARENT_CLASS --boot BOOTKC_KEXT... [--sys SYSKC_KEXT...]
  vtables.py scan  TGL_BIN TAHOE_BIN --boot BOOTKC_KEXT...   (every TAHOE_BIN class TGL subclasses)
"""
import struct, subprocess, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import macho

# Chained KC pointers to the boot KC are offsets from this base (calibrated on
# 26.7.1: OSObject::release(int) at offset 0x91c520 = 0xffffff8000a1c520).
BOOT_KC_BASE = 0xffffff8000100000


def symbols(path):
    """addr -> name for every defined symbol (local and external)."""
    out = subprocess.run(['nm', '-n', '--defined-only', path], capture_output=True, text=True).stdout
    m = {}
    for line in out.splitlines():
        parts = line.split()
        if len(parts) == 3:
            m.setdefault(int(parts[0], 16), parts[2])
    return m


def demangle(names):
    out = subprocess.run(['c++filt'], input='\n'.join(names), capture_output=True, text=True).stdout
    return out.splitlines()


def read_q(info, addr):
    for seg, sect, a, size, foff in info['sections']:
        if a <= addr < a + size and sect not in ('__bss', '__common'):
            return struct.unpack_from('<Q', info['data'], foff + addr - a)[0]
    return None


def vtable_span(syms, name):
    addrs = sorted(syms)
    start = next(a for a, n in syms.items() if n == name)
    nxt = next((a for a in addrs if a > start), start + 8 * 400)
    return start, (nxt - start) // 8


class Image:
    def __init__(self, path, boot=(), sysk=()):
        self.path = path
        self.info = macho.parse(path)
        self.syms = symbols(path)
        self.extrel = {}
        self.chained = self._is_kc()
        if self.chained:
            self.boot = {}
            for p in boot:
                self.boot.update(symbols(p))
            self.sys = dict(self.syms)
            for p in sysk:
                self.sys.update(symbols(p))
        else:
            self._load_relocs()

    def _is_kc(self):
        # KC-extracted kexts have absolute VM addresses far above 0
        return min(s[2] for s in self.info['sections']) >= 0x1000000

    def _load_relocs(self):
        d = self.info['data']
        off = 32
        ncmds = struct.unpack_from('<I', d, 16)[0]
        symoff = stroff = 0
        for _ in range(ncmds):
            cmd, size = struct.unpack_from('<II', d, off)
            if cmd == 0x2:
                symoff, nsyms, stroff, strsize = struct.unpack_from('<IIII', d, off + 8)
            elif cmd == 0xB:  # LC_DYSYMTAB
                f = struct.unpack_from('<18I', d, off + 8)
                extreloff, nextrel = f[14], f[15]
            off += size
        # symbol table index -> name
        sym = lambda idx: d[stroff + struct.unpack_from('<I', d, symoff + idx * 16)[0]:].split(b'\0')[0].decode()
        for i in range(nextrel):
            r_addr, info = struct.unpack_from('<iI', d, extreloff + i * 8)
            symnum, extern = info & 0xFFFFFF, (info >> 27) & 1
            if extern:
                self.extrel[r_addr] = sym(symnum)

    def slot(self, addr):
        if self.chained:
            v = read_q(self.info, addr)
            if not v:
                return None
            target, level = v & 0x3FFFFFFF, (v >> 30) & 3
            if level == 0:
                return self.boot.get(BOOT_KC_BASE + target, f'boot+{target:#x}')
            return self.sys.get(target, f'sys+{target:#x}')
        if addr in self.extrel:
            return self.extrel[addr]
        v = read_q(self.info, addr)
        if not v:
            return None
        return self.syms.get(v, f'local+{v:#x}')

    def vtable(self, cls):
        mangled = f'__ZTV{len(cls)}{cls}'
        start, n = vtable_span(self.syms, mangled)
        slots = [self.slot(start + 8 * k) for k in range(2, n)]
        while slots and slots[-1] is None:
            slots.pop()
        return slots

    def subclasses_of(self, parent):
        """Vtables in this image that reference PARENT's methods (direct or indirect subclasses)."""
        # an inherited slot is a method *of* PARENT, not just one taking a PARENT* argument
        tags = (f'__ZN{len(parent)}{parent}', f'__ZNK{len(parent)}{parent}')
        res = []
        for name in sorted(set(self.syms.values())):
            if name.startswith('__ZTV'):
                cls = name[5:].lstrip('0123456789')
                try:
                    vt = self.vtable(cls)
                except StopIteration:
                    continue
                if any(s and s.startswith(tags) for s in vt):
                    res.append(cls)
        return res


def method(name):
    """Demangled 'Class::method(args)' -> 'method(args)', so overrides compare equal."""
    if name is None:
        return '<null>'
    if '::~' in name:
        return '~'
    if '::' not in name:
        return name
    head, _, rest = name.partition('(')
    return head.rsplit('::', 1)[-1] + ('(' + rest if rest else '')


def cmp_parent(tgl, tahoe, parent, quiet=False):
    tv = tahoe.vtable(parent)
    tv_d = demangle([s or '<null>' for s in tv])
    subs = tgl.subclasses_of(parent)
    if not quiet:
        print(f'Tahoe {parent}: {len(tv)} slots')
        print(f'TGL subclasses referencing {parent}: {", ".join(subs)}')
    for sub in subs:
        sv = tgl.vtable(sub)
        sv_d = demangle([s or '<null>' for s in sv])
        # a pure virtual in Tahoe that TGL implements is an override, not a mismatch
        mism = [k for k in range(min(len(tv), len(sv)))
                if method(tv_d[k]) != method(sv_d[k]) and tv_d[k] != '___cxa_pure_virtual']
        if quiet and not mism:
            print(f'ok   {parent:34s} {len(tv):4d} slots  <- {sub} ({len(sv)})')
            continue
        print(f'\n== {sub}: {len(sv)} slots, parent slots compared {min(len(tv), len(sv))}, mismatches {len(mism)}')
        for k in mism[:40]:
            print(f'  [{k:3d}] tahoe {tv_d[k]}\n        tgl   {sv_d[k]}')
        if len(mism) > 40:
            print(f'  ... {len(mism) - 40} more')


def args(argv):
    pos, opts, cur = [], {'--boot': [], '--sys': []}, None
    for a in argv:
        if a in opts:
            cur = a
        elif cur:
            opts[cur].append(a)
        else:
            pos.append(a)
    return pos, opts


if __name__ == '__main__':
    pos, opts = args(sys.argv[1:])
    if pos[0] == 'dump':
        img = Image(pos[1], opts['--boot'], opts['--sys'])
        vt = img.vtable(pos[2])
        for k, n in enumerate(demangle([s or '<null>' for s in vt])):
            print(f'[{k:3d}] {n}')
    elif pos[0] == 'diff':
        tgl = Image(pos[1])
        tahoe = Image(pos[2], opts['--boot'], opts['--sys'])
        cmp_parent(tgl, tahoe, pos[3])
    elif pos[0] == 'scan':
        tgl = Image(pos[1])
        tahoe = Image(pos[2], opts['--boot'], opts['--sys'])
        for name in sorted(set(tahoe.syms.values())):
            if name.startswith('__ZTV') and not name.endswith('MetaClassE'):
                cls = name[5:].lstrip('0123456789')
                if tgl.subclasses_of(cls):
                    cmp_parent(tgl, tahoe, cls, quiet=True)
