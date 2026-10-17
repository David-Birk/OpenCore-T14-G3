# OpenCore EFI – Lenovo ThinkPad T14 Gen 3 (Intel)

OpenCore EFI for the ThinkPad T14 Gen 3 (Intel, Alder Lake), booting **macOS Tahoe**.

> ⚠️ Work in progress. The iGPU (Iris Xe) is **not** accelerated – macOS runs on a VESA framebuffer (`-igfxvesa`), so the UI is laggy.
> The long-term goal of this repo is to explore Iris Xe support.

## Hardware

| Component | Model |
|-----------|-------|
| CPU | Intel Core i5-1245U (12th Gen, Alder Lake) |
| iGPU | Intel Iris Xe Graphics (Alder Lake-UP3 GT2) |
| Wi-Fi / BT | Intel Alder Lake-P CNVi |
| Audio | Intel Alder Lake PCH-P HDA |
| BIOS | N3MET29W (1.28) |
| SMBIOS | MacBookPro16,2 |

## Status

| Feature | Status |
|---------|--------|
| Boot macOS Tahoe | ✅ |
| Graphics acceleration (Iris Xe) | ❌ VESA only |
| Wi-Fi (AirportItlwm) | |
| Bluetooth | |
| Trackpad / TrackPoint (VoodooI2C / VoodooPS2) | |
| Keyboard | |
| Audio | ❌ AppleALC disabled |
| Battery | |
| Sleep / Wake | |
| Brightness | ❌ |

_(Fill in the blanks as things get tested.)_

## Before you boot

The SMBIOS values in `EFI/OC/config.plist` → `PlatformInfo > Generic` are **placeholders**.
Generate your own `MLB`, `SystemSerialNumber` and `SystemUUID` for `MacBookPro16,2` with
[GenSMBIOS](https://github.com/corpnewt/GenSMBIOS), and set `ROM` to your NIC's MAC address.
Never share your own values publicly.
Ontop, use the publicly available MacOS Recovery Image Downloader tool, and but the the to files in a folder "com.applerecovery.boot" on the root of your efi partition, e.g. a usb stick.
## Credits

[Acidanthera](https://github.com/acidanthera) (OpenCore, Lilu, VirtualSMC, …), [OpenIntelWireless](https://github.com/OpenIntelWireless), [VoodooI2C](https://github.com/VoodooI2C), [USBToolBox](https://github.com/USBToolBox) and the [Dortania guides](https://dortania.github.io/).
