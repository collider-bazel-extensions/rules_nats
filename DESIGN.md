# rules_nats — design notes

## Two-family-in-one-repo shape

NATS consumers come in two flavors:
- App-test consumers want a hermetic in-process server they can pub/sub against (the rules_pg / rules_temporal pattern). This is the high-leverage primitive — most NATS app code wants a per-test server with no shared state.
- Cluster operators want a manifest applied to a real cluster for E2E reconciliation (the rules_loki / rules_kafka pattern).

Splitting the two into separate rule sets would force any consumer that needs both (rare today, plausible tomorrow) to learn two install patterns. Same conclusion rules_atlas / rules_temporal v0.3 reached.

## Hermetic server: bind-then-close port allocation

`nats_server` picks a free port via `python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()'` — bind ephemeral, read the port, close before launching nats-server. Same TOCTOU race rules_pg accepts; nats-server retries on EADDRINUSE and the launcher's polling loop catches transient bind failures.

The `--socket-fd` patch shenanigans rules_pg deals with on PG 14–17 (a Debian-only postgres-common patch) don't apply here — nats-server's CLI doesn't have an equivalent socket-passing flag, and the bind-then-close window is small enough in practice that we don't bother.

## env file convention

`$TEST_TMPDIR/<name>.env` written atomically via `.tmp + rename`. Keys:

- `NATS_URL` — `nats://127.0.0.1:<port>`
- `NATS_HOST` — `127.0.0.1`
- `NATS_PORT` — port number

Same convention `pg_server` uses for `PGHOST/PGPORT/...`. Consumers can `source $env_file` and have ready-to-use connection vars.

## `nats_test` trampoline

The trampoline is a static script in `private/`. The macro emits:

1. A `nats_server` target (UUID-suffixed by parent test name → unique env file).
2. An inner `sh_binary` carrying the user's test logic.
3. A `sh_test` whose `srcs` is the trampoline; `args` pass the server short_path + inner short_path + server target name. The trampoline launches the server, polls the env file, sources it, exec's the inner.

Trampoline also exports `$NATS_CLI` (resolved from runfiles) so consumer tests can shell out to the toolchain CLI without re-resolving it.

### `find -L` for the CLI lookup

The CLI in runfiles is a symlink, not a regular file. `find -path '*/cli/nats' -type f` (without `-L`) silently returns nothing — `-type f` excludes symlinks unless `-L` is passed to follow them. Caught locally on the first run.

## Substitution markers: `__KEY__`

Server template uses bash heavily (`${TEST_TMPDIR:-/tmp}`, `${ENV_FILE_NAME%.env}`, etc.). `{KEY}` markers would collide with bash's `${...}` syntax (the lesson from rules_atlas v0.2). All substitution markers are `__KEY__`.

## Cluster install: chart .tgz, not source tarball

NATS publishes the chart as a packaged `.tgz` at the GitHub release (`github.com/nats-io/k8s/releases/download/nats-2.12.6/nats-2.12.6.tgz`). Smaller than the source tarball (~21KB vs full repo), digest matches the helm-repo index for cross-verification, and helm_template can point directly at the extracted chart root without a subpath strip. Same shape as rules_loki uses for the Grafana helm-charts release.

## Install smoke: `nats-box` for kubectl-exec

The chart deploys a `nats-box` Deployment (a small sidecar pod with the `nats` CLI baked in). The smoke `kubectl exec`s into that pod for the JetStream pub/consume round-trip — no need to mount the host CLI, and the CLI lives in the same network namespace as the server.

## What this repo does not (yet) do

- **NACK** — the JetStream-CRDs operator (Stream / Consumer / KeyValue / ObjectStore as Kubernetes CRs) at https://github.com/nats-io/nack. Out of scope for v0.1's surface; v0.2 candidate. Consumers can apply the NACK manifest separately while `nats_install` provides the server.
- **NATS clustering** — the rendered chart is single-replica. Multi-replica clusters with leaf nodes / supercluster topology are configurable at the maintainer-render layer; consumers would need to edit `tools/values.yaml` and re-render. Not currently parameterized.
- **TLS / auth** — chart default is plaintext. Production deploys override at the maintainer-render layer.
- **`nats_test` Go/Python adapter** — the smoke uses the `nats` CLI for round-trip assertions. App code that uses the Go `nats.go` SDK or Python `nats.py` SDK works identically with `NATS_URL`; we don't ship a language-specific helper.
