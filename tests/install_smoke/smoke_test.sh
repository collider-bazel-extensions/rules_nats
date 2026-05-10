#!/usr/bin/env bash
# Full E2E install smoke for nats_install. Strategy:
#
#   1. The itest dep chain (kind → nats_install) has already brought
#      up a kind cluster + applied the chart manifest. The nats
#      StatefulSet is rolled out before we run.
#   2. `kubectl exec` into a nats-box pod (the chart deploys this
#      sidecar with the nats CLI baked in) to add a JetStream stream
#      against the in-cluster `nats` Service.
#   3. Publish a marker message.
#   4. Read it back via `nats stream get` and assert the marker is
#      present.
#
# Proves end-to-end: rendered chart applies, nats-server boots in the
# cluster, JetStream accepts streams, pub/consume round-trips.
set -euo pipefail

CLUSTER_NAME="cluster"
env_file="$TEST_TMPDIR/${CLUSTER_NAME}.env"
[[ -f "$env_file" ]] || { echo "missing kind env file" >&2; exit 1; }
# shellcheck disable=SC1090
source "$env_file"

KCTL=("$KUBECTL" --kubeconfig="$KUBECONFIG")

NS="nats"
NATS_BOX_DEPLOY="nats-box"
SERVER_URL="nats://nats:4222"

# Wait for nats-box pod (the rollout above only blocks on sts/nats;
# nats-box is a separate Deployment).
echo "smoke: waiting for $NATS_BOX_DEPLOY Deployment Available"
"${KCTL[@]}" -n "$NS" wait "deploy/$NATS_BOX_DEPLOY" \
    --for=condition=Available --timeout=180s

# Pick the nats-box pod name.
box_pod=$("${KCTL[@]}" -n "$NS" get pod \
    -l "app.kubernetes.io/name=nats-box" \
    -o jsonpath='{.items[0].metadata.name}')
[[ -n "$box_pod" ]] || { echo "smoke: FAIL — no nats-box pod found" >&2; exit 1; }
echo "smoke: nats-box pod: $box_pod"

KEXEC=("${KCTL[@]}" -n "$NS" exec "$box_pod" -c nats-box --)

# 1. Add a JetStream stream named SMOKE on `smoke.>`.
"${KEXEC[@]}" nats --server "$SERVER_URL" stream add SMOKE \
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

# 2. Publish a marker.
marker="install-smoke-marker-$$"
"${KEXEC[@]}" nats --server "$SERVER_URL" pub smoke.test "$marker" > /dev/null
echo "smoke: published '$marker' to smoke.test"

# 3. Read it back via `nats stream get`.
got=$("${KEXEC[@]}" nats --server "$SERVER_URL" stream get SMOKE 1 2>&1)
if ! grep -q "$marker" <<<"$got"; then
  echo "smoke: FAIL — stream get did not echo back the marker. Got:" >&2
  echo "$got" >&2
  exit 1
fi

echo "smoke: OK — chart-installed NATS + JetStream pub/consume round-trip confirmed"
echo "  marker excerpt: $(grep -o "$marker" <<<"$got" | head -1)"
