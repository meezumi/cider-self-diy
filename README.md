# cider-self-diy

Nobody else is actively maintaining this build of [Cider](https://cider.sh)
anymore, so I decided to take matters into my own hands and add patches as I
see fit. This is for personal use — ain't gonna pay for Cider v2 .

Cider 1.x is no longer developed upstream. The build I run is **1.6.3**, from
the AUR (`cider 1.6.3.20260321034536-2`). When something in it is broken, the
options are to live with it or to fix it myself. This repo is the second
option, kept somewhere I won't lose it.

## What's here

Patches against Cider's `app.asar`, plus the scripts to apply them. Each patch
is one fix, in its own commit.

| Patch | What it fixes |
|---|---|
| `0001-sidebar-playlist-track-present-label` | "(Track present)" never appeared in Add to Playlist |
| `0002-vueapp-trackmapping-after-add` | …and then went stale the moment you used it |
| `0003-library-search-preserves-sort-order` | Searching your library threw away the sort order |
| `0004-playlist-description-editable` | Renaming a playlist could throw; descriptions were unreachable |
| `0005-mark-library-confirm-button` | Add/Remove from Library's confirm step had no CSS handle |

**0001** — the label was set once in `mounted()`. Vue 2 mounts children before
parents, so the `relateMediaItems` prop was still its empty default every time
that ran, and the flag never became true. Rewritten as a `computed`, which
re-evaluates when the prop actually lands.

**0002** — `addToPlaylist()` POSTs and then refreshes only the playlist page
you happen to be looking at. It never updates `playlists.trackMapping`, so a
track you just added showed no label until the next full library scan or a
restart. Now the mapping is updated in place on success. (Vue 2 can't detect
plain property addition, so new keys go in via `$set`.)

**0003** — the search boxes on Library → Albums and Library → Artists were
bound as `@input="$root.searchLibraryAlbums"`, with no argument list. Vue hands
a bare method reference the DOM event, so the `index` parameter arrived as an
`InputEvent`. `sorting[index]` and `sortOrder[index]` were then `undefined`,
both compared values collapsed to `""`, and neither the `asc` nor the `desc`
branch matched — so the comparator returned `undefined`, which `Array.sort`
treats as 0. Typing one character into either box silently dropped you back to
raw library order, and it stayed that way until you touched the sort dropdown.
Now they pass the index each page already uses elsewhere: `1` for albums, `0`
for artists.

The Songs page doesn't have this bug: `searchLibrarySongs()` takes no index and
reads `cfg.libraryPrefs.songs` directly. It's the same function repaired — the
albums and artists copies were left behind, comment and all ("make a copy of
searchLibrarySongs except use Albums instead of Songs").

**0004** — two faults in the same place. `editPlaylist()` is bound to
blur/change/enter on the playlist *name* field, and it unconditionally read
`data.attributes.description.standard`. `newPlaylist()` POSTs only `{ name }`,
so every playlist created in Cider has no `description` at all and that read
threw. The rename itself had already gone out on the line above, so the name
changed on Apple's side while the sidebar kept the old one and the field stayed
stuck in edit mode.

The second fault is why nobody noticed the first: the description block is
`v-if`-gated on a description already existing, so a playlist without one had no
click target and no way to get a description in the first place. There is an
`action.editDescription` string sitting in `translations.js`, localised into 31
languages and referenced from nowhere — the affordance was planned and never
wired up. It's now an entry in the playlist's "…" menu, shown only for
`canEdit` library playlists, and the editor seeds an empty description via
`$set` so the input has something reactive to bind to.

Also removed a duplicate `editPlaylistDescription` — the file defined it twice,
once to save and once to open the editor. The later definition silently won, so
the saving one was dead code and the working behaviour depended on declaration
order.

**0005** — adds the class `md-btn-confirm` to the Add/Remove from Library
confirm button. Nothing else; no behaviour change.

That button is the second step of a two-step control, and it is a *separate*
`<button>` from the resting one — same classes, same icon class, same inline
`min-width`. The only thing that differs between the two states is the label
text node. A theme that renders these controls icon-only (mine does, by
collapsing the label with `font-size: 0`) therefore makes the armed state
pixel-identical to the resting one, and the button looks dead.

No stylesheet can tell them apart: `confirm` touches nothing else in the DOM,
and Vue renders the inactive branch as a comment node, so even `:nth-child`
sees both at the same index. A marker class is the smallest thing that makes
the state addressable at all.

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
./scripts/fetch-base.sh      # copies the base archive out of /opt
./scripts/build-all.sh       # extract -> patch -> repack -> verify
```

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
./scripts/rollback.sh                            # pristine
./scripts/rollback.sh app.asar.v1-sidebar-only   # just 0001
./scripts/rollback.sh app.asar.v2-trackmapping   # 0001 + 0002
./scripts/rollback.sh app.asar.v3-library-sort   # 0001 + 0002 + 0003
./scripts/rollback.sh app.asar.v4-playlist-desc  # 0001 ... 0004
```

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
