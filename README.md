# rules_nats

Bazel rules for [NATS](https://nats.io) — high-performance pub/sub + JetStream messaging. Two families in one repo:

- **Hermetic server (test-time):**
  - `nats_server` — long-running `nats-server` fixture; writes `$TEST_TMPDIR/<name>.env` with `NATS_URL` once accepting connections.
  - `nats_health_check` — pairs with `nats_server` for `itest_service` compositions.
  - `nats_test` — sh_test macro that auto-launches a `nats_server` and exec's the user test with `NATS_URL` (and `$NATS_CLI` pointing at the toolchain's `nats` CLI) in env.
- **Cluster install (kind / production):**
  - `nats_install` — applies the pinned NATS Helm chart, waits for `sts/nats` rollout.
  - `nats_install_health_check` — paired readiness probe.

## Install (Bzlmod)

```python
bazel_dep(name = "rules_nats", version = "0.1.0")

nats = use_extension("@rules_nats//:extensions.bzl", "nats")
nats.version(version = "2.14.0", cli_version = "0.4.0")
use_repo(
    nats,
    "nats_2_14_0_darwin_amd64",
    "nats_2_14_0_darwin_arm64",
    "nats_2_14_0_linux_amd64",
    "nats_2_14_0_linux_arm64",
)
register_toolchains("@rules_nats//toolchain:all")
```

The `nats` extension is `mod.is_root`-guarded — only the root module's `nats.version()` tags fire — so consumers must declare it themselves rather than inheriting it from rules_nats's own `MODULE.bazel`. (The guard prevents `@nats_<ver>_<plat>` repo-name collisions when consumed transitively.) Same pattern as `rules_capsule`, `rules_temporal`, `rules_atlas`, etc.

The install primitives also require [`rules_kubectl`](https://github.com/collider-bazel-extensions/rules_kubectl) ≥ 0.2.0 (transitive — the macros are thin wrappers around `kubectl_apply`).

## Hermetic server primitives

```python
load("@rules_nats//:defs.bzl", "nats_test")

# Run a sh_test against an auto-launched nats_server.
# The trampoline exports NATS_URL / NATS_HOST / NATS_PORT and
# $NATS_CLI before exec'ing the inner test.
nats_test(
    name = "pubsub_test",
    srcs = ["pubsub_test.sh"],
    # jetstream = True (default) — set False for plain pub/sub.
)
```

Inside `pubsub_test.sh`:

```sh
"$NATS_CLI" --server "$NATS_URL" stream add MYSTREAM --subjects 'foo.>' ...
"$NATS_CLI" --server "$NATS_URL" pub foo.bar 'hello'
```

For longer-running compositions, use `nats_server` + `nats_health_check` directly with `itest_service`:

```python
load("@rules_nats//:defs.bzl", "nats_server", "nats_health_check")
load("@rules_itest//:itest.bzl", "itest_service")

nats_server(name = "test_nats", tags = ["manual"])
nats_health_check(name = "test_nats_health", server = ":test_nats", tags = ["manual"])

itest_service(
    name = "nats_svc",
    exe = ":test_nats",
    health_check = ":test_nats_health",
    tags = ["manual"],
)
```

## Install primitives

```python
load("@rules_nats//:defs.bzl", "nats_install", "nats_install_health_check")
load("@rules_itest//:itest.bzl", "itest_service")

nats_install(
    name = "nats_install_bin",
    tags = ["manual"],
)

nats_install_health_check(
    name = "nats_health_bin",
    tags = ["manual"],
)

itest_service(
    name = "nats_install_svc",
    exe = ":nats_install_bin",
    health_check = ":nats_health_bin",
    deps = [":kind_svc"],
    tags = ["manual"],
)
```

The included smoke (`tests/install_smoke/`) deploys NATS to kind, then `kubectl exec`s into the chart's `nats-box` pod (which ships the `nats` CLI) to add a JetStream stream + publish + consume a message.

## Pinned versions

| Component | Version | Source |
|-----------|---------|--------|
| nats-server | `2.14.0` | https://github.com/nats-io/nats-server/releases (tar.gz) |
| nats CLI    | `0.4.0`  | https://github.com/nats-io/natscli/releases (zip) |
| NATS Helm chart | `2.12.6` | https://github.com/nats-io/k8s/releases/download/nats-2.12.6/nats-2.12.6.tgz |

Maintainer flow for chart bumps: edit `tools/versions.bzl`, then `tools/render_nats.sh <version>` (uses [rules_helm](https://github.com/collider-bazel-extensions/rules_helm); no host helm required).

## See also

- [DESIGN.md](DESIGN.md) — architecture, design tradeoffs.
- [NATS docs](https://docs.nats.io)
- [JetStream docs](https://docs.nats.io/nats-concepts/jetstream)
