# Tahoe test boot 1: display only (no acceleration)

Goal: WhateverXe brings up the TGL framebuffer for 46A8 on macOS Tahoe 26.7.1 (25G241). Native acceleration stays fail-closed, because the `pmap_enter_options` MMIO routing is not ported yet (TAHOE-PORT.md, Result 4). Success means a native-resolution desktop over **HDMI with the lid closed**.

Everything below changes the system. Each step lists its rollback.

## Prepared (no system changes)

| Item | Where |
|---|---|
| WhateverXe + AppleIntelTGLCompat, `tahoe` branch (debug build) | `~/dev/WhateverXe/build/` |
| OCLP with Tahoe Xe-LP patchset, branch `tahoe-adlp` | `~/dev/OpenCore-Legacy-Patcher` (venv `.venv`, Python 3.12) |
| Payload DMG incl. `11.0 20A2314a-25` | `~/dev/xe-research/payload-out/Universal-Binaries.dmg` (`tools/build-payload.sh`) |
| Config change script | `tools/apply-xe-config.py` |

OCLP detection on this machine (read-only run): `Graphics: Intel Xe-LP` detected, no KDK needed, 5 files planned. It blocks on two things: **FileVault is on**, and WhateverXe is not loaded yet.

## Step 0: preconditions

1. **Turn FileVault off.** OCLP refuses root patches with FileVault on. Run `sudo fdesetup disable`; decryption runs in the background and can take a while. Check with `fdesetup status`.
2. Note the sealed system snapshot (current: `com.apple.os.update-590AC978…`, XID 345): `diskutil apfs listSnapshots /`.
3. Back up the ESP:
   ```
   sudo diskutil mount disk0s1
   sudo cp -R /Volumes/EFI/EFI ~/EFI-backup-$(date +%Y%m%d)
   ```

## Step 1: WhateverXe into OpenCore, then reboot

```
cp -R ~/dev/WhateverXe/build/WhateverXe.kext /Volumes/EFI/EFI/OC/Kexts/
python3 tools/apply-xe-config.py /Volumes/EFI/EFI/OC/config.plist          # review
python3 tools/apply-xe-config.py /Volumes/EFI/EFI/OC/config.plist --write  # backup: config.plist.bak-xe
```
Changes: WhateverXe after Lilu; boot-args `-igfxvesa` → `-allow3d -disablegfxfirmware -wexbeta -wexdbg`; iGPU properties: Ice Lake leftovers removed, display pool capped at 60 MB for the fixed 64 MB DVMT.

Expected after reboot: the same desktop as before (no driver attaches to 46A8 yet), and `kmutil showloaded --list-only | grep WhateverXe` lists it.
Rollback: `python3 tools/apply-xe-config.py /Volumes/EFI/EFI/OC/config.plist --revert`, or from Arch: `cp /efi/EFI/OC/config.plist.bak-xe /efi/EFI/OC/config.plist`.

## Step 2: root patch

```
cp ~/dev/xe-research/payload-out/Universal-Binaries.dmg ~/dev/OpenCore-Legacy-Patcher/
cd ~/dev/OpenCore-Legacy-Patcher
sudo PYTHONPATH=. .venv/bin/python OpenCore-Patcher-GUI.command --patch_sys_vol
```
This installs the TGL kexts, the patched Metal driver and the impostor into `/System/Library/Extensions` and rebuilds the auxiliary kernel collection. That is the same link that `tools/link-test.sh` verified.

## Step 3: test boot

Shut down, close the lid, connect HDMI, boot macOS. Keep `-v` on so that boot hangs are visible.

Collect afterwards (or from Arch if macOS does not come up):
```
log show --last boot --predicate 'sender == "WhateverXe" || sender CONTAINS "AppleIntelTGL"' > ~/xe-test1.log
ioreg -lw0 -r -c IOPCIDevice -k N97Admission > ~/xe-test1-ioreg.txt
system_profiler SPDisplaysDataType > ~/xe-test1-displays.txt
```
Useful properties: `N97Admission`, `N97NativeStartAllowed`, `N97NativeKernelReady` (expected false: no MMIO routing), `XELPSharedProbeBound`, `TGLMMIOStrongUCRouted` (expected false).

## Rollback, worst case first

1. **macOS does not boot:** boot Arch, then `cp /efi/EFI/OC/config.plist.bak-xe /efi/EFI/OC/config.plist`. WhateverXe is disabled again; without it the TGL kexts do not attach to 46A8.
2. **Revert root patches:** in macOS, `sudo PYTHONPATH=. .venv/bin/python OpenCore-Patcher-GUI.command --unpatch_sys_vol`, or OCLP "Revert Root Patches". This returns to the sealed snapshot.
3. Restore the full ESP from `~/EFI-backup-*` if needed.

## Results

### Step 1 (2026-10-17): WhateverXe loaded on 25G241
- Boots normally. New boot-args active; `org.b00t0x.WhateverXe (0.2.3)` loaded after Lilu 1.7.2.
- `N97Admission = Yes`: 46A8 rev 0x0C (GT C0, display D0) admitted on Tahoe. VBT, OpRegion, firmware ports, stolen memory (GGC 705) and Display13 boot state read and published.
- GT readout: forcewake acquired and released cleanly. Fuses: slice `0x1`, DSS `0x1F` (5 DSS), EU disable `0x0` (80 EU), L3 `0x9118 = 0x88`, VDBOX/VEBOX `0x9140 = 0x000E00FA`. **This confirms the VDBOX/VEBOX value from `adl-p` on hardware.**
- `N97GTTopologyReady = No` (status 4, ProfileMismatch): `resourcesGT2` requires L3 fuse 0, the hardware reads `0x88`. If set bits are disabled banks (as the ADL-N branch reads `0xF0` = 4 banks), 6 of 8 banks are enabled. The bank count feeds the donor's URB/L3 setup (`urbReplaceAlderLakeN[17]`) and capability checks, so fix it only with a verified decoding (Linux `xe`/`i915`). This affects acceleration only, which stays fail-closed on Tahoe.
- `N97NativePreflight = No`, `N97NativeStartAllowed = No` (expected: GT topology, no MMIO routing on Tahoe; lid was open).
- OCLP detection afterwards: Intel Xe-LP, no validation blockers (`tools/oclp-detect.py`).
