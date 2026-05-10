"""nats_server + nats_health_check — hermetic NATS test fixtures.

`nats_server` produces a long-running executable that:

  1. Picks a free TCP port (bind-ephemeral-then-close — accepts a
     small TOCTOU race; nats-server retries on EADDRINUSE and rebinds
     fast enough that the race rarely fires).
  2. Writes a minimal `nats-server.conf` to `$TEST_TMPDIR/<name>/`
     with the chosen port + JetStream enabled (default; toggle via
     the `jetstream` attr).
  3. Launches `nats-server -c <conf>` in the foreground.
  4. Polls the port; once the server accepts a TCP connect, writes
     `$TEST_TMPDIR/<name>.env` with `NATS_URL=nats://127.0.0.1:<port>`
     atomically (write to .tmp + rename).
  5. signal.pause() — exits cleanly on SIGTERM (rules_itest sends it
     during teardown; bazel test's TEST_TMPDIR cleanup nukes the
     server's storage too).

`nats_health_check` produces a one-shot binary that exits 0 if and
only if the env file has been written. Drops into
`itest_service.health_check`.

Convention env keys (consumers can `source $TEST_TMPDIR/<name>.env`):
  - NATS_URL — `nats://127.0.0.1:<port>`
  - NATS_HOST — `127.0.0.1`
  - NATS_PORT — the port number
"""

load("//private:providers.bzl", "NatsBinaryInfo")

NatsServerInfo = provider(
    doc = "rules_nats nats_server target output.",
    fields = {
        "binary": "NatsBinaryInfo: the toolchain's binaries.",
    },
)

def _nats_server_impl(ctx):
    tc = ctx.toolchains["//toolchain:nats"]
    info = tc.nats

    env_file_name = ctx.label.name + ".env"

    wrapper = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.expand_template(
        template = ctx.file._tmpl,
        output = wrapper,
        substitutions = {
            "__NATS_SERVER_BIN__": info.nats_server_bin.short_path,
            "__ENV_FILE_NAME__":   env_file_name,
            "__JETSTREAM__":       "true" if ctx.attr.jetstream else "false",
        },
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [
        info.nats_server_bin,
        info.nats_cli_bin,
        wrapper,
    ])

    return [
        DefaultInfo(executable = wrapper, runfiles = runfiles),
        NatsServerInfo(binary = info),
    ]

nats_server = rule(
    implementation = _nats_server_impl,
    executable = True,
    attrs = {
        "jetstream": attr.bool(
            default = True,
            doc = "Enable JetStream (persistence) in the server config. " +
                  "Default True — most NATS use cases want JetStream. " +
                  "Set False for plain pub/sub-only fixtures.",
        ),
        "_tmpl": attr.label(
            default = "//private:server.sh.tmpl",
            allow_single_file = True,
        ),
    },
    toolchains = ["//toolchain:nats"],
)

# ---- nats_health_check ------------------------------------------------------

def _nats_health_check_impl(ctx):
    server_label = ctx.attr.server.label
    env_file_name = server_label.name + ".env"

    wrapper = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.expand_template(
        template = ctx.file._tmpl,
        output = wrapper,
        substitutions = {
            "__ENV_FILE_NAME__": env_file_name,
        },
        is_executable = True,
    )

    return [DefaultInfo(executable = wrapper)]

nats_health_check = rule(
    implementation = _nats_health_check_impl,
    executable = True,
    attrs = {
        "server": attr.label(
            mandatory = True,
            providers = [NatsServerInfo],
            doc = "The nats_server target this health check pairs with. " +
                  "The check exits 0 once the server has written its env " +
                  "file (the same convention pg_health_check follows for " +
                  "pg_server).",
        ),
        "_tmpl": attr.label(
            default = "//private:health_check.sh.tmpl",
            allow_single_file = True,
        ),
    },
)
