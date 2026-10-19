#!/usr/bin/env bash
# Add new Zoom versions to versions.txt and build their stanzas.
#
# Candidates are the latest version announced by Zoom plus all versions known
# to Flathub/AUR (scripts/known-versions.sh) that are newer than the newest
# entry in versions.txt, so releases between two runs aren't missed.
#
# Exit code 0: all fine, 1: Zoom's latest version couldn't be added.
# Failures of versions only known to Flathub/AUR are reported as warnings.

set -euo pipefail

base_dir=$(cd "$(dirname "$0")/.." && pwd)
cd "$base_dir"

latest=$(scripts/latest-version.sh)
echo "Latest zoom version is $latest"

newest_known=$(sort -V versions.txt | tail -n 1)
if third_party=$(scripts/known-versions.sh); then
    third_party=$(echo "$third_party" | sort -V | awk -v n="$newest_known" '
        BEGIN { split(n, b, ".") }
        { split($0, a, "."); for (i = 1; i <= 4; i++) { if (a[i] + 0 != b[i] + 0) { if (a[i] + 0 > b[i] + 0) print; next } } }')
else
    echo "::warning::Couldn't read versions from Flathub/AUR"
    third_party=""
fi

latest_failed=0
for version in $(printf '%s\n' "$latest" $third_party | sort -uV); do
    grep -qxF "$version" versions.txt || echo "$version" >> versions.txt
    [ -f "stanzas/${version}.control" ] && continue
    if ! scripts/make-stanza.sh "$version"; then
        if [ "$version" = "$latest" ]; then
            echo "::error::Couldn't add zoom $version (latest version announced by Zoom)"
            latest_failed=1
        else
            echo "::warning::Couldn't add zoom $version (found via Flathub/AUR)"
        fi
    fi
done

exit $latest_failed
