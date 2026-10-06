#!/usr/bin/env bash
# Portable build and bounded lexer validation; no provider-specific commands.
set -Eeuo pipefail

phase=${1:-all}
case "$phase" in
    build|test|all) ;;
    *) printf 'Usage: %s [build|test|all]\n' "$0" >&2; exit 2 ;;
esac

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd -- "$repo_root"
log_dir=${KEYDB_CI_LOG_DIR:-ci-logs}
mkdir -p -- "$log_dir"

{
    git rev-parse HEAD
    git status --short
    uname -sm
    cat /etc/os-release
    "${CC:-cc}" --version
    "${CXX:-c++}" --version
    command -v tclsh8.6
    tclsh8.6 <<<'puts [info patchlevel]'
} > "$log_dir/environment-$phase.log" 2>&1

if [[ "$phase" == build || "$phase" == all ]]; then
    make BUILD_TLS=yes MALLOC=libc -j"${KEYDB_BUILD_JOBS:-2}" \
        2>&1 | tee "$log_dir/build.log"
    src/keydb-server --version | tee "$log_dir/version.log"
    sha256sum src/keydb-server tests/unit/lua-lexer.tcl \
        | tee "$log_dir/checksums.log"
fi

if [[ "$phase" == test || "$phase" == all ]]; then
    test_args=(--single unit/lua-lexer --clients 1 --verbose
               --config server-threads 3)
    # Only needed in execution environments that prohibit Unix sockets.
    if [[ "${KEYDB_TEST_DISABLE_UNIX_SOCKET:-0}" == 1 ]]; then
        test_args+=(--config unixsocket '""')
    fi
    ./runtest "${test_args[@]}" 2>&1 | tee "$log_dir/lexer-tests.log"
fi
