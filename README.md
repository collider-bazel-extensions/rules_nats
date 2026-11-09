# rules_nats

Bazel rules for [NATS](https://nats.io) — high-performance pub/sub + JetStream messaging. Two families in one repo:

- **Hermetic server (test-time):**
  - `nats_server` — long-running `nats-server` fixture; writes `$TEST_TMPDIR/<name>.env` with `NATS_URL` once accepting connections.
  - `nats_health_check` — pairs with `nats_server` for `itest_service` compositions.
  - `nats_test` — sh_test macro that auto-launches a `nats_server` and runs the user test (with the target's `args`) with `NATS_URL` (and `$NATS_CLI` pointing at the toolchain's `nats` CLI) in env.
- **Cluster install (kind / production):**
  - `nats_install` — applies the pinned NATS Helm chart, waits for `sts/nats` rollout.
  - `nats_install_health_check` — paired readiness probe.

## Install (Bzlmod)

```python
bazel_dep(name = "rules_nats", version = "0.1.2")
```

That's all: rules_nats's own `MODULE.bazel` pins nats-server 2.14.0 / nats CLI 0.4.0 and registers the toolchain. rules_nats is not in the BCR yet, so pin it (and `rules_kubectl`, below) with `archive_override` or `git_override`.

To fetch another pinned version for your own targets, set it in your root module:

```python
nats = use_extension("@rules_nats//:extensions.bzl", "nats")
nats.version(version = "2.14.0", cli_version = "0.4.0")
use_repo(nats, "nats_2_14_0_linux_amd64")  # etc.
```

rules_nats's own `nats.version()` always applies (the toolchain uses it); the root module's tags override it per server version and may add versions; other modules' tags are ignored. Before v0.1.2 the root had to set it, or resolution failed with `does not generate repository "nats_2_14_0_linux_amd64"`; the `use_repo` / `register_toolchains` lines earlier READMEs asked for are harmless but no longer needed. Setting one server version with two CLI versions in a module, or an unsupported version, fails naming `nats.version`.

The release archive (the tag tarball) leaves out `tests/` and `tools/`, whose packages load dev-only modules, so `bazel query @rules_nats//...` works for consumers. A `git_override` clone still contains them; name packages instead (for example `@rules_nats//:all`).

The install primitives also require [`rules_kubectl`](https://github.com/collider-bazel-extensions/rules_kubectl) ≥ 0.2.0, a transitive dependency: the macros are thin wrappers around `kubectl_apply`. Pin it in your root module too, because rules_nats's own `git_override` for it applies only when rules_nats is the root.

## Hermetic server primitives

```python
load("@rules_nats//:defs.bzl", "nats_test")

# Run a sh_test against an auto-launched nats_server.
# The trampoline exports NATS_URL / NATS_HOST / NATS_PORT and
# $NATS_CLI, runs the inner test with the target's args, then stops
# the server.
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
