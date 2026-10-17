#!/bin/bash
# Build an OCLP Universal-Binaries.dmg with the Tahoe Xe-LP payload folder
# "11.0 20A2314a-25" added on top of a PatcherSupportPkg release DMG.
#
#   11.0 20A2314a-25/System/Library/Extensions/
#     AppleIntelTGLGraphicsMTLDriver.bundle  IOKit import -> impostor (patch-mtldriver.py)
#     AppleIntelTGLImpostor.dylib            SKL 12.5-25 impostor from the same DMG
#     AppleIntelTGLCompat.kext               built from WhateverXe (ADL-P port probe, 25G241 start)
#     AppleIntelTGLGraphicsFramebuffer.kext  donor + 46A8 in N97Display13, OSBundleRequired Auxiliary
#
# The release DMG is only read (changes go to a shadow file). The output is
# encrypted with the passphrase OCLP mounts it with ("password").
# Usage: tools/build-payload.sh RELEASE.dmg WHATEVERXE_BUILD_DIR OUT.dmg
set -euo pipefail
SRC=$1 WXE=$2 OUT=$3
TOOLS=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
trap 'hdiutil detach "$WORK/mnt" -quiet 2>/dev/null || true; rm -rf "$WORK"' EXIT

mkdir "$WORK/mnt"
printf password | hdiutil attach -stdinpass -nobrowse -noverify -shadow "$WORK/shadow" \
    -mountpoint "$WORK/mnt" "$SRC" >/dev/null
VOL=$(diskutil info "$WORK/mnt" | awk -F': *' '/Volume Name/{print $2}')
DONOR="$WORK/mnt/11.0 20A2314a/System/Library/Extensions"
DST="$WORK/mnt/11.0 20A2314a-25/System/Library/Extensions"
rm -rf "$WORK/mnt/11.0 20A2314a-25" && mkdir -p "$DST"

cp -R "$DONOR/AppleIntelTGLGraphicsMTLDriver.bundle" "$DST/"
chmod -R u+w "$DST"
EXE="$DST/AppleIntelTGLGraphicsMTLDriver.bundle/Contents/MacOS/AppleIntelTGLGraphicsMTLDriver"
python3 "$TOOLS/patch-mtldriver.py" "$EXE" "$WORK/mtl"
cat "$WORK/mtl" > "$EXE"
cp "$WORK/mnt/12.5-25/System/Library/Extensions/AppleIntelSKLGraphicsMTLDriver.bundle/Contents/MacOS/impostor.dylib" \
    "$DST/AppleIntelTGLImpostor.dylib"
cp -R "$WXE/AppleIntelTGLCompat.kext" "$DST/"

# Donor framebuffer: its N97Display13 personality matches ADL-N only; add 46A8
# so the Display13 path can bind. WhateverXe's start wrapper stays fail-closed.
# The accelerator is not copied: without a 46A8 personality it never matches.
cp -R "$DONOR/AppleIntelTGLGraphicsFramebuffer.kext" "$DST/"
chmod -R u+w "$DST/AppleIntelTGLGraphicsFramebuffer.kext"
FB="$DST/AppleIntelTGLGraphicsFramebuffer.kext/Contents/Info.plist"
MATCH=$(/usr/libexec/PlistBuddy -c 'Print :IOKitPersonalities:N97Display13:IOPCIPrimaryMatch' "$FB")
case " $MATCH " in *" 0x46a88086 "*) ;; *)
    /usr/libexec/PlistBuddy -c "Set :IOKitPersonalities:N97Display13:IOPCIPrimaryMatch $MATCH 0x46a88086" "$FB" ;;
esac

# The AuxKC rejects OSBundleRequired Root/Safe Boot. Set Auxiliary before signing,
# so OCLP leaves the plist alone and the ad-hoc signature stays valid.
for K in AppleIntelTGLGraphicsFramebuffer AppleIntelTGLCompat; do
    /usr/libexec/PlistBuddy -c 'Set :OSBundleRequired Auxiliary' "$DST/$K.kext/Contents/Info.plist" 2>/dev/null ||
        /usr/libexec/PlistBuddy -c 'Add :OSBundleRequired string Auxiliary' "$DST/$K.kext/Contents/Info.plist"
done

codesign -f -s - "$DST/AppleIntelTGLGraphicsMTLDriver.bundle" "$DST/AppleIntelTGLImpostor.dylib" \
    "$DST/AppleIntelTGLCompat.kext" "$DST/AppleIntelTGLGraphicsFramebuffer.kext" 2>/dev/null
codesign -v "$DST/AppleIntelTGLGraphicsMTLDriver.bundle" "$DST/AppleIntelTGLCompat.kext" \
    "$DST/AppleIntelTGLGraphicsFramebuffer.kext"

rm -f "$OUT"
printf password | hdiutil create -quiet -srcfolder "$WORK/mnt" -volname "$VOL" -format UDZO \
    -encryption AES-256 -stdinpass "$OUT"
echo "built $OUT"
find "$DST" -maxdepth 1 -mindepth 1 -exec basename {} \;
