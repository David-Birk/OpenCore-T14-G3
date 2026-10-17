# Iris Xe on Tahoe – porting analysis (2026-10-17)

Goal: run Apple's Tiger Lake driver (macOS 11.0 build 20A2314a) on **macOS Tahoe** and patch it onto Alder Lake-P (`46A8`) with WhateverXe ([branch `adl-p`](https://github.com/David-Birk/WhateverXe/tree/adl-p)).

## Precedent: OCLP already runs old Intel drivers on Tahoe

The OCLP fork (`intel_skylake.py`) installs the **Skylake drivers from macOS 12.5 (Monterey)** on Tahoe:

| Component | Version on Tahoe |
|---|---|
| `AppleIntelSKLGraphics.kext`, `…Framebuffer.kext` | `12.5-23.4` (patched for Sonoma 14.4+, otherwise unchanged) |
| `AppleIntelSKLGraphicsMTLDriver.bundle` | `12.5-25`: identical except **one load command**: `IOKit` → `impostor.dylib` |
| `impostor.dylib` (Moraea, no public source) | re-exports IOKit and uses ObjC swizzling to repair Metal.framework internals that changed in Tahoe: `descriptorPrivate` structs of `MTLRenderPipelineDescriptor`, `MTLComputePipelineDescriptor`, `MTLRenderPassDescriptor` and `MTLTextureDescriptor`, plus `-[MTLTextureDescriptor validateWithDevice:]` and `-[_MTLDevice supportsFamily:]`. It also has special cases for WindowServer, WebKit/ANGLE, Finder/Dock/Spotlight and Liquid Glass (`glassSetup`) |

**So an Intel driver that is 4 macOS versions older runs on Tahoe with a single userspace shim.** TGL is one more version back (11.0 instead of 12.5).

## Symbol comparison: TGL 11.0 vs. SKL 12.5 (runs on Tahoe)

Tool: `tools/macho.py` (own Mach-O parser). It compares the imported symbols.

### Metal driver (`…MTLDriver.bundle`) – ✅ no problem
- TGL imports 372 symbols; only 23 are not in SKL, all trivial (CoreFoundation, libc: `CFDictionaryCreate`, `strcpy`, …). They all exist in Tahoe.
- Same frameworks (Metal, IOAccelerator, IOSurface, MPS, GPURawCounter).
- → The SKL approach applies directly: patch the `IOKit` load command to `impostor.dylib`. Open question: does the impostor fix Big Sur 11.0 struct layouts, or only Monterey ones? (11.0 is built with SDK 10.16, SKL with 12.5.)

### Framebuffer kext – ✅ no problem
- 18 extra symbols: `AppleIntelFramebufferController::*` (provided by WhateverXe's `AppleIntelTGLCompat`) and trivial `OSData`/`OSNumber`/libc.

### Accelerator kext (`AppleIntelTGLGraphics`) – ⚠️ the real work
83 symbols that SKL 12.5 does not import. Almost all of them come from three **IOAcceleratorFamily2 classes that were renamed between 11.0 beta and 12.5**:

| TGL 11.0 imports | SKL 12.5 / Tahoe use |
|---|---|
| `IOAccelLegacySurface` (16 methods + vtable + metaclass) | `IOAccelSurface` with the same method names |
| `IOAccelLegacyDisplayPipe` (11) | `IOAccelDisplayPipe` |
| `IOAccelLegacyDisplayMachine` (23) | `IOAccelDisplayMachine` |
| `IOAccelShared2::*RESERVED*`, `scrubEvents`, … | ? (check against Tahoe) |
| `OSObject::operator new/delete`, `IOMalloc` | Tahoe: `OSObject_typed_operator_new`, `IOMallocTypeImpl` (old ones probably still exported) |

Because TGL **subclasses** these classes (constructors `C2`, vtables `__ZTV`, `gMetaClass`), renaming the symbols is not enough. **Object size and vtable layout** must match the Tahoe classes. Options:
1. **Symbol renaming** in the kext (`IOAccelLegacySurface` → `IOAccelSurface`) if the layouts match. Lowest effort, needs verification.
2. **Shim kext / Lilu** that provides the legacy classes as thin subclasses of the Tahoe classes.
3. **WhateverXe/Lilu patches** for individual vtable slots.

## Next step: Tahoe reference binaries

`tools/collect-tahoe.sh` (run on Tahoe) copies the following to the EFI partition (`/Volumes/EFI/xe-dump`, ~60 MB):
the kernel, `IOAcceleratorFamily2`, `IOGraphicsFamily`, `IOSurface`, `IOPCIFamily`, plus Tahoe's native **ICL (Gen11)** and KBL drivers as reference.

With those we can check:
- [ ] Which of the 83 symbols Tahoe exports, and which are missing
- [ ] Vtable layout of `IOAccelSurface`/`DisplayPipe`/`DisplayMachine` in Tahoe vs. `IOAccelLegacy*` in 11.0
- [ ] Tahoe ICL vs. 11.0 TGL: the two drivers come from the same codebase, so Tahoe's ICL is the best template for the new ABI
- [ ] Load-command patch + impostor on the TGL MTLDriver

## Risks
- The impostor is closed source and tuned for Monterey drivers. If Big Sur 11.0 structs differ from it, we need our own swizzle shim.
- WhateverXe's binary patches use exact offsets in the 20A2314a binaries. Renaming symbols must not move code (only the string table / binding info), otherwise every offset breaks.
- Every iteration needs a test boot on the T14.
