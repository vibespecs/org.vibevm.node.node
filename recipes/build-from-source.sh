#!/bin/sh
# Build Node.js from upstream's own source tarball — the `recipe` step of the
# `source-linux-*` / `source-macos-*` installer options, and what nvm-sh's
# `nvm install -s` does (`nvm_install_source`, nvm.sh 4052-4172).
#
# Vibe hands this script its whole contract in the environment
# (PROP-065 `#templates`): the extracted tarball under `$VIBE_SOURCES`, the
# staging prefix `$VIBE_OUT` that becomes the installed payload, and one
# declared parameter as `$VIBE_PARAM_JOBS`. Nothing here is templated by Vibe —
# a recipe's text is passed through untouched — so every value is read from the
# environment and nothing is interpolated into a command string.
#
# The build is relocatable, which `PROP-059#source-build` requires of a recipe:
# `node` finds its own tree from `process.execPath`, and `make install` writes
# `bin/npm`, `bin/npx` and `bin/corepack` as *relative* symbolic links into
# `lib/node_modules/`, so the payload may be moved between storage libraries
# afterwards. The staging prefix is never read back at run time.

set -eu

: "${VIBE_SOURCES:?the sources step must run first}"
: "${VIBE_OUT:?vibe must supply the staging prefix}"

# The `sources` step laid the verified tarball out at `$VIBE_SOURCES/node/`,
# extracted as it came — so its own single top-level `node-v<version>/`
# directory is still there. Find it rather than guess the version: a recipe
# never learns the version it is building.
src=''
for candidate in "$VIBE_SOURCES"/node/*/; do
    [ -d "$candidate" ] || continue
    if [ -n "$src" ]; then
        echo "build-from-source.sh: more than one directory under $VIBE_SOURCES/node" >&2
        exit 1
    fi
    src="$candidate"
done
if [ -z "$src" ]; then
    echo "build-from-source.sh: no extracted source tree under $VIBE_SOURCES/node" >&2
    exit 1
fi

# `jobs`, the declared parameter (PROP-065 `#parameters`). Its manifest default
# is 0, which means "whatever nvm would have chosen", because a manifest
# default is a constant and the number of cores is a host fact. The choice
# itself is `nvm_get_make_jobs` (nvm.sh 3998-4049): one less than the number of
# cores when there are more than two, otherwise a single job.
jobs="${VIBE_PARAM_JOBS:-0}"
case "$jobs" in
    '' | *[!0-9]*) jobs=0 ;;
esac
if [ "$jobs" -eq 0 ]; then
    cores="$(getconf _NPROCESSORS_ONLN 2>/dev/null \
        || getconf NPROCESSORS_ONLN 2>/dev/null \
        || nproc 2>/dev/null \
        || echo '')"
    case "$cores" in
        '' | *[!0-9]*) cores=0 ;;
    esac
    if [ "$cores" -eq 0 ]; then
        echo 'build-from-source.sh: cannot determine the number of cores, building single-threaded'
        jobs=1
    elif [ "$cores" -gt 2 ]; then
        jobs=$((cores - 1))
        echo "build-from-source.sh: $cores cores detected, building with $jobs jobs"
    else
        jobs=1
        echo "build-from-source.sh: $cores core(s) detected, building single-threaded"
    fi
else
    echo "build-from-source.sh: building with $jobs jobs, as asked"
fi

cd "$src"

# The compiler is Node's own default — `cc` and `c++`, which the step declares
# as needs — unless the caller exported `CC` / `CXX`, which reach this child
# like any other inherited variable. That is also what nvm ends up with: its
# clang nudge sets `CC=${CC:-cc} CXX=${CXX:-c++}`.
echo "\$> ./configure --prefix=$VIBE_OUT"
./configure --prefix="$VIBE_OUT"
echo "\$> make -j$jobs"
make -j"$jobs"
echo "\$> make -j$jobs install"
make -j"$jobs" install
