#!/usr/bin/env bash
# Maintainer flow:
#   1. Edit tools/versions.bzl::NATS_CHART_VERSIONS — add the target
#      version's chart_url + chart_sha256.
#   2. Add (or update) a `helm_template` + `sh_binary` block in
#      tools/BUILD.bazel for the new version.
#   3. tools/render_nats.sh <version>  (e.g. 2.12.6)
#
# Host helm is NOT required — helm comes from rules_helm.
set -euo pipefail

VERSION="${1:?usage: tools/render_nats.sh <version>}"
TARGET="//tools:render_writeback_$(echo "$VERSION" | tr '.' '_')"

echo "[render_nats] $TARGET"
exec bazel run "$TARGET"
