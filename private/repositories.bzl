"""Per-platform NATS repo: downloads nats-server tar.gz + nats CLI
zip at the pinned shas, exposes both binaries as a single filegroup.
"""

load(":versions.bzl", "NATS_CLI_VERSIONS", "NATS_SERVER_VERSIONS")

_BUILD_TMPL = """\
package(default_visibility = ["//visibility:public"])

# nats-server: extracted from the server tarball.
filegroup(
    name = "nats_server_bin",
    srcs = ["nats-server"],
)

# nats CLI: extracted from the CLI zip into a sibling subdir to
# avoid name collision (the zip's payload is just `nats`).
filegroup(
    name = "nats_cli_bin",
    srcs = ["cli/nats"],
)

# Both binaries together — for runfiles staging.
filegroup(
    name = "all_bins",
    srcs = [
        ":nats_server_bin",
        ":nats_cli_bin",
    ],
)
"""

def _impl(rctx):
    server_version = rctx.attr.server_version
    cli_version = rctx.attr.cli_version
    platform = rctx.attr.platform

    if server_version not in NATS_SERVER_VERSIONS:
        fail("rules_nats: unknown nats-server version '{}'. Known: {}".format(
            server_version, sorted(NATS_SERVER_VERSIONS.keys()),
        ))
    if cli_version not in NATS_CLI_VERSIONS:
        fail("rules_nats: unknown nats CLI version '{}'. Known: {}".format(
            cli_version, sorted(NATS_CLI_VERSIONS.keys()),
        ))

    server_pin = NATS_SERVER_VERSIONS[server_version].get(platform)
    cli_pin = NATS_CLI_VERSIONS[cli_version].get(platform)
    if not server_pin or not cli_pin:
        fail("rules_nats: platform '{}' missing in version pins".format(platform))

    # Server tarball — extracts a single `nats-server` binary at the
    # repo root after stripping the version-prefixed dir.
    rctx.download_and_extract(
        url = server_pin["url"],
        sha256 = server_pin["sha256"],
        stripPrefix = server_pin["strip_prefix"],
    )

    # CLI zip — extracts to a sibling `cli/` subdir so the tarball's
    # `nats-server` and the CLI's `nats` binary don't sit in the same
    # directory (they would otherwise be fine, but separating them
    # keeps the BUILD filegroups unambiguous).
    rctx.download_and_extract(
        url = cli_pin["url"],
        output = "cli",
        sha256 = cli_pin["sha256"],
        stripPrefix = cli_pin["strip_prefix"],
    )

    rctx.file("WORKSPACE", "workspace(name = \"{}\")\n".format(rctx.name))
    rctx.file("BUILD.bazel", _BUILD_TMPL)

nats_binary_repo = repository_rule(
    implementation = _impl,
    attrs = {
        "server_version": attr.string(mandatory = True),
        "cli_version":    attr.string(mandatory = True),
        "platform":       attr.string(mandatory = True),
    },
)
