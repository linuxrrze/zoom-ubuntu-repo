# zoom-ubuntu-repo
Scripts to build a Debian/Ubuntu compatible repository from Zoom's published .deb files

This is hardcoded for zoom amd64 builds but can easily be modified for i386 if you want it.

# Using the hosted repository

The repository indices are built by GitHub Actions and published on GitHub Pages.
The .deb files are **not** copied: apt downloads them directly from `cdn.zoom.us`.
This works with apt's `mirror+` method (apt >= 1.6, i.e. Ubuntu 18.04 / Debian 10 or newer):
`mirrors.txt` sends requests for index files to GitHub Pages and requests for .deb files to Zoom's CDN.
apt still checks every downloaded .deb against the SHA256 in the signed index.

```
linux # wget -O /usr/share/keyrings/zoom-repo.asc https://linuxrrze.github.io/zoom-ubuntu-repo/zoom-repo.asc
linux # cp zoom-repo-example.list /etc/apt/sources.list.d/zoom.list
linux # apt update && apt install zoom
```

The repository started with the 10 newest Zoom versions; every new Zoom release is added
and old ones stay available, e.g. `apt install zoom=7.0.5.3034`.

## How the hosted repository is built

* `versions.txt` lists all known Zoom versions. Only versions with a `stanzas/<version>.control` file
  (their `Packages` entry) are published.
  `scripts/make-stanza.sh <version>` downloads the .deb to a temporary directory, verifies Zoom's signature and the package contents against it
  (keys in `keys/zoom/`) and writes the stanza with `Filename: prod/<version>/zoom_amd64.deb`.
* `scripts/build-index.sh` builds `dists/stable/...`, signs `Release` and writes `mirrors.txt`.
* `.github/workflows/update.yml` runs daily: `scripts/add-new-versions.sh` adds Zoom's latest version and any
  newer releases found via Flathub/AUR, then the indices are published. The run fails if Zoom's latest version
  can't be verified (e.g. after a signing key change: add the new key to `keys/zoom/`).
* To publish an older version, run `scripts/make-stanza.sh <version>` and commit the new stanza.
* Zoom only reveals its latest version. `scripts/known-versions.sh --missing` lists releases that are
  missing from `versions.txt`, based on the package history of Flathub and the AUR.

Setting up a fork: enable GitHub Pages with source "GitHub Actions" and store an armored, passphrase-less
signing key as secret `REPO_GPG_PRIVATE_KEY`
(`gpg --quick-gen-key "zoom-ubuntu-repo" ed25519 sign never`, then `gpg --armor --export-secret-keys <id>`).
Note that GitHub disables scheduled workflows after 60 days without repository activity.

# Self-hosted usage

Adapt the paths in zoom-update.cron for your needs and add it to your cron jobs:

```
linux # cp zoom-update.cron /usr/local/bin/zoom-update.cron
linux # echo '0 * * * * nobody /usr/local/bin/zoom-update.cron' > /etc/cron.d/zoom-update
```

# Background

Parsing the Zoom homepage got harder and harder, but here's what I got as a workaround from Zoom:
(mind the URL containing the current version number):

```
linux # wget --spider https://zoom.us/client/latest/zoom_amd64.deb | grep ^Location:
Spider mode enabled. Check if remote file exists.
--2022-02-01 07:49:17--  https://zoom.us/client/latest/zoom_amd64.deb
Resolving zoom.us (zoom.us)... 170.114.10.74
Connecting to zoom.us (zoom.us)|170.114.10.74|:443... connected.
HTTP request sent, awaiting response... 302 
Location: https://cdn.zoom.us/prod/5.9.3.1911/zoom_amd64.deb [following]
Spider mode enabled. Check if remote file exists.
--2022-02-01 07:49:17--  https://cdn.zoom.us/prod/5.9.3.1911/zoom_amd64.deb
Resolving cdn.zoom.us (cdn.zoom.us)... 99.84.89.248
Connecting to cdn.zoom.us (cdn.zoom.us)|99.84.89.248|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 56825388 (54M) [binary/octet-stream]
Remote file exists.
```

So in order to get the latest version number, do this:

```
linux # wget --spider https://zoom.us/client/latest/zoom_amd64.deb 2>&1 | grep ^Location: | sed -e 's/.*prod\/\(.*\)\/.*/\1/'
5.9.3.1911
```
