#!/bin/sh
# The npm adapter's `remove` verb: uninstall the items this step is handed
# from *this* installation's npm prefix. The items are read as "$@", the
# same opaque argv elements the `install` verb takes.

set -u

[ "$#" -gt 0 ] || exit 0

exec npm uninstall -g -- "$@"
