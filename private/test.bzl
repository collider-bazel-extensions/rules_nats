"""nats_test — sh_test macro that auto-launches a nats_server in the
background and exec's the user's test with NATS_URL etc. in env.

Each `nats_test` target gets:
  - Its own `nats_server` (target-name-suffixed → unique env file).
  - A static trampoline that launches the server, waits for its env
    file, sources NATS_URL / NATS_HOST / NATS_PORT, exec's the user's
    test binary.

No shared state between tests → safe under `--jobs=N` parallelism.
Mirrors `rules_pg`'s `pg_test` shape.
"""

load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
load("@rules_shell//shell:sh_test.bzl", "sh_test")
load(":server.bzl", "nats_server")

def nats_test(
        name,
        srcs,
        deps = None,
        data = None,
        size = "medium",
        timeout = None,
        tags = None,
        jetstream = True,
        env = None,
        **kwargs):
    """sh_test that auto-launches a nats_server in the background.

    Args:
      name: target name.
      srcs: shell sources for the user's test logic (passed to a
        sh_binary inner target).
      deps: forwarded to the inner sh_binary.
      data: forwarded to the inner sh_binary.
      size: sh_test size (default "medium").
      timeout: sh_test timeout.
      tags: sh_test tags.
      jetstream: enable JetStream on the auto-launched server (default True).
      env: forwarded to sh_test (the wrapper sets NATS_URL on top).
      **kwargs: forwarded to sh_test.
    """

    server_name = name + "_nats_server"
    nats_server(
        name = server_name,
        jetstream = jetstream,
        tags = (tags or []) + ["manual"],
    )

    inner_name = name + "_inner"
    sh_binary(
        name = inner_name,
        srcs = srcs,
        deps = deps,
        data = data,
        tags = (tags or []) + ["manual"],
    )

    sh_test(
        name = name,
        srcs = ["@rules_nats//private:nats_test_trampoline.sh"],
        args = [
            "$(rootpath :{})".format(server_name),
            "$(rootpath :{})".format(inner_name),
            server_name,  # env-file basename = <server target name>.env
        ],
        data = [
            ":" + server_name,
            ":" + inner_name,
        ],
        size = size,
        timeout = timeout,
        tags = tags,
        env = env,
        **kwargs
    )
