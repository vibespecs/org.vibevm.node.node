# Node.js application package

This package installs [Node.js](https://nodejs.org/) — the official upstream
build, unmodified — as a portable Vibe user application, and puts `node`,
`npm` and `npx` on PATH. It contains no binaries: each installation downloads
one pinned archive and verifies it against its SHA-256 digest.

| Archive | From | Digest from |
| --- | --- | --- |
| `node-v<version>-<platform>.tar.gz` / `.zip` | `https://nodejs.org/dist/v<version>/` | `SHASUMS256.txt` of that release |

```text
vibe install -g org.vibevm.node/node
node --version
npm --version
npx --version
```

## Published versions

Two Node.js releases are published from this one repository, each as its own
tag with its own rendered `vibe.toml`:

| Version | Tag | Line |
| --- | --- | --- |
| 24.22.2 | `v24.22.2` | current |
| 22.23.4 | `v22.23.4` | maintenance |

`main` carries the newest of them; an older release stays reachable at its
tag, which is what the registry resolves. Install a specific one by version:

```text
vibe install -g org.vibevm.node/node@24
vibe install -g org.vibevm.node/node@22
```

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

## Targets

| Installer option | `--platform` / `--arch` | Archive |
| --- | --- | --- |
| `linux-x64` | `linux` / `x86_64` | `node-v<version>-linux-x64.tar.gz` |
| `linux-arm64` | `linux` / `aarch64` | `node-v<version>-linux-arm64.tar.gz` |
| `linux-musl-x64` | `linux-musl` / `x86_64` | `node-v<version>-linux-x64-musl.tar.gz` |
| `macos-x64` | `macos` / `x86_64` | `node-v<version>-darwin-x64.tar.gz` |
| `macos-arm64` | `macos` / `aarch64` | `node-v<version>-darwin-arm64.tar.gz` |
| `windows-x64` | `windows` / `x86_64` | `node-v<version>-win-x64.zip` |
| `windows-arm64` | `windows` / `aarch64` | `node-v<version>-win-arm64.zip` |

Vibe picks the option of the host's platform and architecture and asks when it
cannot decide. A musl system (Alpine and others) is detected as `linux` like
any other Linux, so install there with `vibe install -g org.vibevm.node/node
--platform linux-musl`.

## How the three launchers run

The archive is unpacked with its own top-level directory stripped
(`payload_root`), so the payload is Node's own tree: `bin/node` and
`lib/node_modules/npm/` on Linux and macOS, `node.exe` and
`node_modules/npm/` on Windows.

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

## Maintaining

`vibe.toml` is **rendered, never edited**. Its renderer is a package of its
own — `org.vibevm.node/vibevm-package-generator`, which carries the whole
`org.vibevm.node` family — so this repository ships no tooling:

```text
vibe install -g org.vibevm.node/vibevm-package-generator
vibevm-generate-package-node --node 24.22.2 SHASUMS256.txt SIZES > vibe.toml
```

`SHASUMS256.txt` is the release's own checksum asset and `SIZES` a file of
`<bytes> <name>` lines for the same archives (`stat -c '%s %n' *`). The
renderer fetches nothing; the rendered header records the generator version
and the SHA-256 of both inputs, and re-rendering from the same inputs is
byte-identical.

To move to a new Node.js release: download every archive of that release,
verify it against `SHASUMS256.txt`, check that each archive's top-level
directory still matches `payload_root` and that the launcher paths still
exist, render, re-render and compare, and install on at least Linux and
Windows.

## License

This package (its manifest and documents) is UPL-1.0, see `LICENSE.md`.
Node.js itself is not: it is distributed under the MIT license together with
the licenses listed in its own `LICENSE`, which every installation keeps in
the payload root.
