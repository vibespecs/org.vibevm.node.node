#!/bin/sh
# The npm adapter's `install` verb: install the items this step is handed
# into *this* installation's npm prefix.
#
# The items arrive as separate argv elements appended to this script's own
# argv and are read as "$@" — never spliced into a command string. An item
# is opaque: `typescript`, `pnpm@9`, `@scope/pkg@^1.2`, a git URL, a local
# tarball path are all one argument each, exactly as written.
#
# `npm` here is this version's own npm: PATH leads with the installation's
# payload directory, so no script in this package ever knows a version
# number.

set -u

[ "$#" -gt 0 ] || exit 0

exec npm install -g -- "$@"
