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

## Result 1: Tahoe kernel (26.7.1, 25G241)

Tahoe ships kext executables only inside the kernel collections. Compared against the boot KC (kernel, IOPCIFamily, IOSurface):
- **TGL accelerator:** of 559 non-graphics imports, only 3 are missing (`___globalObjectIDCounter`, `___ktrace_enable_filter`, `___ktrace_kernel_enabled`). SKL 12.5 imports exactly the same three and runs on Tahoe, so they come from IOAcceleratorFamily2. ✅
- **TGL framebuffer:** missing are only `AppleGraphicsDeviceControl` (its own kext) and `IOACPIPlatformDevice` (ACPI platform). Both are in the system KC. ✅ (to be confirmed)
- → The kernel side is **not** a problem. Everything that is open lies in the **system KC** (IOAcceleratorFamily2, IOGraphicsFamily, AGDC, Intel GPU drivers).

## Result 2: system kernel collection (26.7.1, 25G241)

Kexts extracted with `ipsw kernel extract` (IOAcceleratorFamily2 487.4.4, IOGraphicsFamily 600, AGDC 8.1.12, ICL/KBL 24.0.5).

**Tahoe still ships the legacy classes.** `IOAccelLegacySurface`, `IOAccelLegacyDisplayPipe` and `IOAccelLegacyDisplayMachine` are exported by Tahoe's IOAcceleratorFamily2 (metaclass, vtable, all methods), as subclasses of the renamed `IOAccelSurface`/`DisplayPipe`/`DisplayMachine`. The rename table above was a false alarm.

**Imports.** Against boot KC + system KC, the TGL accelerator has exactly **5** unresolved imports, the framebuffer only the `AppleIntelFramebufferController`/`PortHAL`/`DisplayPath` symbols that `AppleIntelTGLCompat` provides.

**Vtables** (`tools/vtables.py scan`): every vtable TGL inherits from Tahoe (42 class pairs in IOAcceleratorFamily2, plus `IOFramebuffer` 350 slots and `AppleGraphicsDeviceControl` 276 slots) has the same slot layout as in 11.0. The only differences are Tahoe pure virtuals that TGL implements and the 5 imports, which are the **same slot under a new name**:

| Slot | TGL 11.0 imports | Tahoe exports |
|---|---|---|
| `IOAccelMemoryMap` [50] | `_RESERVEDIOAccelMemoryMap0()` | `getAssignedGPUVirtualAddressLength() const` |
| `IOAccelResource2` [70] | `_RESERVEDIOAccelResource0()` | `dirtyBufferRange(u64, u64)` |
| `IOAccelResource2` [71] | `_RESERVEDIOAccelResource1()` | `dirtyVendorCommand(u32, u64)` |
| `IOAccelResource2` [35] | `initSurfaceBuffer(IOAccelLegacySurface*, …)` | `initSurfaceBuffer(IOAccelSurface*, …)` |
| `IOGraphicsAccelerator2` [287] | `createDrawable(IOAccelLegacySurface*, …)` | `createDrawable(IOAccelSurface*, …)` |

The reserved slots were filled with new methods; TGL never overrides them, so binding them to the Tahoe implementation is correct. `IOAccelLegacySurface*` → `IOAccelSurface*` is a base-class pointer, same ABI.

**Object sizes.** Sizes from the `MetaClass` constructors (`OSMetaClass(name, super, size)`). For every TGL subclass, the lowest own-field offset it touches is exactly the size of the Tahoe parent (e.g. `IntelAccelerator` starts at `0xdd8` = `sizeof(IOGraphicsAccelerator2)`; `IGAccelSurface` is `0x13b0` = `sizeof(IOAccelLegacySurface)` with no own fields). Cross-check: SKL 12.5 (runs on Tahoe) vs. Tahoe KBL shows the same own-field offsets. → No parent class grew or shrank between 11.0 and Tahoe. (No 11.0 IOAcceleratorFamily2 binary was available, so this is inferred from field accesses, not a header diff.)

**→ No binary change needed.** All 5 references are vtable entries only (no direct calls). kmutil, like kxld before it, patches inherited vtable slots from the parent's vtable, so they never have to resolve by name. Verified with `tools/link-test.sh`: the **unmodified** 20A2314a `AppleIntelTGLGraphics` links into an auxiliary KC against the live 26.7.1 boot/system KCs, and the 5 slots point at Tahoe's `getAssignedGPUVirtualAddressLength`, `dirtyBufferRange`, `dirtyVendorCommand`, `initSurfaceBuffer(IOAccelSurface*…)` and `createDrawable(IOAccelSurface*…)`.

`tools/rename-imports.py` (renames the 5 imports by appending to the string table) produces a byte-identical linked result. Keep it only as a fallback for loaders without vtable patching.

Tahoe also keeps the userspace drivers (`…MTLDriver`, `…GLDriver`) only in the dyld shared cache (`/System/Volumes/Preboot/Cryptexes/OS/System/Library/dyld/`); extract with `ipsw dyld extract` when comparing them.

## Result 3: Metal driver loads on Tahoe

**Impostor.** OCLP's SKL 12.5-25 MTLDriver differs from 12.5 only in the IOKit load command (→ `impostor.dylib`); `__text` is identical. The impostor hooks Metal.framework internals (`MTL*DescriptorInternal _descriptorPrivate`, `-[MTLTextureDescriptorInternal validateWithDevice:]`, `-[_MTLDevice supportsFamily:]`, `MTLIOAccelDevice`) plus app workarounds; nothing in it is SKL-specific. TGL's `MTLIGAccelDevice` subclasses the same `MTLIOAccelDevice`.

**Code cave.** The 20A2314a MTLDriver from PatcherSupportPkg has injected code in the Mach-O header padding (`0x10d0`–`0x1ee7`, entered by `jmp 0x10d0` at the start of `__GLOBAL__sub_I_IntelTelemetryShared.cpp`). The load commands end exactly at `0x10d0`, so **they must not grow**: `install_name_tool -change` to the long bundle path overwrites the cave and the driver dies with SIGILL in its initializer. `tools/patch-mtldriver.py` rewrites the IOKit path inside the existing 88-byte command instead (≤ 63 characters). Default target: `/System/Library/Extensions/AppleIntelTGLImpostor.dylib`.

**Load test** (non-installing, on 26.7.1): `dlopen` of the patched driver with the SKL 12.5-25 impostor succeeds. All imports bind against Tahoe's frameworks, the impostor and the driver's initializers run, and `MTLIGAccelDevice` registers as a subclass of `MTLIOAccelDevice`. Not tested yet: device creation, which needs the kernel driver.

**Still open:** the impostor's `descriptorPrivate` layout fixes were written for Monterey (12.5) drivers. The 11.0 driver may read those structs at different offsets. That shows up only when the first pipeline or texture is created.

## Result 4: WhateverXe is the blocker, not the Apple drivers

WhateverXe (`adl-p`) is qualified for exactly one kernel, Big Sur 20G1443 (`Darwin Kernel Version 20.6.0 … xnu-7195.141.49.702.12~1`):
- `XE::selectProfile`: the ADL-N/ADL-P Display13 path sets `adlnKernelReady` only on that exact version string. **On Tahoe it fails closed and does nothing for 46A8.** The TGL path also accepts only 20A2314a/20G1443 kernels.
- Lilu plugin range is `BigSur`–`BigSur`; on Tahoe it loads only with `-wexbeta`.
- Further 20G1443-only fixes that check exact kernel bytes or versions: MMIO uncached mapping (`pmap_enter_options`/`IOProtectCacheMode` byte patterns, ADL-P BAR/PAT), GPU hang recovery (`-disablegfxfirmware` path), the `hwSaveNVRAM` vtable fix.
- All 10 private kernel symbols it resolves still exist in Tahoe 26.7.1.

**Gap in the vtable analysis.** Checking subclass vtables does not cover virtual calls the TGL kexts make on kernel objects they only *use*. Example: the framebuffer's `hwSaveNVRAM` calls `IODTPlatformExpert` through `+0x9F8`. On 20G1443 and Tahoe `writeNVRAMProperty` sits at `+0x9E8`, so WhateverXe rewrites the call. That fix is needed on Tahoe too, but WhateverXe applies it only on 20G1443. Other such calls (e.g. into `IOPCIDevice`, `IOMemoryDescriptor`, `IOWorkLoop`) are unchecked.

**Uncached MMIO mapping (`tglPrepareMMIOUC`).** Required: `tglActive` and `tglAcceleratorReady` both need `tglMMIOUCRouted && tglMMIOUCReady`, on the ADL-N/ADL-P path too. It patches four mid-function sites in `pmap_enter_options` (`+0x48`, `+0x157`, `+0x15FA`, `+0x1850`) and checks `IOProtectCacheMode` bytes. On Tahoe none of the `pmap_enter_options` patterns occur anywhere in the function, so the hook must be re-derived from Tahoe's code. It also requires `tglVM.pciBAR == 0x4010000000` (16 MB) and a specific PAT MSR value; the T14 G3's BAR0 matches (`0x4010000000`, see RESEARCH.md), the PAT value is unchecked.

→ The Tahoe port needs a **Tahoe kernel path in WhateverXe**: qualify 25G241 in `selectProfile`, re-derive each kernel byte pattern against the 25G241 kernel, port the NVRAM slot fix, and audit virtual calls into non-subclassed kernel classes.

OCLP side prepared on local branch `tahoe-adlp` of the b00t0x OCLP fork: adds `0x46A8`, qualifies 25G241, and installs the kexts plus the patched Metal driver and impostor from a new payload folder `11.0 20A2314a-25`. **Do not install until WhateverXe has a Tahoe path.**

## Next steps
- [x] `sudo tools/link-test.sh`: the stock kext links (see above)
- [x] Link test for the framebuffer: `AppleIntelTGLGraphicsFramebuffer` + `AppleIntelTGLCompat` link together into an aux KC on 26.7.1
- [x] Load-command patch + impostor on the TGL MTLDriver (`tools/patch-mtldriver.py`, Result 3)
- [ ] WhateverXe: Tahoe 25G241 kernel path (Result 4)
- [ ] Audit virtual calls from the TGL kexts into non-subclassed kernel classes
- [ ] Payload `11.0 20A2314a-25` (patched MTLDriver + `AppleIntelTGLImpostor.dylib`) into a Universal-Binaries.dmg for the OCLP branch
- [ ] First install via OCLP (see CLAUDE.md for the safety net)

## Risks
- The impostor is closed source and tuned for Monterey drivers. If Big Sur 11.0 structs differ from it, we need our own swizzle shim.
- WhateverXe's binary patches use exact offsets in the 20A2314a binaries. Renaming symbols must not move code (only the string table / binding info), otherwise every offset breaks. (`rename-imports.py` only appends to the string table.)
- Layout compatibility is inferred from field accesses; a runtime mismatch in a parent field would show up as a panic in IOAcceleratorFamily2 code.
- Every iteration needs a test boot on the T14.
