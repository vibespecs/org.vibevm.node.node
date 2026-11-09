# Node.js application package

This package declares how Vibe installs Node.js 24.22.2, the official upstream
build, as a portable user application on seven targets (Linux glibc
x86_64/aarch64, Linux musl x86_64, macOS x86_64/aarch64, Windows
x86_64/aarch64). It contains no binaries. Each installer option downloads one
archive identified by its exact URL and SHA-256 from nodejs.org, unpacks it
with its top-level directory stripped, and declares three launchers — `node`,
`npm` and `npx` — all of which run the payload's own `node` executable (npm
and npx on their CLI scripts, the way Node's own wrappers do). All three are
public commands, so an installation puts them on PATH.

Before changing the package, read `vibe.toml` and `README.md`. `vibe.toml` is
rendered by `tools/render-manifest.py` from the release checksum file; edit the
script, not the rendered file. When moving to a new Node.js release, download
every archive, verify it against `SHASUMS256.txt`, confirm each archive's
top-level directory still matches `payload_root` and that the launcher paths
still exist, render, install on at least Linux and Windows, and keep the public
command names `node`, `npm` and `npx` stable.

This package is what another application package names when it needs a Node.js
runtime it does not bundle. Such a package declares its launcher
`executable = "command:node"` and resolves `node` from PATH at launch; it does
not depend on this package, and the user who wants a managed Node.js installs
it here by name.
