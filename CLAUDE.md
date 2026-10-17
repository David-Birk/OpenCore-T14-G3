# CLAUDE.md – OpenCore T14 Gen 3 / Iris Xe on Tahoe

Context for Claude Code sessions (and humans) working on this repo. Status as of 2026-10-17.

## Goal
Hardware-accelerated graphics (Metal/QE/CI) for the **Intel Iris Xe iGPU** of the ThinkPad T14 Gen 3 on **macOS Tahoe**.
Approach: Apple's never-released Tiger Lake driver (macOS 11.0 build 20A2314a) + [WhateverXe](https://github.com/b00t0x/WhateverXe) (Lilu plugin) extended for Alder Lake-P + Tahoe compatibility patches à la OpenCore Legacy Patcher.

Collaborators: David-Birk (repo owner), bspid67 (same laptop). Discussion: GitHub issue #18 in the original repo.

## Hardware (measured under Linux i915)
- CPU i5-1245U (Alder Lake-P), iGPU `8086:46A8` rev `0x0C` (GT stepping C0, display D0), subsystem `17AA:22E8`
- GT: graphics version 12 (= TGL GT2), 1 slice, 5 DSS, **80 EU**. Display: version **13** (XeLPD)
- Ports (VBT `docs/hardware/t14g3_vbt.bin`): eDP DDI A, HDMI DDI B (combo, DDC pin 2), TC1–4 = Type-C
- DVMT/stolen memory **64 MB**, not adjustable in BIOS
- SMBIOS MacBookPro16,2; boot-args currently contain `-igfxvesa` (iGPU disabled)

## Repos and locations
| What | Where |
|---|---|
| This repo (EFI + docs) | github.com/David-Birk/OpenCore-T14-G3 |
| WhateverXe fork, branch **`adl-p`** | github.com/David-Birk/WhateverXe (upstream b00t0x/WhateverXe) |
| OCLP fork with Xe root patch | github.com/b00t0x/OpenCore-Legacy-Patcher (branch `mod`, `intel_xe.py`) |
| TGL driver binaries (20A2314a) + SKL Tahoe payloads | github.com/b00t0x/PatcherSupportPkg, `Universal-Binaries/11.0 20A2314a`, `12.5-25`, `12.5-23.4` |
| Alternative project | github.com/sgiammori/NootedGreen (TGL spoofing, Sonoma) |

## Status
1. **`adl-p` commit f63a88e**: 46A8 rev 0x0C is admitted and goes through WhateverXe's Display13 path (shared with ADL-N) with its own GT2 profile (`GT::ADLPGT2`, 80/96 EU, 8 L3 banks). Not built or tested yet. **Unverified:** VDBOX/VEBOX fuse `0x000E00FA` (derived from Linux; a mismatch fails closed and publishes the real fuse value as an `N97*` ioreg property).
2. **Tahoe analysis** (`docs/TAHOE-PORT.md`):
   - OCLP runs SKL drivers from 12.5 on Tahoe; the only change to the MTLDriver is the load command `IOKit` → `impostor.dylib` (Moraea Metal shim).
   - TGL MTLDriver and framebuffer have no critical extra imports compared with SKL 12.5.
   - TGL accelerator: kernel imports resolve against Tahoe 26.7.1 except 3 symbols, which SKL also uses (they come from IOAcceleratorFamily2).
   - **Resolved:** Tahoe still exports `IOAccelLegacySurface`/`DisplayPipe`/`DisplayMachine`. All inherited vtables and parent object sizes match 11.0. Only 5 imports were renamed (same vtable slot); `tools/rename-imports.py` fixes them without moving code. Details: TAHOE-PORT.md "Result 2".
3. Known hurdle for the first boot: WhateverXe's Display13 bootstrap expects only HDMI active on pipe A. The GOP lights up eDP → test with the **lid closed + HDMI**.

## Next steps (on Tahoe)
- [x] Setup: Xcode is installed. Homebrew no longer supports Intel Macs, so `ipsw` is the standalone release binary in `~/dev/xe-research/bin/ipsw`
- [ ] Clone the WhateverXe fork (`adl-p`), put `MacKernelSDK/` (acidanthera) and a `Lilu.kext/` debug build in its root, run `python3 tools/test.py` (includes `tests/alderlake_p.cpp`)
- [x] Extract IOAcceleratorFamily2 + ICL/KBL from the system KC and compare vtables/sizes (`tools/vtables.py`)
- [x] Decide: **symbol renaming** (`tools/rename-imports.py`)
- [ ] `sudo tools/link-test.sh` on the renamed kext (kmutil link against the live KCs, installs nothing)
- [ ] OCLP fork: add `0x46A8` to `intel_xe.py` `DEVICE_IDS`, relax `native_os()` for Tahoe, MTLDriver with the impostor load command

## Working data (not in the repo)
`~/dev/xe-research/`: `tahoe/` (collect-tahoe.sh output, `kexts/` and `bootkexts/` extracted from the KCs), `tgl/` (20A2314a binaries from b00t0x/PatcherSupportPkg), `skl/` (SKL 12.5-23.4), `patched/` (renamed TGL kext).

## Rules
- **No `Co-Authored-By` lines** in commits. Commit identity: `David-Birk` with the GitHub noreply address.
- **Never commit real SMBIOS values** (`MLB`, `SystemSerialNumber`, `SystemUUID`, `ROM`). The `config.plist` here uses placeholders; the real one lives only on the ESP.
- WhateverXe patches use **exact offsets** in the 20A2314a binaries. Tahoe adjustments must not move code.
- Ask before root patches, kext installs or ESP/config changes. The laptop triple-boots Arch/Windows/macOS from one NVMe (GRUB → OpenCore). Tahoe is the only macOS install.

## Safety net for tests on Tahoe
- Revert root patches with OCLP ("Revert Root Patches"). Note down the APFS snapshot state before the first patch.
- Disable WhateverXe at boot: add `-wexoff` to the boot-args (OpenCore picker), or set `Kernel > Add` to disabled.
- Arch Linux is the recovery system: the ESP is mounted at `/efi`, and the OpenCore config is at `/efi/EFI/OC/config.plist`.
