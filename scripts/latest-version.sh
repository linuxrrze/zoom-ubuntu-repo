#!/usr/bin/env bash
# Print the latest Zoom version, taken from the redirect of the "latest" URL
# (https://zoom.us/client/latest/... -> https://cdn.zoom.us/prod/<version>/...)

set -euo pipefail

location=$(curl -sfI https://zoom.us/client/latest/zoom_amd64.deb | grep -i '^location:' | tr -d '\r' || true)
version=$(echo "$location" | sed -n -e 's|.*/prod/\([^/]*\)/.*|\1|p')

if [ -z "$version" ]; then
    echo "ERROR: Unable to determine zoom version" >&2
    exit 1
fi
echo "$version"
