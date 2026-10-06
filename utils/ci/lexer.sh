#!/usr/bin/env bash
# Portable build, bounded lexer, and scripting validation.
set -Eeuo pipefail

phase=${1:-all}
case "$phase" in
    build|test|scripting|scripting-tls|all) ;;
    *) printf 'Usage: %s [build|test|scripting|scripting-tls|all]\n' "$0" >&2; exit 2 ;;
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
    sha256sum src/keydb-server tests/unit/lua-lexer.tcl tests/unit/scripting.tcl \
        | tee "$log_dir/checksums.log"
fi

if [[ "$phase" == test || "$phase" == all || "$phase" == scripting || "$phase" == scripting-tls ]]; then
    test_unit=unit/lua-lexer
    test_log=lexer-tests.log
    if [[ "$phase" == scripting || "$phase" == scripting-tls ]]; then
        test_unit=unit/scripting
        test_log=$phase-tests.log
    fi
    test_args=(--single "$test_unit" --clients 1 --verbose --config server-threads 3)
    if [[ "$phase" == scripting-tls ]]; then
        ./utils/gen-test-certs.sh 2>&1 | tee "$log_dir/certificates.log"
        test_args+=(--tls)
    fi
    # Only needed in execution environments that prohibit Unix sockets.
    if [[ "${KEYDB_TEST_DISABLE_UNIX_SOCKET:-0}" == 1 ]]; then
        test_args+=(--config unixsocket '""')
    fi
    ./runtest "${test_args[@]}" 2>&1 | tee "$log_dir/$test_log"
fi
