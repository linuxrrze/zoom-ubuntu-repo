#!/usr/bin/env bash
# Print all Zoom Linux versions (with build number) that other packagers have
# shipped, taken from the git history of the Flathub (us.zoom.Zoom) and AUR
# (zoom) packages. Zoom itself only reveals its latest version.
#
# Usage: scripts/known-versions.sh            all known versions, sorted
#        scripts/known-versions.sh --missing  only those missing in versions.txt

set -euo pipefail

base_dir=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

git clone -q --bare https://github.com/flathub/us.zoom.Zoom.git "$tmp/flathub"
git clone -q --bare https://aur.archlinux.org/zoom.git "$tmp/aur"

{
    # Flathub: download URLs contain the full version
    git -C "$tmp/flathub" log -p --format= -- us.zoom.Zoom.yaml us.zoom.Zoom.json \
        | grep -E '^\+' | grep -oE 'cdn\.zoom\.us/prod/[0-9.]+/' | sed -e 's#.*/prod/##' -e 's#/$##'
    # AUR: version is split into pkgver and _subver (build number)
    git -C "$tmp/aur" log -p --format='format:@@ %h' -- PKGBUILD \
        | awk '/^@@ /{if (p && s) print p "." s; p = ""; s = ""}
               /^\+pkgver=/{sub(/^\+pkgver=/, ""); p = $0}
               /^\+_subver=/{sub(/^\+_subver=/, ""); s = $0}
               END{if (p && s) print p "." s}'
} | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort -uV > "$tmp/known"

if [ "${1:-}" = "--missing" ]; then
    grep -vxF -f "${base_dir}/versions.txt" "$tmp/known" || true
else
    cat "$tmp/known"
fi
