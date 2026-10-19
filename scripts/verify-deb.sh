#!/usr/bin/env bash
# Verify a Zoom .deb: it carries a dpkg-sig manifest (_gpgbuilder), a signed
# list of MD5/SHA1 hashes of the other archive members. Check the signature
# with Zoom's keys (they have used several), then the members against the list.
#
# Usage: scripts/verify-deb.sh <file.deb> [key file...]   (default: keys/zoom/*.asc)
#
# zoom-update.cron carries a copy of this check (it is installed standalone).

set -euo pipefail

deb=${1:?usage: $0 <file.deb> [key file...]}
shift
base_dir=$(cd "$(dirname "$0")/.." && pwd)
[ $# -gt 0 ] || set -- "${base_dir}"/keys/zoom/*.asc

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -m 700 "$tmp/gnupg"

gpg --quiet --homedir "$tmp/gnupg" --import "$@" 2>/dev/null
if ! ar p "$deb" _gpgbuilder > "$tmp/manifest.asc" 2>/dev/null || \
   ! gpg --quiet --homedir "$tmp/gnupg" --trust-model always --status-fd 3 \
        --output "$tmp/manifest" --decrypt "$tmp/manifest.asc" 3> "$tmp/status" 2>/dev/null || \
   ! grep -q '^\[GNUPG:\] VALIDSIG ' "$tmp/status"; then
    echo "ERROR: signature check failed for $deb" >&2
    exit 2
fi
members=$(ar t "$deb" | grep -vx _gpgbuilder)
for member in $members; do
    md5=$(ar p "$deb" "$member" | md5sum | cut -d' ' -f1)
    sha1=$(ar p "$deb" "$member" | sha1sum | cut -d' ' -f1)
    size=$(ar p "$deb" "$member" | wc -c)
    if ! grep -qE "^[[:space:]]+${md5} ${sha1} ${size} ${member}\$" "$tmp/manifest"; then
        echo "ERROR: ${member} doesn't match the signed manifest in $deb" >&2
        exit 2
    fi
done
if [ "$(grep -cE '^[[:space:]]+[0-9a-f]{32} [0-9a-f]{40} ' "$tmp/manifest")" != "$(echo "$members" | wc -l)" ]; then
    echo "ERROR: archive members don't match the signed manifest in $deb" >&2
    exit 2
fi
