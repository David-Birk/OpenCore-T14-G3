#!/usr/bin/env python3
"""Switch an OpenCore config.plist from iGPU-disabled to the WhateverXe display test.

Shows the changes by default; --write applies them and keeps CONFIG.bak-xe.
--revert restores the iGPU-disabled state (-igfxvesa, WhateverXe disabled).

Changes:
  Kernel > Add   WhateverXe.kext right after Lilu (enabled)
  boot-args      drop -igfxvesa; add -allow3d -disablegfxfirmware -wexbeta -wexdbg
  iGPU props     drop the Ice Lake leftovers (AAPL,ig-platform-id, framebuffer-unifiedmem);
                 cap the display pool at 60 MB for the fixed 64 MB DVMT
                 (framebuffer-patch-enable 1, framebuffer-stolenmem 0x03C00000)

WhateverXe.kext itself must be copied to EFI/OC/Kexts separately.
Usage: apply-xe-config.py CONFIG.plist [--write | --revert]
"""
import plistlib, shutil, sys

NVRAM = '7C436110-AB2A-4BBB-A880-FE41995C9F82'
IGPU = 'PciRoot(0x0)/Pci(0x2,0x0)'
ADD_ARGS = ['-allow3d', '-disablegfxfirmware', '-wexbeta', '-wexdbg']
DROP_PROPS = ['AAPL,ig-platform-id', 'framebuffer-unifiedmem']
SET_PROPS = {'framebuffer-patch-enable': bytes.fromhex('01000000'),
             'framebuffer-stolenmem': bytes.fromhex('0000C003')}
KEXT = {'Arch': 'x86_64', 'BundlePath': 'WhateverXe.kext', 'Comment': 'WhateverXe (tahoe)',
        'Enabled': True, 'ExecutablePath': 'Contents/MacOS/WhateverXe', 'MaxKernel': '',
        'MinKernel': '', 'PlistPath': 'Contents/Info.plist'}


def apply(c, revert):
    log = []
    adds = c['Kernel']['Add']
    entry = next((k for k in adds if k['BundlePath'] == 'WhateverXe.kext'), None)
    if revert:
        if entry and entry['Enabled']:
            entry['Enabled'] = False
            log.append('Kernel>Add: WhateverXe.kext disabled')
    elif entry is None:
        lilu = next(i for i, k in enumerate(adds) if k['BundlePath'] == 'Lilu.kext')
        adds.insert(lilu + 1, dict(KEXT))
        log.append('Kernel>Add: + WhateverXe.kext (after Lilu)')
    elif not entry['Enabled']:
        entry['Enabled'] = True
        log.append('Kernel>Add: WhateverXe.kext enabled')

    nv = c['NVRAM']['Add'][NVRAM]
    old = nv['boot-args'].split()
    if revert:
        new = [a for a in old if a not in ADD_ARGS] + ([] if '-igfxvesa' in old else ['-igfxvesa'])
    else:
        new = [a for a in old if a != '-igfxvesa'] + [a for a in ADD_ARGS if a not in old]
    if new != old:
        nv['boot-args'] = ' '.join(new)
        log.append(f'boot-args: {" ".join(old)}\n        -> {" ".join(new)}')

    props = c['DeviceProperties']['Add'].setdefault(IGPU, {})
    if not revert:
        for k in DROP_PROPS:
            if k in props:
                log.append(f'{IGPU}: - {k} = {props.pop(k).hex()}')
        for k, v in SET_PROPS.items():
            if props.get(k) != v:
                log.append(f'{IGPU}: {k} = {v.hex()}')
                props[k] = v
    return log


def main(path, mode=None):
    c = plistlib.load(open(path, 'rb'))
    log = apply(c, mode == '--revert')
    print('\n'.join(log) or 'no changes')
    if mode in ('--write', '--revert') and log:
        shutil.copy2(path, path + '.bak-xe')
        with open(path, 'wb') as f:
            plistlib.dump(c, f)
        print(f'written; backup at {path}.bak-xe')


if __name__ == '__main__':
    main(*sys.argv[1:3])
