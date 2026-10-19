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

# The .deb carries a dpkg-sig manifest (_gpgbuilder): a signed list of
# MD5/SHA1 hashes of the other archive members. Check the signature with
# Zoom's keys (they have used several), then the members against the list.
gpg --quiet --homedir "$tmp/gnupg" --import "${base_dir}"/keys/zoom/*.asc 2>/dev/null
deb="$tmp/deb/zoom_${arch}.deb"
if ! ar p "$deb" _gpgbuilder > "$tmp/manifest.asc" 2>/dev/null || \
   ! gpg --quiet --homedir "$tmp/gnupg" --trust-model always --status-fd 3 \
        --output "$tmp/manifest" --decrypt "$tmp/manifest.asc" 3> "$tmp/status" 2>/dev/null || \
   ! grep -q '^\[GNUPG:\] VALIDSIG ' "$tmp/status"; then
    echo "ERROR: signature check failed for zoom ${version}" >&2
    exit 2
fi
members=$(ar t "$deb" | grep -vx _gpgbuilder)
for member in $members; do
    md5=$(ar p "$deb" "$member" | md5sum | cut -d' ' -f1)
    sha1=$(ar p "$deb" "$member" | sha1sum | cut -d' ' -f1)
    size=$(ar p "$deb" "$member" | wc -c)
    if ! grep -qE "^[[:space:]]+${md5} ${sha1} ${size} ${member}\$" "$tmp/manifest"; then
        echo "ERROR: ${member} doesn't match the signed manifest for zoom ${version}" >&2
        exit 2
    fi
done
if [ "$(grep -cE '^[[:space:]]+[0-9a-f]{32} [0-9a-f]{40} ' "$tmp/manifest")" != "$(echo "$members" | wc -l)" ]; then
    echo "ERROR: archive members don't match the signed manifest for zoom ${version}" >&2
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
