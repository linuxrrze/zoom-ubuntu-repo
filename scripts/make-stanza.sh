#!/usr/bin/env bash
# Build the Packages stanza for one Zoom version without storing the .deb.
# The .deb is downloaded to a temp dir, its Zoom signature is verified and
# Filename: is rewritten to the path on cdn.zoom.us, where apt fetches it
# via the "type:deb" entry in mirrors.txt.
#
# Usage: scripts/make-stanza.sh <version>   (writes stanzas/<version>.control)

set -euo pipefail

version=${1:?usage: $0 <version>}
arch=amd64
deb_path="prod/${version}/zoom_${arch}.deb"
base_dir=$(cd "$(dirname "$0")/.." && pwd)
target="${base_dir}/stanzas/${version}.control"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -m 700 "$tmp/gnupg" "$tmp/deb"

echo "Fetching zoom ${version}"
wget -q -O "$tmp/deb/zoom_${arch}.deb" "https://cdn.zoom.us/${deb_path}"

# Zoom has used several signing keys over the years, accept any of them
gpg --quiet --homedir "$tmp/gnupg" --import "${base_dir}"/keys/zoom/*.asc 2>/dev/null
if ! gpg --quiet --homedir "$tmp/gnupg" --trust-model always --verify "$tmp/deb/zoom_${arch}.deb" 2>/dev/null; then
    echo "ERROR: signature check failed for zoom ${version}" >&2
    exit 2
fi

(cd "$tmp/deb" && dpkg-scanpackages --multiversion . 2>/dev/null) \
    | sed -e "s|^Filename: .*|Filename: ${deb_path}|" \
    | sed -e '/^$/d' > "$tmp/stanza"

if ! grep -q '^SHA256: ' "$tmp/stanza"; then
    echo "ERROR: dpkg-scanpackages produced no stanza for zoom ${version}" >&2
    exit 3
fi

mv "$tmp/stanza" "$target"
echo "Wrote ${target}"
