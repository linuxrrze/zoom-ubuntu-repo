#!/usr/bin/env bash

version="latest"
if [ "$1" != "" ]; then
    version=$1
fi

set -u
set -e

arch=amd64
deb_name=zoom_$arch.deb
if [ "$version" = "latest" ]; then
    # Redirects to https://cdn.zoom.us/prod/<version>/zoom_amd64.deb
    url=https://zoom.us/client/latest/$deb_name
else
    url=https://cdn.zoom.us/prod/$version/$deb_name
fi
rm -rf DEBIAN $deb_name
wget -q -O $deb_name "$url"
if ! "$(dirname "$0")"/scripts/verify-deb.sh $deb_name; then
    rm -f $deb_name
    exit 2
fi
dpkg -e $deb_name
version=$(cat DEBIAN/control | grep ^Version | cut -d\  -f2)
echo "Latest zoom version is $version"
target=zoom_${version}_$arch.deb
if [ -e $target ]; then
    echo "$target already exists. No action."
else
    echo "Adding $target to repository."
    mv $deb_name $target
    ./build-repo.sh
fi
rm -rf DEBIAN $deb_name
