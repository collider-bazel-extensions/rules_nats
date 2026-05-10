"""nats_toolchain — exposes the platform-resolved nats-server + nats
CLI binaries as a `ToolchainInfo` so consumer rules resolve them via
`ctx.toolchains[...]`.
"""

load("//private:providers.bzl", "NatsBinaryInfo")

NATS_TOOLCHAIN_TYPE = Label("//toolchain:nats")

def _toolchain_impl(ctx):
    info = NatsBinaryInfo(
        server_version  = ctx.attr.server_version,
        cli_version     = ctx.attr.cli_version,
        nats_server_bin = ctx.file.nats_server_bin,
        nats_cli_bin    = ctx.file.nats_cli_bin,
    )
    return [
        platform_common.ToolchainInfo(nats = info),
        DefaultInfo(
            files = depset([ctx.file.nats_server_bin, ctx.file.nats_cli_bin]),
            runfiles = ctx.runfiles(files = [ctx.file.nats_server_bin, ctx.file.nats_cli_bin]),
        ),
    ]

nats_toolchain = rule(
    implementation = _toolchain_impl,
    attrs = {
        "server_version":  attr.string(mandatory = True),
        "cli_version":     attr.string(mandatory = True),
        "nats_server_bin": attr.label(allow_single_file = True, mandatory = True),
        "nats_cli_bin":    attr.label(allow_single_file = True, mandatory = True),
    },
)
