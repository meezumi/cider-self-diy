<p align="center">
  <img src="assets/cider.png" alt="Cider" width="128" height="128">
</p>

<h1 align="center">cider-self-diy</h1>

<p align="center">
  <em>Personal patches for Cider 1.6.3, applied to <code>app.asar</code> locally.</em>
</p>

<p align="center">
  <a href="https://github.com/meezumi/cider-self-diy/releases"><img alt="Latest release" src="https://img.shields.io/github/v/release/meezumi/cider-self-diy?style=flat-square&labelColor=1c1c1e&color=fa2d48"></a>
  <a href="https://github.com/meezumi/cider-self-diy/tree/main/patches"><img alt="Patches" src="https://img.shields.io/github/directory-file-count/meezumi/cider-self-diy/patches?type=file&label=patches&style=flat-square&labelColor=1c1c1e&color=fa2d48"></a>
  <img alt="Cider 1.6.3" src="https://img.shields.io/badge/Cider-1.6.3-fa2d48?style=flat-square&labelColor=1c1c1e">
  <a href="LICENSE"><img alt="AGPL-3.0-only" src="https://img.shields.io/badge/license-AGPL--3.0--only-fa2d48?style=flat-square&labelColor=1c1c1e"></a>
</p>

---

Nobody else is actively maintaining this build of [Cider](https://cider.sh)
anymore, so I decided to take matters into my own hands and add patches as I
see fit. This is for personal use — ain't gonna pay for Cider v2.

Cider 1.x is no longer developed upstream. The build I run is **1.6.3**, from
the AUR (`cider 1.6.3.20260321034536-2`). When something in it is broken, the
options are to live with it or to fix it myself. This repo is the second
option, kept somewhere I won't lose it.

## What's here

Patches against Cider's `app.asar`, plus the scripts to apply them. Each patch
is one fix, in its own commit, numbered in `patches/`.

**Every patch is written up in full on the
[releases page](https://github.com/meezumi/cider-self-diy/releases)** — what
broke, why, and what the fix does. That's the documentation; this file is just
how to build and install.

## What this is not

Not a fork, not a redistribution, not a thing you should install because a
stranger on the internet said so. It patches a *specific* archive, identified
by checksum, on the assumption you have the same one.

## Requirements

- Cider **1.6.3** installed at `/opt/Cider`
- Node 22+ and `npm`
- The pristine `app.asar` this was built against:
  **`55c3c496efb53ad6f0c56351ba559923`**

That last one matters. The archive isn't in this repo (see below), and since
this is an AUR build of abandoned upstream, it is **not in pacman's cache**
either — there's no clean `pacman -S` to fall back on. If your checksum
differs, the patches may not apply, and the recorded build hashes won't match.
The manifest exists so you find that out immediately instead of shipping a
broken archive.

## Why there's no `.asar` in this repo

It's ~96 MiB of Cider's own AGPL source plus bundled `node_modules`. Committing
it would be redistributing upstream, which is a different act from publishing
my own patches. It also sits just under GitHub's 100 MiB hard limit, so git
would happily accept it and I'd regret it later.

The tradeoff: the repo has to be reproducible from patches alone. It is —
`scripts/build-all.sh` rebuilds the archive **bit for bit** from the pristine
one, verified by checksum.

## Usage

```sh
npm install                  # pins @electron/asar 4.2.0 -- see below
./scripts/build-all.sh       # base from /opt -> patch -> repack -> verify
```

`build-all.sh` copies the base archive out of `/opt` itself the first time, via
`fetch-base.sh`. It ends by checking the result against the manifest; if it
prints `MATCH`, you have the same bytes the matching release was cut from.

Then, **with Cider fully quit**:

```sh
./scripts/install.sh
```

`install.sh` and `rollback.sh` are the only things here that need **`sudo`**.
They write into `/opt/Cider/resources`, which is root-owned, so both call it
internally and will prompt for your password. That's three
`sudo install -m 0644 -o root -g root` lines between the two scripts, and
they're worth reading before you run them. Everything else — installing
dependencies, copying the base archive, patching, repacking, verifying — stays
inside `build/` and needs no elevation.

To go back:

```sh
./scripts/rollback.sh                              # pristine
./scripts/rollback.sh app.asar.v3-library-sort     # 0001 ... 0003
```

Each patch leaves a numbered rung in `build/`, so you can step back to any
point rather than all the way. `manifest/archives.md5` lists them all with
their checksums; each release names the rung it corresponds to.

`install.sh` refuses to run while Cider is alive, and refuses to install at all
unless a backup exists. It also drops a copy of the pristine archive next to
the installed one, so rollback still works if this checkout disappears.

### The base is two things

`fetch-base.sh` copies both `app.asar` **and** its `app.asar.unpacked/`
sidecar. Native `.node` binaries live in the sidecar because they can't be
`dlopen`'d from inside an archive. Extraction fails without it.

## Two traps worth writing down

**Pin the asar tool.** `@electron/asar` v4 requires a `**/` prefix on
`--unpack-dir`. Without it the glob matches almost nothing, the native modules
get packed *into* the archive, and it **still exits 0** — you get a
plausible-looking archive with broken AirPlay. Separately, 4.3.0 dedupes
identical files and produces a different layout than 4.2.0. Hence the exact
pin, and hence `verify.sh`.

**Verify against the real thing.** `verify.sh` checks the archive hash and all
65 unpacked files against the manifest, and optionally deep-compares every
packed file against a reference archive:

```sh
./scripts/verify.sh /opt/Cider/resources/app.asar
```

That's 9,518 entries and 9,453 byte comparisons. It's what catches a repack
that "worked".

## License

**AGPL-3.0-only.** Not a choice — Cider declares `AGPL-3.0` in its
`package.json`, and patches to it are derivative works.

Not affiliated with the Cider Collective or Apple. "Apple Music" is a trademark
of Apple Inc.

The logo above is Cider's own, reproduced to identify the application these
patches apply to. It is not mine and implies no endorsement.
