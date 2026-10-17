# Iris Xe on macOS – Research (as of 2026-10-17)

Goal: hardware-accelerated graphics (QE/CI, Metal) for the Iris Xe iGPU of the ThinkPad T14 Gen 3 (Intel).

## TL;DR

- **We do not need to write a GPU driver from scratch.** Apple built drivers for Tiger Lake (Xe-LP) and shipped them in an early macOS Big Sur build (**11.0 / 20A2314a**):
  `AppleIntelTGLGraphics.kext`, `AppleIntelTGLGraphicsFramebuffer.kext`, plus the GL, Metal and VA user-space bundles. The Metal shader compiler ships with them.
- The community is patching these drivers onto newer Xe-LP GPUs, and **it already works** on some hardware:
  [WhateverXe](https://github.com/b00t0x/WhateverXe) reports Metal/OpenGL, HEVC and dual external displays on **Tiger Lake and Alder Lake-N**, but only on Big Sur 11.7.11 (20G1443) and only on external displays.
- Our GPU (**Alder Lake-P, `8086:46A8`**) is **not supported yet**. It is next on WhateverXe's roadmap ("Alder Lake and Raptor Lake S/H/P/U", "Internal displays", "Monterey through Tahoe").
- **Most promising way in:** help with Alder Lake-P support in WhateverXe (test, debug, contribute), not start our own project.

## Our hardware (read from Linux i915)

| | |
|---|---|
| PCI ID | `8086:46A8` rev `0x0C`, subsystem `17AA:22E8` |
| i915 platform | `alderlake_p`, display version **13.00** (stepping D0) |
| Graphics / media IP | version **12** (stepping C0) – same GT generation as Tiger Lake |
| Topology | 1 slice, 5 subslices, 16 EU/subslice = **80 EU** (same as TGL i5-1135G7, `9A49`) |
| Stolen memory (DVMT) | **64 MB** (`0x9C800000–0xA07FFFFF`), not adjustable in the Lenovo BIOS |
| CD clock | 192 MHz current, 652.8 MHz max |
| Ports | eDP-1 on DDI A/PHY A (1920×1200 panel), HDMI-A-1 on DDI B/PHY B, DP-1…4 = USB-C/TB (Type-C PHYs) |
| Firmware used by Linux | DMC `adlp_dmc.bin` 2.20, GuC `adlp_guc_70.bin` 70.49.4, HuC `tgl_huc.bin` 7.9.3 |
| VBT dump | [`hardware/t14g3_vbt.bin`](hardware/t14g3_vbt.bin) |

What this means:
- **The render/compute side (GT) is architecturally Tiger Lake.** Apple's TGL accelerator and Metal compiler should "understand" our EUs.
- **The display engine is newer (display 13 instead of 12).** Most of the porting work is likely here: Apple's TGL framebuffer programs display-12 registers. In Linux i915, Alder Lake-N is a sub-platform of Alder Lake-P, so it shares the display-13 engine. WhateverXe already supports ADL-N, which makes ADL-P much more reachable.
- HDMI hangs off a combo PHY (DDI B), like the setups WhateverXe has tested. The internal display is eDP on DDI A and is still unsupported there.

## Existing projects

| Project | Approach | Status | Relevance |
|---|---|---|---|
| [b00t0x/WhateverXe](https://github.com/b00t0x/WhateverXe) | Lilu plugin (WhateverGreen fork) + Xe root patch via an [OCLP fork](https://github.com/b00t0x/OpenCore-Legacy-Patcher) that installs the TGL drivers from 20A2314a | v0.2.3 (2026-10-10), very active. Metal works on TGL `9A40/9A49/9A78` + ADL-N `46D0–46D4`, Big Sur 20G1443 only, external displays only | ⭐ **Main candidate** |
| [sgiammori/NootedGreen](https://github.com/sgiammori/NootedGreen) | Lilu plugin, TGL driver spoofing for Haswell…Raptor Lake, targets Sonoma 14.x | WIP, dev platform RPL-P (~70% per README), "Alder Lake ~35%, untested". Last commit 2026-05 | Second option, closer to newer macOS |
| [macintelk/drm](https://github.com/macintelk/drm) (jalavoui) | Linux i915/xe sources browsable in Xcode + tools for TGL/ICL kexts | Active (2026-10-17) | Reference / tooling |
| [pawan295/Appleinteltgldriver.kext](https://github.com/pawan295/Appleinteltgldriver.kext) | Custom driver written from scratch | Per README no command submission and no Metal; boot-panic loops reported | ❌ not useful |
| ICL spoofing (WhateverGreen, ICLLP framebuffer) | Spoof device-id to Ice Lake | Framebuffer partly worked, `-allow3d` → "Unsupported ICL Sku" panic. Dead end | ❌ superseded |

Forum threads:
- InsanelyMac: [Iris Xe on Tiger Lake (ICLLP framebuffer…)](https://www.insanelymac.com/forum/topic/358305-80-solved-iris-xe-igpu-on-tiger-lake-successfully-loaded-icllp-frambuffer-and-vram-also-recognizes-1536mb-however-some-issues/) – main discussion, 33+ pages; recent posts discuss WhateverXe and TGL patches
- InsanelyMac: [AppleIntelTGLGraphics](https://www.insanelymac.com/forum/topic/360229-appleinteltglgraphics/) (jalavoui, since 11/2024)
- InsanelyMac: [NootedGreen](https://www.insanelymac.com/forum/topic/362634-nootedgreenkext-is-on-air-its-a-long-long-road-to-complete/)
- GitHub: [lshbluesky – Research on Iris Xe QE/CI](https://github.com/lshbluesky/Samsung-NT750XDA-KF59U-Hackintosh/discussions/15) (history of the ICL-spoofing attempts)

## Known hurdles for our machine

1. **macOS version.** WhateverXe currently works only on Big Sur 11.7.11. We run Tahoe. We need a **second APFS volume with Big Sur** for testing. Tahoe support is on their roadmap via OCLP.
2. **Display 13.** Apple's TGL framebuffer was built for display 12. ADL-N support shows that people are already bridging this gap.
3. **Internal display (eDP).** Not supported by WhateverXe yet. For a laptop this is the most important piece, but external HDMI is a fine first milestone.
4. **DVMT 64 MB.** WhateverXe recommends 96 MB; for 60 MB it documents `-igfxdvmt` + `framebuffer-stolenmem`. We need to check whether that works with 64 MB. The Lenovo BIOS has no DVMT setting (maybe via a setup-variable edit, risky).
5. **USB-C/Thunderbolt outputs** (Type-C PHY): not supported yet. Test with **HDMI**.
6. **SIP/AMFI/root patches.** The Xe root patch modifies the system volume and needs the AMFIPass mod.

## Proposed plan

### Phase 0 – Preparation (now)
- [ ] Both of us: post the same hardware data (`lspci -nn`, i915 dmesg, VBT) → is bspid67's T14 G3 identical (46A8, 80 EU)?
- [ ] Read WhateverXe in depth: `docs/`, source code, especially the ADL-N backend (what was changed compared to TGL?)
- [ ] Get Apple's TGL drivers (from the OCLP fork's payload) and look at them in Ghidra/IDA
- [ ] Linux i915 as reference: `drivers/gpu/drm/i915/display/` – find the differences between `DISPLAY_VER == 12` and `13` for our ports (DDI A eDP, DDI B HDMI)
- [ ] Open an issue/discussion with WhateverXe: introduce ourselves, offer ADL-P (`46A8`) as test hardware, ask what's needed

### Phase 1 – Test setup
- [ ] Second APFS volume with **Big Sur 11.7.11 (20G1443)** next to Tahoe, with its own OpenCore entry/config. Our current EFI works on Tahoe; Big Sur needs adjusted kexts (AirportItlwm build for Big Sur, etc.)
- [ ] Set up debugging: `keepsyms=1 debug=0x100 msgbuf=…`, ideally a serial/network kernel debugger or at least persistent panic logs
- [ ] External HDMI monitor ready

### Phase 2 – First attempt
- [ ] Root-patch with the OCLP fork + WhateverXe, use a `device-id` override to the ADL-N backend (e.g. `D2460000`) on an external HDMI display. The README warns that this does *not* guarantee compatibility, but the logs and panics will show exactly where ADL-P differs
- [ ] Collect logs/panics and send them to the WhateverXe project

### Phase 3 – Contribute
- [ ] Implement a proper ADL-P backend in WhateverXe (with the maintainer)
- [ ] Internal display (eDP, DDI A, backlight)
- [ ] Newer macOS versions (Monterey…Tahoe), coordinated with WhateverXe/OCLP

## Things to learn (reading list)

- [Lilu](https://github.com/acidanthera/Lilu) + [WhateverGreen](https://github.com/acidanthera/WhateverGreen): how kext patching/hooking works at runtime
- Intel PRMs for Tiger Lake / Alder Lake (Intel publishes them as "Intel Graphics for Linux – Programmer's Reference Manuals")
- Linux `i915` / `xe` sources (display version 12 vs 13)
- Reverse engineering: Ghidra or IDA + `keepsyms` panic logs
- [Dortania Debugging](https://dortania.github.io/OpenCore-Install-Guide/troubleshooting/debug.html)
