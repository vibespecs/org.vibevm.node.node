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

**`vibe.toml` is a template manifest** (`[package] template = true`,
PROP-075): it is written once with `{version}` and `{sha256:…}` variables and
a `[template]` declaration naming where versions and digests come from, and
Vibe renders it on the client, at resolution time, for whichever version the
user asks for. Every release from `min = "12.0.0"` up is installable from this
one file, and **a new Node.js release needs no commit here**. The versions come
from `https://nodejs.org/dist/index.json`, the digests from
`https://nodejs.org/dist/v{version}/SHASUMS256.txt`, and two
`[[template.channel]]` rules turn the records' own `lts` field into the
channels `lts` and `lts/<codename>`.

`[package].version` is the **template revision** (`1.0.0`, tag `v1.0.0`), not a
Node.js version: a revision is excluded from the version domain, and bumping it
is how a fix to the manifest's shape reaches users. The two releases the
retired generator rendered stay published concretely at the tags `v24.22.2` and
`v22.23.4`; a concretely published version wins over the template's rendering
of the same version and the template is then not rendered for it at all, which
is how one release can be hand-fixed without touching the template.

Three of the seven rows carry `template_optional = true` —
`linux-musl-x64`, `macos-arm64` and `windows-arm64` — because upstream has not
built them for every release in the window (Apple silicon starts at 16.0.0,
Windows ARM at 19.9.0, musl at 22.23.3 and still with gaps). Such a row is
dropped from the rendered manifest when the release's `SHASUMS256.txt` does
not carry its archive; every other row is required, and a missing required
archive is a refusal rather than a quiet manifest. Keep that list honest: a
required row upstream stops building must *become* optional, never disappear,
or old versions stop installing.

Before changing the package, read `vibe.toml` and `README.md`. **Do not
re-introduce a generator**: the renderer is Vibe's own pure one
(`crates/vibe-template` in the vibe repository), and
`org.vibevm.node/vibevm-package-generator` is superseded. Two of its outputs
are deliberately lost: the per-archive `size` (nodejs.org publishes digests
but not sizes — the step panel falls back to `Content-Length`) and the
provenance header (the lock and the installation record now carry the template
revision and the two document hashes instead).

The regression gate lives in the vibe repository: `cargo test -p vibe-template
--test node_golden` renders this file at `24.22.2` and `22.23.4` and compares
it byte for byte with the manifests those two tags carry, from upstream's own
frozen documents; `cargo test -p vibe-cli --test cli_template_node` drives the
channels and the optional rows through the real binary. Keep the public command
names `node`, `npm` and `npx` stable, and check `payload_root` and the launcher
paths whenever upstream changes an archive's shape.

This package is what another application package names when it needs a Node.js
runtime it does not bundle. Such a package declares its launcher
`executable = "command:node"` and resolves `node` from PATH at launch; it does
not depend on this package, and the user who wants a managed Node.js installs
it here by name.
