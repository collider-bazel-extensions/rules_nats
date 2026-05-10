#!/usr/bin/env bash
# nats_test trampoline — launches nats_server in the background,
# polls for its env file, sources NATS_URL et al, exec's the user's
# inner sh_binary.
#
# Argv: <server_short_path> <inner_short_path> <server_target_name>
set -euo pipefail

SERVER_SHORT="$1"
INNER_SHORT="$2"
SERVER_NAME="$3"

if [[ -z "${TEST_TMPDIR:-}" ]]; then
  echo "nats_test: TEST_TMPDIR not set (expected under bazel test)" >&2
  exit 1
fi

if [[ -z "${RUNFILES_DIR:-}" ]]; then
  if [[ -n "${TEST_SRCDIR:-}" ]]; then
    RUNFILES_DIR="$TEST_SRCDIR"
  fi
  export RUNFILES_DIR
fi

resolve() {
  local p="$1"
  if [[ -e "${RUNFILES_DIR}/_main/${p}" ]]; then
    printf '%s\n' "${RUNFILES_DIR}/_main/${p}"
  elif [[ -e "${RUNFILES_DIR}/${p}" ]]; then
    printf '%s\n' "${RUNFILES_DIR}/${p}"
  else
    echo "nats_test: not in runfiles: ${p}" >&2
    exit 1
  fi
}

server_bin="$(resolve "$SERVER_SHORT")"
test_bin="$(resolve "$INNER_SHORT")"
env_file="${TEST_TMPDIR}/${SERVER_NAME}.env"

"$server_bin" &
server_pid=$!
cleanup() {
  if kill -0 "$server_pid" 2>/dev/null; then
    kill -TERM "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

# Server's own deadline is 30s; give the trampoline a hair more.
deadline=$(( $(date +%s) + 35 ))
while (( $(date +%s) < deadline )); do
  [[ -f "$env_file" ]] && break
  if ! kill -0 "$server_pid" 2>/dev/null; then
    echo "nats_test: server exited before env file appeared" >&2
    exit 1
  fi
  sleep 0.2
done
[[ -f "$env_file" ]] || { echo "nats_test: timeout waiting for $env_file" >&2; exit 1; }

set -a
# shellcheck disable=SC1090
source "$env_file"
set +a

# The nats_server target has the toolchain's nats CLI in its
# runfiles; surface it to the inner test as $NATS_CLI so consumers
# don't have to re-resolve it. Find by name to dodge platform-specific
# repo paths.
# The CLI in runfiles is a symlink; -L follows it. Without -L, the
# `-type f` predicate would skip the symlink entry.
nats_cli_path="$(find -L "${RUNFILES_DIR}" -path '*/cli/nats' -type f 2>/dev/null | head -n1)"
if [[ -n "$nats_cli_path" ]]; then
  export NATS_CLI="$nats_cli_path"
fi

exec "$test_bin" "$@"
