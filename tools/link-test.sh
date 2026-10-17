#!/bin/bash
# Run on macOS Tahoe: let kmutil link kexts against the live boot + system
# kernel collections, without installing anything. Output goes to a temp dir.
# kmutil only accepts root-owned kexts, hence sudo for the copy.
# Usage: sudo tools/link-test.sh [--together] path/to/A.kext [path/to/B.kext ...]
#   default:    one collection per kext
#   --together: all kexts in one collection (for kexts that depend on each other)
set -uo pipefail
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
KC=/System/Library/KernelCollections
WORK=$(mktemp -d /tmp/link-test.XXXXXX)
together=0
[ "${1:-}" = --together ] && { together=1; shift; }

# link_group NAME KEXT... : copy the kexts, build one aux KC, check each one is inside
link_group() {
    local dir="$WORK/$1"; shift
    local args=() ids=() k id
    mkdir -p "$dir"
    for k in "$@"; do
        id=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$k/Contents/Info.plist")
        cp -R "$k" "$dir/"
        args+=(-p "$dir/$(basename "$k")" -b "$id")
        ids+=("$id")
    done
    chown -R 0:0 "$dir"
    echo "=== $* (${ids[*]})"
    kmutil create --allow-missing-kdk -z -x -n aux -a x86_64 \
        -B "$KC/BootKernelExtensions.kc" -S "$KC/SystemKernelExtensions.kc" \
        -A "$dir/aux.kc" "${args[@]}" 2>&1 | c++filt | grep -v 'No variant specified'
    if [ ! -e "$dir/aux.kc" ]; then
        echo "LINK FAILED"
        return
    fi
    for id in "${ids[@]}"; do
        if otool -l "$dir/aux.kc" | grep -q "entry_id $id "; then
            echo "LINKED OK    $id"
        else
            echo "NOT INCLUDED $id: kmutil built a collection without it"
        fi
    done
    echo "  -> $dir/aux.kc"
}

if [ $together = 1 ]; then
    link_group together "$@"
else
    for k in "$@"; do
        link_group "$(basename "$(dirname "$k")")-$(basename "$k")" "$k"
    done
fi
# hand the results back to the invoking user for inspection
[ -n "${SUDO_UID:-}" ] && chown -R "$SUDO_UID" "$WORK" && chmod -R u+rwX,go+rX "$WORK"
echo "results in $WORK"
