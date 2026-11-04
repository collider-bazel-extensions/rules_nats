#!/usr/bin/env bash
# nats_test passes the target's args (and only those) to the test.
set -euo pipefail

[[ $# -eq 2 && "$1" == "one" && "$2" == "two words" ]] \
  || { echo "FAIL: args = [$*] ($# of them), want [one] [two words]" >&2; exit 1; }
[[ -n "${NATS_URL:-}" ]] || { echo "FAIL: NATS_URL not set" >&2; exit 1; }
echo "PASS: args forwarded, NATS_URL=$NATS_URL"
