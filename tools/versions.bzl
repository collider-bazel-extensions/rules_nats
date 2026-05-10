"""Maintainer-side: NATS Helm chart pin for the helm-render flow.

Consumers don't see this — it's loaded only by the dev-only chart-fetch
extension under tools/. The committed manifest at
`//private/manifests:nats.yaml` is what consumers actually consume.

The chart is published as a packaged `.tgz` via the nats-io/k8s
GitHub release (and mirrored at https://nats-io.github.io/k8s/helm/charts/).
We download the `.tgz` directly — same flow as rules_loki.

Update flow:
    1. Edit NATS_CHART_VERSIONS to add/change the entry, including
       chart_url + chart_sha256:
           curl -fsSL "<url>" | sha256sum
    2. Add (or update) a `helm_template` + `sh_binary` block in
       tools/BUILD.bazel for the new version.
    3. `bash tools/render_nats.sh <version>`.
"""

NATS_CHART_VERSIONS = {
    "2.12.6": {
        "chart_url":    "https://github.com/nats-io/k8s/releases/download/nats-2.12.6/nats-2.12.6.tgz",
        "chart_sha256": "3fce4b3bb67c8c7cec2ea133c7435927eea03b963655e58c9a03b804ec8aa8e9",
    },
}
