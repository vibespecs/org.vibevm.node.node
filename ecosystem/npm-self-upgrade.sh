#!/bin/sh
# The npm adapter's `self_upgrade` verb: bring *this* installation's bundled
# npm up to the newest release it can run.
#
# Node's own compatibility table is the reason this is not a bare
# `npm install -g npm`: a given npm major is the last one that runs on a
# given node line, and asking for `npm@latest` on an older runtime installs
# an npm that cannot start. The ceilings below are upstream's own, the same
# ones every Node release note carries.
#
# **What a failed upgrade means here, stated because it decides the exit
# status.** The verb's job is "the bundled manager is as current as this
# runtime can have it". If the attempt cannot be made — no registry
# reachable, the release not published for this platform — the runtime is
# left carrying the npm it was shipped with, which is a working manager and
# the same outcome as "already current": this verb reports it and succeeds.
# If npm itself is broken afterwards, nothing is working and the verb fails.
# So the exit status answers "does this installation have a usable package
# manager", never "was the network up".

set -u

node_major_minor() {
    node -e 'const v = process.versions.node.split(".");
             process.stdout.write(v[0] + " " + v[1]);' 2>/dev/null
}

# The newest npm this node line can run: upstream's own ceilings.
wanted_npm() {
    major="$1"
    minor="$2"
    if [ "$major" -lt 10 ]; then
        echo "npm@6"
    elif [ "$major" -lt 12 ] || [ "$major" = 13 ] || [ "$major" = 15 ]; then
        echo "npm@7"
    elif [ "$major" = 12 ] || [ "$major" = 14 ] || { [ "$major" = 16 ] && [ "$minor" -lt 13 ]; }; then
        echo "npm@8.6"
    elif [ "$major" -lt 18 ] ||
        { [ "$major" = 18 ] && [ "$minor" -lt 17 ]; } ||
        [ "$major" = 19 ] ||
        { [ "$major" = 20 ] && [ "$minor" -lt 5 ]; }; then
        echo "npm@9"
    elif { [ "$major" = 20 ] && [ "$minor" -lt 17 ]; } ||
        [ "$major" = 21 ] ||
        { [ "$major" = 22 ] && [ "$minor" -lt 9 ]; }; then
        echo "npm@10"
    else
        echo "npm"
    fi
}

read -r major minor <<EOF
$(node_major_minor)
EOF

if [ -z "${major:-}" ] || [ -z "${minor:-}" ]; then
    echo "npm self-upgrade: this installation's node does not run" >&2
    exit 1
fi

wanted="$(wanted_npm "$major" "$minor")"
echo "npm self-upgrade: node v${major}.${minor}.x takes ${wanted}"

if npm install -g -- "$wanted"; then
    echo "npm self-upgrade: npm is now v$(npm --version 2>/dev/null)"
    exit 0
fi

# The upgrade did not happen. The question that decides the exit status is
# whether this installation still has a usable npm, not whether a registry
# answered.
if current="$(npm --version 2>/dev/null)" && [ -n "$current" ]; then
    echo "npm self-upgrade: ${wanted} could not be fetched; npm stays at v${current}" >&2
    exit 0
fi

echo "npm self-upgrade: npm does not run in this installation" >&2
exit 1
