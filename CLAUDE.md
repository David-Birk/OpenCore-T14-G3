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
   - **Resolved:** Tahoe still exports `IOAccelLegacySurface`/`DisplayPipe`/`DisplayMachine`. All inherited vtables and parent object sizes match 11.0. 5 imports were renamed in Tahoe, but all are vtable-only and kmutil's vtable patching binds them; the **unmodified 20A2314a accelerator links** into an aux KC on 26.7.1 (`tools/link-test.sh`). Details: TAHOE-PORT.md "Result 2".
3. Known hurdle for the first boot: WhateverXe's Display13 bootstrap expects only HDMI active on pipe A. The GOP lights up eDP → test with the **lid closed + HDMI**.

## Next steps (on Tahoe)
- [x] Setup: Xcode is installed. Homebrew no longer supports Intel Macs, so `ipsw` is the standalone release binary in `~/dev/xe-research/bin/ipsw`
- [x] WhateverXe `adl-p` cloned to `~/dev/WhateverXe` (MacKernelSDK + Lilu 1.7.2 DEBUG in its root). `python3 tools/test.py`: 55/55 after fixing `tests/device_selection.cpp` for the 0x0C stepping. `python3 tools/build.py` builds. Native replay tests need the original Apple-signed 20A2314a binaries (SHA-pinned); the PatcherSupportPkg copies don't match
- [x] Extract IOAcceleratorFamily2 + ICL/KBL from the system KC and compare vtables/sizes (`tools/vtables.py`)
- [x] Decide: **no change needed**, kmutil vtable patching handles the renamed slots (`tools/rename-imports.py` stays as a fallback)
- [x] `sudo tools/link-test.sh` (kmutil link against the live KCs, installs nothing): accelerator links
- [ ] Link test for the framebuffer together with `AppleIntelTGLCompat`
- [x] MTLDriver: IOKit → impostor via `tools/patch-mtldriver.py` (in place, because of the header code cave). Loads on Tahoe (dlopen test)
- [x] Framebuffer + `AppleIntelTGLCompat` link test (both link): `sudo tools/link-test.sh --together …/AppleIntelTGLCompat.kext …/AppleIntelTGLGraphicsFramebuffer.kext`
- [x] OCLP: local branch `tahoe-adlp` in `~/dev/OpenCore-Legacy-Patcher` (b00t0x `mod`): 46A8, 25G241, Tahoe payload list. Not pushed, no fork yet
- [x] WhateverXe `tahoe` branch (pushed): exact kernel identity table, 25G241 admitted for Display13/recovery/NVRAM fix. 56/56 tests
- [x] Big Sur 20G1443 vs Tahoe kernel/family ABI: no blocker (TAHOE-PORT.md "Result 5"). Big Sur files in `~/dev/xe-research/bigsur/`
- [ ] Port WhateverXe's `pmap_enter_options` MMIO routing to 25G241. Until then acceleration stays fail-closed on Tahoe
- [ ] Display-only test boot, runbook `docs/TAHOE-TEST-1.md`. **State 2026-10-17:**
  - [x] Step 0: FileVault decryption started (`fdesetup status`; must read "FileVault is Off" before the root patch). ESP backups: `~/EFI-backup-20261017` (full) and `/Volumes/EFI/OC-backup-20261017` (= `/efi/OC-backup-20261017` in Arch)
  - [ ] Step 1: user copies WhateverXe.kext to the ESP and runs `apply-xe-config.py --write`, then reboots. **After the reboot, check:** `kmutil showloaded --list-only | grep WhateverXe`, `log show --last boot --predicate 'sender == "WhateverXe"'`, and that macOS came up normally
  - [ ] Step 2: once FileVault is off, root patch with the OCLP branch (venv `.venv`, Python 3.12 from `~/dev/xe-research/bin/py312`)

## Working data (not in the repo)
`~/dev/xe-research/`: `tahoe/` (collect-tahoe.sh output, `kexts/` and `bootkexts/` extracted from the KCs), `tgl/` (20A2314a binaries from b00t0x/PatcherSupportPkg), `skl/` (SKL 12.5-23.4), `patched/` (renamed TGL kext, patched MTLDriver bundle, `AppleIntelTGLImpostor.dylib`), `tgl/bundles/` (full 20A2314a bundles incl. TGLCompat).

## Rules
- **No `Co-Authored-By` lines** in commits. Commit identity: `David-Birk` with the GitHub noreply address.
- **Never commit real SMBIOS values** (`MLB`, `SystemSerialNumber`, `SystemUUID`, `ROM`). The `config.plist` here uses placeholders; the real one lives only on the ESP.
- WhateverXe patches use **exact offsets** in the 20A2314a binaries. Tahoe adjustments must not move code.
- Ask before root patches, kext installs or ESP/config changes. The laptop triple-boots Arch/Windows/macOS from one NVMe (GRUB → OpenCore). Tahoe is the only macOS install.

## Safety net for tests on Tahoe
- Revert root patches with OCLP ("Revert Root Patches"). Note down the APFS snapshot state before the first patch.
- Disable WhateverXe at boot: add `-wexoff` to the boot-args (OpenCore picker), or set `Kernel > Add` to disabled.
- Arch Linux is the recovery system: the ESP is mounted at `/efi`, and the OpenCore config is at `/efi/EFI/OC/config.plist`.
