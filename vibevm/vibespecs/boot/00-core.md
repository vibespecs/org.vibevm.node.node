# Node.js application package

This package declares how Vibe installs Node.js, the official upstream build,
as a portable user application on seven targets (Linux glibc x86_64/aarch64,
Linux musl x86_64, macOS x86_64/aarch64, Windows x86_64/aarch64). It contains
no binaries. Each installer option downloads one archive identified by its
exact URL and SHA-256 from nodejs.org, unpacks it with its top-level directory
stripped, and declares three launchers — `node`, `npm` and `npx` — all of
which run the payload's own `node` executable (npm and npx on their CLI
scripts, the way Node's own wrappers do). All three are public commands, so an
installation puts them on PATH.

Two Node.js releases are published from this one repository: 24.22.2 at the
tag `v24.22.2` and 22.23.4 at `v22.23.4`, each with its own rendered
`vibe.toml`. `main` carries the newest of them; the registry resolves a
version from its tag. Both install at once and share the `node` slot, so
`vibe app use node <key>` chooses which one answers `node`.

Before changing the package, read `vibe.toml` and `README.md`. **`vibe.toml`
is rendered, never edited**, and its renderer is not in this repository: it is
`org.vibevm.node/vibevm-package-generator`, the generator of the whole
`org.vibevm.node` family.

```text
vibe install -g org.vibevm.node/vibevm-package-generator
vibevm-generate-package-node --node <version> SHASUMS256.txt SIZES > vibe.toml
```

The rendered header names the generator version and the SHA-256 of both input
files, and re-rendering from the same inputs is byte-identical — check that
before every publish. When moving to a new Node.js release, download every
archive, verify it against `SHASUMS256.txt`, confirm each archive's top-level
directory still matches `payload_root` and that the launcher paths still
exist, render, install on at least Linux and Windows, and keep the public
command names `node`, `npm` and `npx` stable.

This package is what another application package names when it needs a Node.js
runtime it does not bundle. Such a package declares its launcher
`executable = "command:node"` and resolves `node` from PATH at launch; it does
not depend on this package, and the user who wants a managed Node.js installs
it here by name.
