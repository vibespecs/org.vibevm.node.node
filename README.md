# Node.js application package

This package installs [Node.js](https://nodejs.org/) — the official upstream
build, unmodified — as a portable Vibe user application, and puts `node`,
`npm` and `npx` on PATH. It contains no binaries: each installation downloads
one pinned archive and verifies it against its SHA-256 digest.

| Archive | From | Digest from |
| --- | --- | --- |
| `node-v<version>-<platform>.tar.gz` / `.zip` | `https://nodejs.org/dist/v<version>/` | `SHASUMS256.txt` of that release |
| `node-v<version>.tar.gz` (the source build) | the same directory | the same document |

```text
vibe install -g org.vibevm.node/node
node --version
npm --version
npx --version
```

Every Linux and macOS target also has a **source** installer option beside its
prebuilt one — [Building from source](#building-from-source-what-nvm-install--s-is)
— under its own platform id, so it is asked for and never detected: the line
above goes on installing the prebuilt build, as it always did.

## One template, every release

`vibe.toml` on `master` is a **template manifest** (`[package] template =
true`): it is written once with `{version}` and `{sha256:…}` variables plus a
`[template]` declaration naming where the versions and the digests come from,
and Vibe renders it on your machine, at resolution time, for whichever version
you ask for. Every Node.js release from 12.0.0 up is therefore installable
from this one file, and moving to a new release needs no change here at all.

| What | Where it comes from |
| --- | --- |
| the versions | `https://nodejs.org/dist/index.json` (`strip_prefix = "v"`, `min = "12.0.0"`) |
| the digests | `https://nodejs.org/dist/v<version>/SHASUMS256.txt` |
| the channels | the records' own `lts` field: `lts` and `lts/<codename>` |

```text
vibe install -g org.vibevm.node/node@lts        # the newest LTS release
vibe install -g org.vibevm.node/node@lts/jod    # the newest of one LTS line
vibe install -g org.vibevm.node/node@24         # any version requirement
vibe install -g org.vibevm.node/node@=12.0.0    # one exact release
```

The template itself has a version of its own — the **template revision**,
`1.2.0`, carried by the tag `v1.2.0`. A revision is never a Node.js version:
it is excluded from the version domain, and bumping it is how a fix to the
manifest's shape reaches users without republishing anything per release.

Two Node.js releases also stay **published concretely**, each as its own tag
with the manifest the retired generator rendered:

| Version | Tag | Line |
| --- | --- | --- |
| 24.22.2 | `v24.22.2` | current |
| 22.23.4 | `v22.23.4` | maintenance |

A concretely published version always wins over the template's rendering of
the same version, and the template is then not rendered for it at all — which
is how one release can be hand-fixed without touching the template, and why
these two tags are kept rather than deleted.

Both can be installed at the same time. They share the `node` slot, so one of
them answers `node` at a time and the other waits:

```text
vibe app alternatives node                 # every installed provider
vibe app use node org.vibevm.node/node@22.23.4
node -v                                   # v22.23.4
vibe app use node org.vibevm.node/node@24.22.2
node -v                                   # v24.22.2
```

Node's own directory goes on PATH whole, not three per-command proxies: the
option declares `path_dirs`, and Vibe links the payload's `bin` (the payload
root on Windows, where `node.exe` and `npm.cmd` live) at
`<settings>/opt/paths/node/0` and puts that link directory on your durable
PATH. Everything in it is therefore reachable — including the commands
`npm install -g` writes there *after* Vibe is done, which a fixed proxy set
could never expose.

```text
npm install -g prettier
prettier --version        # npm wrote it into the payload; the link exposes it
```

One link per slot, so two installed versions never collide — and neither do
their globals: `npm install -g` writes into the payload of whichever version
is current, so a package installed under 22 is not on PATH under 24 and the
two never share a `node_modules`. `vibe app use node --none` removes the link
so the system's own `node` answers again until `vibe app use node --default`.

This is the Node.js another Vibe application can run on. A package whose
launcher is declared `executable = "command:node"` runs whichever `node` is on
PATH when it starts — the system's, or this one, reached through that link.

## Version files, and npm as Node's own ecosystem

The package declares the two files a Node project pins its runtime with, and
npm as the runtime's own package ecosystem. Both are declarations Vibe reads;
neither puts anything npm-shaped inside Vibe.

```text
echo 22.9.0 > .nvmrc
cd .                             # the prompt hook switches to 22.9.0
vibe app env --project           # or, without a hook, these lines
vibe app use node org.vibevm.node/node@22.9.0 --write-version-file
```

| Declaration | What it is |
| --- | --- |
| `[[application.version_file]]` `format = "plain"` | `.nvmrc`, then `.node-version` — one bare version or channel name, which is what nvm, nodenv and fnm all read |
| `[[application.ecosystem]]` `id = "npm"` | `install`, `list`, `remove` and `self_upgrade`, each one `recipe` step under `ecosystem/` |

What the adapter buys, in commands:

```text
vibe app extras list node                  # what this version carries
vibe app extras add node typescript        # and in every new version
vibe app extras self-upgrade node          # the newest npm this line runs
vibe app migrate node 20.18.0 22.9.0 --only ecosystem:npm   # carry globals
```

Three decisions in those scripts, each written in the script itself:

- **`list` leaves out `npm` and `corepack`.** Both live inside every Node
  distribution's own `lib/node_modules`: they are the runtime's managers, not
  packages anybody added. Reporting them would make a fresh installation look
  as though it already carried two globals, and carrying them into another
  version would overwrite that version's own bundled pair.
- **`self_upgrade` installs the newest npm *this* node line can run**, from
  upstream's own compatibility ceilings — `npm@latest` on an older runtime
  installs an npm that cannot start.
- **`self_upgrade` succeeds when the upgrade could not be fetched but npm
  still runs**, and fails when npm does not run. Its question is whether this
  installation has a usable package manager, never whether the network was up.

The package recommends no npm package of its own, so a fresh installation
carries exactly what upstream ships. What *you* want in every new version is
yours to declare, in `[slot.node.extras.npm]` of `~/.vibe/config.toml` — the
general form of what `$NVM_DIR/default-packages` was, and
`vibe app extras import node $NVM_DIR/default-packages` moves an existing one
over in one command.

## Targets

| Installer option | `--platform` / `--arch` | Archive | Kind |
| --- | --- | --- | --- |
| `linux-x64` | `linux` / `x86_64` | `node-v<version>-linux-x64.tar.gz` | prebuilt |
| `linux-arm64` | `linux` / `aarch64` | `node-v<version>-linux-arm64.tar.gz` | prebuilt |
| `linux-musl-x64` | `linux-musl` / `x86_64` | `node-v<version>-linux-x64-musl.tar.gz` | prebuilt |
| `macos-x64` | `macos` / `x86_64` | `node-v<version>-darwin-x64.tar.gz` | prebuilt |
| `macos-arm64` | `macos` / `aarch64` | `node-v<version>-darwin-arm64.tar.gz` | prebuilt |
| `windows-x64` | `windows` / `x86_64` | `node-v<version>-win-x64.zip` | prebuilt |
| `windows-arm64` | `windows` / `aarch64` | `node-v<version>-win-arm64.zip` | prebuilt |
| `source-linux-x64` | `linux-source` / `x86_64` | `node-v<version>.tar.gz` | source |
| `source-linux-arm64` | `linux-source` / `aarch64` | `node-v<version>.tar.gz` | source |
| `source-macos-x64` | `macos-source` / `x86_64` | `node-v<version>.tar.gz` | source |
| `source-macos-arm64` | `macos-source` / `aarch64` | `node-v<version>.tar.gz` | source |

Vibe picks the option of the host's platform and architecture and asks when it
cannot decide. A musl system (Alpine and others) is detected as `linux` like
any other Linux, so install there with `vibe install -g org.vibevm.node/node
--platform linux-musl`.

Only `linux`, `macos` and `windows` are detected; `linux-musl`, `linux-source`
and `macos-source` are "selectable only explicitly" (PROP-059
`#installer-options`). That is what keeps the bare `vibe install -g
org.vibevm.node/node` deciding by itself on every host: the four source rows
sit under platform ids nothing detects, so they never compete with the
prebuilt row of the pair the host actually is, and a source build is something
you ask for.

Three of the seven prebuilt rows are declared `template_optional = true`, because
upstream has not built them for every release in the window — measured over
the 406 releases from 12.0.0 to 26.13.0:

| Row | Absent for | First release that has it |
| --- | --- | --- |
| `linux-musl-x64` | 389 of 406 | 22.23.3, and still missing in places above it |
| `macos-arm64` | 132 of 406 | 16.0.0 (Apple silicon) |
| `windows-arm64` | 234 of 406 | 19.9.0 |

Such a row is **dropped from the rendered manifest** when the release's
`SHASUMS256.txt` does not carry its archive, so an old version installs with
the targets it really has instead of pointing at an archive that does not
exist; asking for a dropped target refuses by name (`no_option`). Every other
row is required, and a release missing one of those is a loud refusal rather
than a quiet manifest. All seven are present together only from 26.8.0 up.

The four source rows are never optional: `node-v<version>.tar.gz` is in every
release's `SHASUMS256.txt`, all the way down to 12.0.0. So a source build is
also the way to get a target upstream never shipped a binary for — Node 14 on
Apple silicon, say, where `macos-arm64` is dropped from the rendered manifest
but `source-macos-arm64` is not.

## Building from source: what `nvm install -s` is

```text
vibe install -g org.vibevm.node/node@22.23.4 --platform linux-source
vibe install -g org.vibevm.node/node@22.23.4 --platform linux-source --set jobs=6
vibe install -g org.vibevm.node/node@22.23.4 --platform macos-source --installer source-macos-arm64
```

`--platform linux-source` is the whole of it on a 64-bit host: that platform
has one row per architecture and the host's own architecture is still detected
inside it, so exactly one option remains. `--installer` names the row when you
want to be explicit, or when you are installing for the architecture you are
not on.

The source options fetch Node's **own source tarball** from the same release
directory the prebuilt archives come from, verify it against the same
`SHASUMS256.txt`, and then do what `nvm install -s` does — `./configure
--prefix`, `make -j`, `make -j install` (nvm's `nvm_install_source`). What
comes out is the same tree the official tarball carries — `make install
--prefix` is how upstream makes it — so the payload layout, `path_dirs =
["bin"]` and all three launchers are the prebuilt rows' unchanged, and nothing
downstream has to know which row produced the payload.

| | |
| --- | --- |
| Platforms | `linux-source` and `macos-source`, both architectures — explicit platform ids, because a source build is a choice and not a detected default. There is no Windows row: nvm builds from source on POSIX only |
| Archive | `node-v<version>.tar.gz`. nvm prefers `.tar.xz` where the release supports it (`nvm_get_artifact_compression`); this package takes `.tar.gz`, which every release in the window has and which the same digest document lists — so the source rows need no digest variable the template did not already have |
| Steps | `source` (fetch and verify, `needs = ["network"]`), then `build` (the recipe `recipes/build-from-source.sh`) |
| Result | `owned` — the build writes `$VIBE_OUT`, which Vibe places in a storage library. The tree is relocatable: `make install` writes `bin/npm`, `bin/npx` and `bin/corepack` as relative symbolic links, and `node` finds its own tree from `process.execPath` |

### The one parameter: `jobs`

| | |
| --- | --- |
| Spelling | `--set jobs=N`, an `integer` between 0 and 1024 |
| Default | `0`, which means *nvm's own default*: one less than the number of cores when there are more than two, otherwise a single job (`nvm_get_make_jobs`) |

A manifest default is a constant and the core count is a host fact, so `0` is
the honest way to spell "whatever nvm would have chosen": the recipe counts the
cores itself and says what it decided. `--set jobs=6` is an exact answer and is
used as given; `jobs` reaches the recipe as `VIBE_PARAM_JOBS`, the environment
channel PROP-065 `#parameters` defines, never interpolated into a command.

### The toolchain it needs, and what happens when it is missing

The `build` step declares `needs = ["command:make", "command:python3",
"command:cc", "command:c++"]` — Node's own build requirements, and the exact
programs its `configure` reaches for. Vibe checks them **before the
installation starts**, so a machine without a compiler does not discover it
after fetching and unpacking 102 MiB of source:

```text
✗ need_unmet  step `build` of `org.vibevm.node/node@22.23.4` needs `command:cc`,
              which this host does not provide; nothing was downloaded or run
  fix   provide command:cc and retry, or select another installer option
  see   spec://org.vibevm.core/vibevm/common/PROP-065#needs
```

The command exits `2` — refused before any effect — and leaves nothing behind.
`vibe app plan … --platform linux-source` answers the same way without
installing anything, which is how to ask a machine whether it could build
before asking it to.

The compiler is Node's own default, `cc` and `c++`. An exported `CC` / `CXX`
reaches the recipe like any other inherited variable and wins, which is also
where nvm ends up (`CC=${CC:-cc} CXX=${CXX:-c++}`).

## How the three launchers run

The archive is unpacked with its own top-level directory stripped
(`payload_root`), so the payload is Node's own tree: `bin/node` and
`lib/node_modules/npm/` on Linux and macOS, `node.exe` and
`node_modules/npm/` on Windows. A source build produces the same tree, because
`make install --prefix` is what upstream runs to make the tarball — which is
why the source options repeat these three rows unchanged.

All three launchers run the payload's own `node` executable:

| Launcher | Executable | Arguments |
| --- | --- | --- |
| `node` | the payload's `node` | — |
| `npm` | the payload's `node` | `npm-cli.js` of the bundled npm |
| `npx` | the payload's `node` | `npx-cli.js` of the bundled npm |

That is what Node's own `npm` wrapper does. No launcher depends on a shell
script, on a `.cmd` file or on a `node` already on PATH, so the same three
rows work on every target, and `npm` keeps working on Windows without
PowerShell execution policy entering the picture.

These launchers are what `vibe app run org.vibevm.node/node npm` uses, and
what a graphical client lists. PATH is the other surface, and the one above:
it is the payload directory itself, so `node`, `npm`, `npx`, `corepack` and
every later global install are all reached the way Node expects.

The Linux and macOS tarballs carry three relative symbolic links
(`bin/npm`, `bin/npx`, `bin/corepack`) pointing inside the payload; Vibe
1.0.12 unpacks those, and the link directory exposes them as they are.

## Closed networks

The same package, unedited, installs where nodejs.org cannot be reached. The
administrator mirrors the registry into the corporate one and places the
archives in the machine's `[artifacts] packages` drop; every archive is still
verified against the digest in `vibe.toml`.

1. Mirror the package (on a connected machine):

   ```text
   vibe registry mirror vibespecs --into <corporate monorepo url> --package org.vibevm.node/node
   ```

2. Download the archives of the targets you need from the Node.js release above
   and place them in the drop. `vibe artifacts where org.vibevm.node/node`
   prints, for every installer option, the exact file names, digests and
   destination paths; the layout is

   ```text
   <drop>/org.vibevm.node/node/24.22.2/node-v24.22.2-linux-x64.tar.gz
   <drop>/org.vibevm.node/node/24.22.2/node-v24.22.2-win-x64.zip
   …
   ```

3. A site profile names the registry, the drop and the source policy, for
   example

   ```toml
   schema = 1
   name = "example-site"

   [[registry]]
   name = "corp"
   type = "monorepo"
   url = "ssh://git.example.internal/vibe/registry.git"

   [source_policy]
   exclude_hosting = ["github", "gitverse"]

   [artifacts]
   packages = "/srv/vibe-drop"
   ```

   applied with `vibe self apply site.toml`; then `vibe install -g
   org.vibevm.node/node` reads the package from `corp` and the archive from the
   drop, with no connection to the public hosts. It also works with
   `--offline`.

With a proxy instead of a drop, the archive is downloaded through the
`[proxy]` the site profile declares (`mode = "px"` with a PAC file is
supported).

Because the manifest is a template, a closed network also has to reach the
two documents it declares — the version list and the release's checksum
document. Both are ordinary remappable artifacts (`template-index` and
`template-digest`), so one `[[remap]]` row relocates them onto a mirror or
the filesystem, with the declaration itself unchanged:

```toml
[[remap]]
prefix = "https://nodejs.org/dist/"
path = "/srv/node-dist"      # holds index.json and v<version>/SHASUMS256.txt
reason = "the site's mirror of the Node.js release host"
```

`vibe remap explain` answers for those two fetches like any other, and
`--offline` then resolves from
`<settings>/cache/templates/org.vibevm.node/node/` with no request at all.

## Maintaining

`vibe.toml` is **authored here, by hand, once** — and then not touched per
release. A new Node.js release needs no commit in this repository: it appears
in `https://nodejs.org/dist/index.json`, and the next resolution renders it.

The generator that used to render one manifest per release,
`org.vibevm.node/vibevm-package-generator`, is **superseded** by the
`[template]` declaration and is not used any more. Its repository records
that. Two things it did are deliberately lost with it:

- **`size` on the archive steps.** nodejs.org publishes digests but no sizes,
  and the generator read them from a hand-made `SIZES` file. A rendered
  manifest therefore carries no `size`; the step panel falls back to the
  server's `Content-Length`, and a mirror's byte total is a lower bound.
- **The provenance header.** A rendered manifest is produced on the client
  from the template at its revision and the release's own `SHASUMS256.txt`;
  the lock and the installation record carry the template revision, the
  rendered manifest's SHA-256 and the digest document's, which is where that
  provenance lives now.

What still has to be checked when upstream changes shape, rather than merely
publishing another release:

- a new target (`files[]` gains an archive) — a new `[[installer_options]]`
  row, `template_optional = true` until every release in the window has it;
- a target upstream stops building — the row becomes `template_optional`
  rather than disappearing, so old versions keep installing;
- `payload_root`, the launcher paths, or the archive naming changing — the
  template names all three, and the `{version}` spelling is the only part
  that varies per release;
- the two published tags: they are *not* re-rendered, by design.

The template's regression gate is in the vibe repository, not here:
`cargo test -p vibe-template --test node_golden` renders a **copy** of this
file at `24.22.2` and `22.23.4` and compares it, byte for byte, with the
manifests the two tags carry (modulo the generator's four header lines and the
`size` lines), reading upstream's own frozen `index.json` subset and
`SHASUMS256.txt` documents. The copy is
`crates/vibe-template/tests/fixtures/node/vibe.toml`, and it is pinned at the
revision whose render the two tags are: a revision that adds an installer row
the tags do not have — `1.2.0` and its four source rows — is a divergence that
belongs in the fixture's own history, not a break of the golden proof. `cargo test -p vibe-cli --test cli_template_node`
drives the channels and the optional rows through the real binary. A change
to this file that breaks either is a change that would have broken an
install.

**Not published yet.** Template resolution works today from every
directory-shaped registry (`--registry DIR`, a `localdir` source, a
`monorepo` working copy, a mirrored layout registry); rendering a template
found in a **per-package git registry** is the one part of PROP-075
`#TEMPLATE-DISCOVERY` still to be implemented. Until then this repository is
not republished, because a client resolving it through a git registry would
see the template revision `1.0.0` as if it were a Node.js version. The
revision is deliberately numbered below every produced version so that even
such a client prefers a real one.

## License

This package (its manifest and documents) is UPL-1.0, see `LICENSE.md`.
Node.js itself is not: it is distributed under the MIT license together with
the licenses listed in its own `LICENSE`, which every installation keeps in
the payload root.
