#!/usr/bin/env bash
# nats_test smoke — proves the auto-launched nats_server is reachable
# at NATS_URL and that JetStream pub/consume round-trips a message.
#
# This script runs inside the nats_test trampoline, which has already
# launched a server and sourced its env file (NATS_URL / NATS_HOST /
# NATS_PORT).
set -euo pipefail

[[ -n "${NATS_URL:-}" ]] || { echo "NATS_URL not set (env-file wiring broken)" >&2; exit 1; }
echo "smoke: NATS_URL=$NATS_URL"

# nats_test's trampoline exports $NATS_CLI for us — it has access to
# the nats_server's runfiles which include the CLI binary.
[[ -x "${NATS_CLI:-}" ]] || { echo "smoke: NATS_CLI not exported by trampoline" >&2; exit 1; }
echo "smoke: nats CLI = $NATS_CLI ($("$NATS_CLI" --version | head -1))"

# 1. Create a JetStream stream named SMOKE that captures subjects on `smoke.>`.
"$NATS_CLI" --server "$NATS_URL" stream add SMOKE \
    --subjects 'smoke.>' \
    --storage memory \
    --retention limits \
    --discard old \
    --max-msgs=-1 \
    --max-msgs-per-subject=-1 \
    --max-bytes=-1 \
    --max-age=0 \
    --max-msg-size=-1 \
    --dupe-window=2m \
    --replicas 1 \
    --no-allow-rollup \
    --no-deny-delete \
    --no-deny-purge \
    --defaults \
    > /dev/null
echo "smoke: stream SMOKE created"

# 2. Publish a message.
marker="hello-from-smoke-$$"
"$NATS_CLI" --server "$NATS_URL" pub smoke.test "$marker" > /dev/null
echo "smoke: published '$marker' to smoke.test"

# 3. Pull it back with nats stream get.
got=$("$NATS_CLI" --server "$NATS_URL" stream get SMOKE 1 2>&1)
if ! grep -q "$marker" <<<"$got"; then
  echo "smoke: FAIL — stream get did not return the marker. Got:" >&2
  echo "$got" >&2
  exit 1
fi
echo "smoke: OK — JetStream round-trip confirmed"
echo "  marker excerpt: $(grep -o "$marker" <<<"$got" | head -1)"
