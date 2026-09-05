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
| `0006-unplayable-items-open-in-browser` | Radio shows and interviews were badged unplayable, then did nothing when clicked |
| `0007-sidebar-playlist-artwork` | Every sidebar playlist showed the same list glyph instead of its own cover |
| `0008-real-bugs-batch` | Four unrelated defects: a search box that filtered nothing, an unbounded recursion, a lyrics chain that dead-ended, and a rename that fired twice |

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

**0006** — whole rows of the home page ("Artists Take Over", "Listen to
Interviews", the radio shows carousel) rendered every card under a grey
slash-circle badge, and clicking one did nothing at all.

The badge is real and it was telling the truth: `mediaitem-square` marks an
item unavailable when `playParams.kind` is a `radioStation` with
`streamingKind == 1`, or when a video item arrives with no `playParams`.
Neither can be queued. The problem was that the badge was the *only* thing that
knew. `routeView` never asked, so a badged card still fell through to
`playMediaItemById`, which called `setQueue` with a key MusicKit does not
accept — failing silently. The card looked like a dead pixel.

The check itself had three faults. `typeof null` is `"object"`, so a null
`playParams` entered the radio branch and threw on `null.kind` — inside an
`async mounted()`, where it surfaced only as an unhandled rejection. The video
branch tested `tv-episodes`, but the home feed requests `tv-shows` and never
`tv-episodes`, so on the home page that half matched nothing. And
`streamingKind` appeared in exactly one place in the entire codebase: this
check. It gated nothing.

Both callers now share one `isUnplayableItem()` helper, so the badge and the
click can't drift apart, and an unplayable item opens in your browser — which
can play it — instead of failing quietly. Items with no URL fall through to
the old path rather than dead-ending. The badge stays, now with a "Show in
Apple Music" tooltip reusing the existing localised string.

Getting it into the *real* browser takes two more steps than it looks, and
both are easy to get wrong.

`window.open` is not enough. The main process installs a
`setWindowOpenHandler` that returns `action: "allow"` for any URL containing
`apple.com`, so an Apple Music link opens as an in-app Electron window — which
renders blank, because it can't play anything either. Every *other* URL there
goes to `shell.openExternal`, so the mechanism exists; Apple links are exactly
the case routed away from it. That rule is deliberately not narrowed here —
Apple's own sign-in flow depends on it.

Calling `shell.openExternal` from the renderer doesn't work either. The window
is created with `sandbox: true`, and a sandboxed `require("electron")` exposes
only a small subset — `ipcRenderer`, `contextBridge`, `webFrame` and friends.
`shell` is not among them, so it is silently `undefined` and the call throws.

So the renderer asks the main process, where `shell` does exist, over a
dedicated `open-external` channel. The handler checks the scheme before handing
the string to the OS. Because it touches the main process, this patch edits the
*compiled* `build/base/browserwindow.js` — that is what Electron actually runs
(`"main": "./build/index.js"`) — and mirrors the change into the `.ts` beside
it, so the shipped source doesn't contradict the shipped build.

`openExternal` respects your system default browser rather than hardcoding one.

(The pre-existing `window.open` for editorial links in `routeView` has the same
blind spot, but it's untouched here — one change at a time.)

The invariant worth knowing: **anything showing the badge today is what this
patch redirects.** Nothing else changes.

**0007** — the playlist sidebar drew the same `feather/list.svg` glyph beside
every entry, so twenty-six playlists looked identical. The cover you set is
visible only once you open the playlist.

Nothing needed fetching. `app.playlists.listing` — the array the sidebar is
already iterating — carries `attributes.artwork` on every entry; it is the same
object the playlist page uses for its header image. The component just never
drew it, because `icon` was assigned a constant in `mounted()`.

Artwork now comes from a computed that runs the URL through
`getMediaItemArtwork()`, which handles the `{w}`/`{h}` templating catalog
playlists use and applies `devicePixelRatio` itself. Folders have no artwork
and keep their folder icon.

Library artwork URLs are presigned and expire, so a stale one can 404. An
`@error` handler falls back to the original glyph rather than leaving a broken
image in the sidebar.

The stylesheet is the compiled `style.css` — that is what the app loads — with
the same rule mirrored into `style.less` beside it. The sizing deliberately
reuses `--iconSize`, the variable the glyph already used, so row height and the
12px gap are untouched.

**0008** — four unrelated defects, batched because they are all small and all
sit in files earlier patches already touch.

*The Add to Playlist search box filtered nothing.* `search()` populates
`playlistSorted` and has always done so, but the template iterates
`$root.getPlaylistFolderChildren('p.playlistsroot')` — so typing filtered an
array nothing rendered. A `displayedPlaylists` computed now returns the folder
listing when the query is empty (the previous behaviour, folders and all) and
the flat filtered list while searching. That also makes the existing
Enter-to-add shortcut reachable, since it keys off the same `playlistSorted`.

*`playMediaItemById` could recurse until the stack overflowed.* Its `catch`
called itself with identical arguments. Every async path in that method
resolves inside `.then()`, so the only way into the `catch` is a synchronous
throw — which an immediate, identical retry reproduces exactly. Nothing changes
between attempts, so the retry could never have succeeded; it now logs and
stops.

*The lyrics chain dead-ended instead of falling back to Apple Music.* With
`enable_mxm` on, `loadLyrics()` tries Musixmatch **first** — despite the comment
directly above it saying MXM is the fallback — and every Musixmatch failure path
hands off to QQ, whose first line is a config guard that returns immediately
when it is disabled. `enable_mxm: true` with `enable_qq: false`, a pairing the
settings UI offers freely, therefore produced no lyrics at all. Apple Music was
never tried, though `app.loadAMLyrics()` sat commented out beside each of those
sites. A `lyricsFallback()` helper now routes to QQ when it is enabled and to
Apple Music otherwise. It terminates: `loadAMLyrics`' own catch routes onward to
QQ (guarded) or MXM.

The symptom is worth recording, because it does not look like a lyrics problem.
`chrome-top.ejs` renders the lyrics button from `lyrics.length > 0`; the `v-else`
branch draws the same button at `opacity: 0.3` with `pointer-events: none`. So
the button appears present, swallows every click, and explains nothing.

*Renaming a playlist fired twice.* `rename()` is bound to both
`@keydown.enter` and `@blur`. Enter sets `renaming` false, which swaps the input
out via `v-else` and fires blur, which calls `rename()` again — two edit
requests per rename. Both bindings are wanted; a guard on `renaming` drops the
second entry.

One further one-liner: `sidebar-playlist.ejs` called `this.addFavorite(...)`,
which is defined on the root instance, not the component. It is unreachable —
the menu entry is `disabled: true, hidden: true` — so this fixes a latent throw,
nothing visible.

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
./scripts/rollback.sh app.asar.v5-confirm-class  # 0001 ... 0005
./scripts/rollback.sh app.asar.v6-open-external  # 0001 ... 0006
./scripts/rollback.sh app.asar.v7-sidebar-artwork # 0001 ... 0007
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
