#!/usr/bin/env bash
# Inner test for server_cleanup_test: records the server's port.
set -euo pipefail
echo "$NATS_PORT" > "$TEST_TMPDIR/recorded_port"
