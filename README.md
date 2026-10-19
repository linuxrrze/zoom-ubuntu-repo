# zoom-ubuntu-repo
An unofficial APT repository for the Zoom desktop client on Debian/Ubuntu, plus scripts to run your own.

The repository indices are built by GitHub Actions and published on GitHub Pages. The .deb files are **not**
copied: apt downloads them directly from Zoom's CDN (`cdn.zoom.us`). Only amd64 is supported, Zoom publishes
no Linux .deb packages for other architectures.

# Installation

Requires apt 1.6 or newer (Ubuntu 18.04 / Debian 10 or later) on amd64.

```
sudo install -d -m 0755 /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/zoom-repo.asc https://linuxrrze.github.io/zoom-ubuntu-repo/zoom-repo.asc
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/zoom-repo.asc] mirror+https://linuxrrze.github.io/zoom-ubuntu-repo/mirrors.txt stable main" \
    | sudo tee /etc/apt/sources.list.d/zoom.list
sudo apt update
sudo apt install zoom
```

Check the repository key before trusting it: `gpg --show-keys /etc/apt/keyrings/zoom-repo.asc`
(on Ubuntu 18.04: `gpg --with-fingerprint /etc/apt/keyrings/zoom-repo.asc`) must show the fingerprint
`11C834440F15B1AFF6567534A6FEE25BF439A5B9`.

If Zoom was installed manually from a downloaded .deb before, `apt upgrade` now keeps it up to date.

## Older versions

The repository started with the 10 newest Zoom versions; every new release is added and old ones stay available:

```
apt list -a zoom                      # show all available versions
sudo apt install zoom=7.0.5.3034      # install a specific version
sudo apt-mark hold zoom               # keep it from being upgraded (undo with apt-mark unhold)
```

## Removal

```
sudo apt remove zoom
sudo rm /etc/apt/sources.list.d/zoom.list /etc/apt/keyrings/zoom-repo.asc
sudo apt update
```

# How it works

![Where the files live in both setups](docs/zoom-repo-setups.png)

(`docs/zoom-repo-setups.drawio` is the editable source; the PNG also opens as editable diagram in draw.io.)

* The `deb` line points apt to `mirrors.txt`, a list for apt's `mirror+` method: index files are fetched from
  GitHub Pages (`type:index`), .deb files from `https://cdn.zoom.us/` (`type:deb`).
* The index (`dists/stable/...`) is signed with the repository key and lists the SHA256 of every package, so apt
  rejects any .deb from the CDN that differs from the one verified when the version was added.
* Before a version is added, its .deb is downloaded once and checked against Zoom's own signature, including the
  package contents. The .deb itself isn't stored, only its index entry.

# Maintaining the repository

* `versions.txt` lists all known Zoom versions. Only versions with a `stanzas/<version>.control` file
  (their `Packages` entry) are published.
* `scripts/make-stanza.sh <version>` downloads the .deb to a temporary directory, verifies it with
  `scripts/verify-deb.sh` against Zoom's keys in `keys/zoom/` and writes the stanza with
  `Filename: prod/<version>/zoom_amd64.deb`.
* `scripts/build-index.sh` builds `dists/stable/...`, signs `Release` and writes `mirrors.txt`.
* `.github/workflows/update.yml` runs daily (and on pushes): `scripts/add-new-versions.sh` adds Zoom's latest
  version and all releases found via Flathub/AUR that are newer than the oldest published version, then the
  indices are published. A version is only recorded in `versions.txt` once it passed verification, so failures
  are retried every day.
* The run fails if Zoom's latest version can't be verified or zoom.us is unreachable; other failures show up as
  warnings. After a Zoom signing key change, add the new public key to `keys/zoom/` (Zoom serves older keys at
  `https://zoom.us/linux/download/pubkey?version=<x-y-z>`; check the fingerprint against Zoom's announcement).
  Versions that can never be verified belong in `versions-skipped.txt`.
* After 50 days without a new version the workflow pushes an empty keepalive commit, because GitHub disables
  scheduled workflows after 60 days without repository activity.
* To publish an older version, run `scripts/make-stanza.sh <version>` and commit the new stanza.
  Zoom only reveals its latest version; `scripts/known-versions.sh --missing` lists releases missing from
  `versions.txt`, based on the package history of Flathub and the AUR.

## Setting up your own copy (fork)

1. Fork the repository and enable GitHub Pages: Settings → Pages → Source: **GitHub Actions**.
2. Create a signing key without passphrase, in a temporary GnuPG home outside your checkout:
   ```
   export GNUPGHOME=$(mktemp -d)
   gpg --batch --passphrase '' --quick-gen-key "Zoom apt repository <you@example.org>" ed25519 sign 5y
   gpg --armor --export-secret-keys > "$GNUPGHOME/private.asc"
   ```
3. Store the content of `$GNUPGHOME/private.asc` as Actions secret `REPO_GPG_PRIVATE_KEY`
   (Settings → Secrets and variables → Actions). Keep an offline backup, then `rm -rf "$GNUPGHOME"`.
4. Run the "Update repository" workflow (Actions tab). It publishes the indices and the public key
   (`zoom-repo.asc`) to `https://<user>.github.io/<repository>/`.
5. Replace `linuxrrze.github.io/zoom-ubuntu-repo` and the key fingerprint in this README and in
   `zoom-repo-example.list` with your own.

The signing key of this repository expires on 2031-10-18. Before that, extend it (`gpg --quick-set-expire`),
update the secret and let users download `zoom-repo.asc` again.

# Self-hosted repository

To serve the .deb files from your own web server instead, adapt the paths in `zoom-update.cron`
(or set `ZOOM_CACHE` in `/etc/default/zoom-update`) and add it to your cron jobs:

```
linux # cp zoom-update.cron /usr/local/bin/zoom-update.cron
linux # echo '0 * * * * nobody /usr/local/bin/zoom-update.cron' > /etc/cron.d/zoom-update
```

Each download is checked against Zoom's signature (key from `https://zoom.us/linux/download/pubkey`), including
the package contents, before it is added. If Zoom changes its key, the script stops until you review the new key.
The repository is a flat one (`Packages`, `Packages.gz`, unsigned `Release`), see the commented line in
`zoom-repo-example.list`.

To add a single version manually from a checkout of this repository, run `./fetch.sh [<version>]`
in the repository directory (it uses the keys in `keys/zoom/`).

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
