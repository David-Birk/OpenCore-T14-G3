#!/bin/bash
# Run on macOS Tahoe: let kmutil link a kext against the live boot + system
# kernel collections, without installing anything. Output goes to a temp dir.
# kmutil only accepts root-owned kexts, hence sudo for the copy.
# Usage: sudo tools/link-test.sh path/to/A.kext [path/to/B.kext ...]
set -uo pipefail
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
KC=/System/Library/KernelCollections
WORK=$(mktemp -d /tmp/link-test.XXXXXX)
for k in "$@"; do
    id=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$k/Contents/Info.plist")
    dir="$WORK/$(basename "$(dirname "$k")")-$(basename "$k")"
    mkdir -p "$dir" && cp -R "$k" "$dir/" && chown -R 0:0 "$dir"
    echo "=== $k ($id)"
    kmutil create --allow-missing-kdk -z -x -n aux -a x86_64 \
        -B "$KC/BootKernelExtensions.kc" -S "$KC/SystemKernelExtensions.kc" \
        -A "$dir/aux.kc" -p "$dir/$(basename "$k")" -b "$id" 2>&1 | c++filt | grep -v 'No variant specified'
    if [ ! -e "$dir/aux.kc" ]; then
        echo "LINK FAILED"
    elif otool -l "$dir/aux.kc" | grep -q "entry_id $id "; then
        echo "LINKED OK -> $dir/aux.kc"
    else
        echo "NOT INCLUDED: kmutil built a collection without $id"
    fi
done
# hand the results back to the invoking user for inspection
[ -n "${SUDO_UID:-}" ] && chown -R "$SUDO_UID" "$WORK" && chmod -R u+rwX,go+rX "$WORK"
echo "results in $WORK"
