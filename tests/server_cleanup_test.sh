#!/usr/bin/env bash
# The nats_test trampoline stops its nats_server when the test ends, even
# when run directly (not under `bazel test`'s process-group cleanup).
#
# Args: <trampoline> <server> <inner> <server_name>
set -euo pipefail

root="$TEST_SRCDIR/$TEST_WORKSPACE"
trampoline="$root/$1"; shift
rm -f "$TEST_TMPDIR/recorded_port"
# setsid: own process group, so nothing outside the trampoline's own
# cleanup can stop the server for it.
setsid "$trampoline" "$@"
port=$(cat "$TEST_TMPDIR/recorded_port")
[[ -n "$port" ]] || { echo "FAIL: inner test did not record a port" >&2; exit 1; }
for _ in $(seq 50); do
  (echo > "/dev/tcp/127.0.0.1/$port") >/dev/null 2>&1 || { echo "PASS: nats-server on :$port stopped"; exit 0; }
  sleep 0.1
done
echo "FAIL: nats-server still listening on :$port after the test finished" >&2
exit 1
