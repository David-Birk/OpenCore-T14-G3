#!/bin/bash
# Run on macOS Tahoe: collects the binaries needed to compare Apple's TGL
# driver (Big Sur 11.0) against Tahoe's graphics stack. Read-only on the system;
# writes only to the target folder (default: the EFI partition, folder xe-dump).
set -euo pipefail

OUT="${1:-}"
if [ -z "$OUT" ]; then
    if ! mount | grep -q ' on /Volumes/EFI '; then
        sudo diskutil mount "$(diskutil list | awk '/EFI/ && /disk0/ {print $NF; exit}')"
    fi
    OUT=/Volumes/EFI/xe-dump
fi
sudo mkdir -p "$OUT"
sudo chown "$(id -u)" "$OUT"
echo "Writing to $OUT"

sw_vers > "$OUT/sw_vers.txt"
uname -a > "$OUT/uname.txt"

copy() {
    if [ -e "$1" ]; then
        mkdir -p "$OUT/$(dirname "$1")"
        cp -R "$1" "$OUT/$1"
        echo "ok   $1"
    else
        echo "miss $1" | tee -a "$OUT/missing.txt"
    fi
}

# Kernel and the families the TGL kexts link against
copy /System/Library/Kernels/kernel
for k in IOAcceleratorFamily2 IOGraphicsFamily IOSurface IOPCIFamily \
         AppleIntelICLGraphics AppleIntelICLLPGraphicsFramebuffer \
         AppleIntelKBLGraphics AppleIntelKBLGraphicsFramebuffer; do
    copy "/System/Library/Extensions/$k.kext/Contents/MacOS/$k"
    copy "/System/Library/Extensions/$k.kext/Contents/Info.plist"
done

# Tahoe's native Gen11 Metal/GL drivers (closest relative of the TGL bundles)
for b in AppleIntelICLGraphicsMTLDriver AppleIntelICLGraphicsGLDriver AppleIntelKBLGraphicsMTLDriver; do
    copy "/System/Library/Extensions/$b.bundle/Contents/MacOS/$b"
    copy "/System/Library/Extensions/$b.bundle/Contents/Info.plist"
done

# Fallback if kext executables are only inside the kernel collection
[ -e "$OUT/System/Library/Extensions/IOAcceleratorFamily2.kext/Contents/MacOS/IOAcceleratorFamily2" ] ||
    copy /System/Library/KernelCollections/BootKernelExtensions.kc

kmutil showloaded --list-only 2>/dev/null | grep -iE 'accel|graphics|intel|iosurface' > "$OUT/kmutil-loaded.txt" || true
du -sh "$OUT"
echo "Done. Boot Linux and run: sudo cp -r /efi/xe-dump ~/dev/xe-research/tahoe"
