#!/usr/bin/env bash
# Build the published part of the repository (indices, mirror list, key)
# from the stanzas in stanzas/, ordered as in versions.txt.
#
# Usage: scripts/build-index.sh <output dir> <base url> [gpg key id]
#
# Without a key id the Release file stays unsigned (for local testing,
# clients then need [trusted=yes]).

set -euo pipefail

out=${1:?usage: $0 <output dir> <base url> [gpg key id]}
base_url=${2:?usage: $0 <output dir> <base url> [gpg key id]}
key_id=${3:-}
base_dir=$(cd "$(dirname "$0")/.." && pwd)

dist="${out}/dists/stable"
bin="${dist}/main/binary-amd64"
rm -rf "${out}"
mkdir -p "${bin}"

while read -r version; do
    [ -n "$version" ] || continue
    stanza="${base_dir}/stanzas/${version}.control"
    if [ -f "$stanza" ]; then
        cat "$stanza"
        echo
    fi
done < "${base_dir}/versions.txt" > "${bin}/Packages"
gzip -9nc "${bin}/Packages" > "${bin}/Packages.gz"

checksums()
{
    echo "$1:"
    for f in main/binary-amd64/Packages main/binary-amd64/Packages.gz; do
        printf ' %s %s %s\n' "$($2 "${dist}/$f" | cut -d' ' -f1)" "$(stat -c%s "${dist}/$f")" "$f"
    done
}

{
    echo "Origin: zoom-ubuntu-repo"
    echo "Label: Zoom (unofficial)"
    echo "Suite: stable"
    echo "Codename: stable"
    echo "Date: $(date -Ru)"
    echo "Architectures: amd64"
    echo "Components: main"
    echo "Description: Zoom client packages, served from cdn.zoom.us"
    checksums MD5Sum md5sum
    checksums SHA256 sha256sum
} > "${dist}/Release"

if [ -n "$key_id" ]; then
    gpg --batch --yes --local-user "$key_id" --clearsign -o "${dist}/InRelease" "${dist}/Release"
    gpg --batch --yes --local-user "$key_id" -abs -o "${dist}/Release.gpg" "${dist}/Release"
    gpg --batch --armor --export "$key_id" > "${out}/zoom-repo.asc"
fi

# Index files come from this repository, .deb files from Zoom's CDN
printf '%s\ttype:index\nhttps://cdn.zoom.us/\ttype:deb\n' "${base_url%/}/" > "${out}/mirrors.txt"

echo "Built repository in ${out} ($(grep -c '^Package: ' "${bin}/Packages") packages)"
