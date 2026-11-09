#!/usr/bin/env python3
"""Render vibe.toml from the Node.js release checksum file.

    python3 -I tools/render-manifest.py SHASUMS256.txt SIZES > vibe.toml

SHASUMS256.txt is the checksum asset of the pinned Node.js release and SIZES
a file of `<bytes> <name>` lines for the same archives (for example
`stat -c '%s %n' *`). Nothing is fetched: download the archives, verify each
against SHASUMS256.txt, then render. Bump NODE below for a new release.
"""
import sys

NODE = "24.22.2"
NODE_URL = f"https://nodejs.org/dist/v{NODE}"

# option id, platform, platform name, arch, arch name, archive suffix
TARGETS = [
    ("linux-x64", "linux", "Linux (glibc)", "x86_64", "Intel/AMD 64-bit", "linux-x64.tar.gz"),
    ("linux-arm64", "linux", "Linux (glibc)", "aarch64", "ARM 64-bit", "linux-arm64.tar.gz"),
    ("linux-musl-x64", "linux-musl", "Linux (musl: Alpine and others)", "x86_64", "Intel/AMD 64-bit", "linux-x64-musl.tar.gz"),
    ("macos-x64", "macos", "macOS", "x86_64", "Intel 64-bit", "darwin-x64.tar.gz"),
    ("macos-arm64", "macos", "macOS", "aarch64", "Apple silicon", "darwin-arm64.tar.gz"),
    ("windows-x64", "windows", "Windows", "x86_64", "Intel/AMD 64-bit", "win-x64.zip"),
    ("windows-arm64", "windows", "Windows", "aarch64", "ARM 64-bit", "win-arm64.zip"),
]


def sums(path):
    table = {}
    with open(path, encoding="utf-8") as text:
        for line in text:
            parts = line.split()
            if len(parts) == 2:
                table[parts[1].lstrip("*")] = parts[0]
    return table


def sizes(path):
    table = {}
    with open(path, encoding="utf-8") as text:
        for line in text:
            parts = line.split()
            if len(parts) == 2:
                table[parts[1].rsplit("/", 1)[-1]] = int(parts[0])
    return table


def main():
    node_sums, size = sums(sys.argv[1]), sizes(sys.argv[2])
    out = [HEADER.format(node=NODE)]
    for option, platform, platform_name, arch, arch_name, suffix in TARGETS:
        archive = f"node-v{NODE}-{suffix}"
        root = archive.rsplit(".tar.gz", 1)[0].rsplit(".zip", 1)[0]
        # The Windows zip keeps node.exe and npm's own tree at its top level;
        # the POSIX tarballs use the usual bin/ and lib/ prefixes.
        # `path_dirs` exposes that same directory whole, because npm writes
        # new commands into it: a global `npm install -g` puts them beside
        # node, and a fixed per-command proxy set could never reach them.
        if platform == "windows":
            node, npm_root, path_dir = "node.exe", "node_modules/npm/bin", "."
        else:
            node, npm_root, path_dir = "bin/node", "lib/node_modules/npm/bin", "bin"
        out.append(OPTION.format(
            option=option, platform=platform, platform_name=platform_name,
            arch=arch, arch_name=arch_name, node=NODE,
            fmt="zip" if suffix.endswith(".zip") else "tar_gz",
            url=f"{NODE_URL}/{archive}", sha=node_sums[archive], size=size[archive],
            payload_root=root, node_exe=node, npm_root=npm_root,
            path_dir=path_dir,
        ))
    sys.stdout.write("\n".join(out))


HEADER = '''[package]
name = "node"
group = "org.vibevm.node"
kind = "app"
version = "{node}"
epoch = 1
format = "normal"
authors = ["Oleg Chirukhin"]
license = "UPL-1.0"
description = "Node.js {node}, the official upstream build, as a portable Vibe application putting node, npm and npx on PATH"
keywords = ["node", "nodejs", "javascript", "runtime", "npm", "application"]
homepage = "https://nodejs.org/"

[compatibility]
min_vibe_version = "1.0.12"
requires_kinds = []

[application]
id = "node"
keywords = ["node", "nodejs", "npm", "javascript"]
'''

# Every option is one verified archive, three launchers and the one payload
# directory it exposes whole on PATH. The launchers all run the payload's own
# node executable: npm and npx are started on their CLI scripts the way
# Node's own wrappers do, so no launcher depends on a shell script, a .cmd
# file or a node already on PATH — that is what `vibe app run` uses.
#
# PATH itself comes from `path_dirs`, not from per-command proxies: npm's own
# global installs write new commands (and on Windows their .cmd wrappers)
# into this very directory after vibe has finished installing, so the whole
# directory has to be what goes on PATH.
OPTION = '''
[[installer_options]]
id = "{option}"
name = "Node.js {node}"
platform = "{platform}"
platform_name = "{platform_name}"
arch = "{arch}"
arch_name = "{arch_name}"
path_dirs = ["{path_dir}"]

[[installer_options.steps]]
id = "node"
title = "Download and unpack the Node.js {node} runtime"
kind = "archive"
format = "{fmt}"
source = "{url}"
sha256 = "{sha}"
size = {size}
payload_root = "{payload_root}"

[[installer_options.launchers]]
id = "node"
name = "node"
description = "The Node.js runtime"
executable = "{node_exe}"
kind = "command"
default = true

[[installer_options.launchers]]
id = "npm"
name = "npm"
description = "The npm package manager"
executable = "{node_exe}"
args = ["$app_root/{npm_root}/npm-cli.js"]
kind = "command"

[[installer_options.launchers]]
id = "npx"
name = "npx"
description = "Run a command from an npm package"
executable = "{node_exe}"
args = ["$app_root/{npm_root}/npx-cli.js"]
kind = "command"

'''

if __name__ == "__main__":
    main()
