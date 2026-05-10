"""nats_install + nats_install_health_check — cluster-deploy
primitives wrapping rules_kubectl's `kubectl_apply` over the
pinned, pre-rendered NATS Helm chart.

Wait shape:
  - StatefulSet `<namespace>/nats` rolled out (the chart names the
    StatefulSet after the release name; we pass `release_name = "nats"`
    at render time).

The chart deploys a single nats-server with JetStream enabled (chart
default for v2.12.x). Multi-replica + cluster setups are out of scope
for v0.1's smoke fixture; consumers can override values at the
maintainer-render layer for production deploys.
"""

load("@rules_kubectl//:defs.bzl", "kubectl_apply", "kubectl_apply_health_check")

_NATS_STS = "sts/nats"

def nats_install(
        name,
        namespace = "nats",
        wait_timeout = "300s",
        **kwargs):
    """Apply the pinned NATS chart into `namespace`, block until the
    StatefulSet has rolled out before idling.

    Drops into `itest_service.exe`. Wait timeout 300s — the
    nats:2.12.6 image is small (~30MB); cold pulls clear well under
    5 minutes.
    """
    extra_rollouts = kwargs.pop("wait_for_rollouts", [])
    kubectl_apply(
        name = name,
        manifests = ["@rules_nats//private/manifests:nats.yaml"],
        namespace = namespace,
        create_namespace = True,
        server_side = True,
        wait_for_rollouts = [_NATS_STS] + list(extra_rollouts),
        wait_timeout = wait_timeout,
        **kwargs
    )

def nats_install_health_check(
        name,
        namespace = "nats",
        **kwargs):
    """Readiness probe paired with `nats_install`. Same wait shape
    with `--timeout=0s`. Drops into `itest_service.health_check`.
    """
    extra_rollouts = kwargs.pop("wait_for_rollouts", [])
    kubectl_apply_health_check(
        name = name,
        namespace = namespace,
        wait_for_rollouts = [_NATS_STS] + list(extra_rollouts),
        **kwargs
    )
