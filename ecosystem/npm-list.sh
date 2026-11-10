#!/bin/sh
# The npm adapter's `list` verb: what this installation's npm carries
# globally, one item per line, written into the file $VIBE_ECOSYSTEM_LIST
# names — never onto stdout, so npm's own notices stay a log.
#
# Each line is `name@version`, which is an item the `install` verb takes
# back unchanged: that is what makes the synthesised `ecosystem:npm`
# migration a real round trip.
#
# **The managers Node ships with are left out, and that is the decision this
# file exists to state.** `npm` and `corepack` live inside every Node
# distribution's own `lib/node_modules`: they are the runtime's package
# managers, not packages anybody added to it. Reporting them would make
# every fresh installation look as though it already carried two global
# packages, and carrying them into another version — which is what the
# `ecosystem:npm` migration does with this list — would overwrite that
# version's own bundled managers with an older or newer pair that upstream
# did not test it against. Upgrading npm is the adapter's fourth verb,
# `self_upgrade`, which is the one place that decision belongs.

set -u

: "${VIBE_ECOSYSTEM_LIST:?the list verb is run by vibe, which names the answer file}"

npm ls -g --depth 0 --parseable --long 2>/dev/null |
    awk -F: '
        {
            item = $NF
        }
        item !~ /^@?[^@]+@[^@]+$/ { next }
        # The two managers every Node distribution bundles.
        item ~ /^npm@/ || item ~ /^corepack@/ { next }
        { print item }
    ' |
    sort >"$VIBE_ECOSYSTEM_LIST"

exit 0
