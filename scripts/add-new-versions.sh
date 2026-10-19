#!/usr/bin/env bash
# Add new Zoom versions: build their stanzas and append them to versions.txt.
#
# Candidates are the latest version announced by Zoom plus all versions known
# to Flathub/AUR (scripts/known-versions.sh) that are newer than the oldest
# published version, aren't published yet and aren't listed in
# versions-skipped.txt. Flathub/AUR often lag behind Zoom, so releases that
# appear there late are still picked up. A version is only recorded in
# versions.txt once its stanza was built, so failures are retried next run.
#
# Prints the added versions to the file given in $ADDED_FILE (if set).
# Exit code 0: all fine (Flathub/AUR failures are only warnings)
#           1: Zoom's latest version couldn't be verified or downloaded
#           2: Zoom's latest version couldn't be determined (zoom.us unreachable)

set -euo pipefail

base_dir=$(cd "$(dirname "$0")/.." && pwd)
cd "$base_dir"

status=0

if latest=$(scripts/latest-version.sh); then
    echo "Latest zoom version is $latest"
else
    echo "::error::Couldn't determine Zoom's latest version (zoom.us unreachable?)"
    latest=""
    status=2
fi

oldest_published=$(ls stanzas/ | sed -n -e 's/\.control$//p' | sort -V | head -n 1)
if known=$(scripts/known-versions.sh); then
    # Versions sorting after the oldest published one (sort -V, as dpkg would order them)
    third_party=$(printf '%s\n' "$oldest_published" $known | sort -uV | awk -v oldest="$oldest_published" 'found { print } $0 == oldest { found = 1 }')
else
    echo "::warning::Couldn't read versions from Flathub/AUR"
    third_party=""
fi

skipped=$(sed -e 's/#.*//' -e 's/[[:space:]]//g' -e '/^$/d' versions-skipped.txt 2>/dev/null || true)

for version in $(printf '%s\n' $latest $third_party | sort -uV); do
    [ -f "stanzas/${version}.control" ] && continue
    if echo "$skipped" | grep -qxF "$version"; then
        continue
    fi
    if scripts/make-stanza.sh "$version"; then
        grep -qxF "$version" versions.txt || echo "$version" >> versions.txt
        [ -z "${ADDED_FILE:-}" ] || echo "$version" >> "$ADDED_FILE"
    elif [ "$version" = "$latest" ]; then
        echo "::error::Couldn't add zoom $version (latest version announced by Zoom). New signing key? Add it to keys/zoom/."
        status=1
    else
        echo "::warning::Couldn't add zoom $version (found via Flathub/AUR). If it can never be verified, list it in versions-skipped.txt."
    fi
done

exit $status
