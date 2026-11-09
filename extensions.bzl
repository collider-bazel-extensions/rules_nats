"""Bzlmod extension. Single `version` tag — fetches both nats-server
and nats CLI for each supported platform.
"""

load("//private:repositories.bzl", "nats_binary_repo")
load("//private:versions.bzl", "NATS_CLI_VERSIONS", "NATS_SERVER_VERSIONS", "PLATFORMS")

_version_tag = tag_class(attrs = {
    "version":     attr.string(mandatory = True),  # nats-server version
    "cli_version": attr.string(mandatory = True),  # nats CLI version
})

def _pins(mod):
    """{nats-server version: nats CLI version} from one module's tags."""
    out = {}
    for tag in mod.tags.version:
        if tag.version in out and out[tag.version] != tag.cli_version:
            fail("rules_nats: module {} sets nats.version(version = \"{}\") with cli_version {} and {}; set one.".format(
                mod.name,
                tag.version,
                out[tag.version],
                tag.cli_version,
            ))
        out[tag.version] = tag.cli_version
    return out

def _impl(mctx):
    # The extension runs once for the whole build and sees every module's
    # tags, but the `@nats_<ver>_<plat>` repos it creates are global, so each
    # is created once. rules_nats's own MODULE.bazel imports its pinned
    # version's repos and registers the toolchain for every consumer, so its
    # own tags always apply (a root without nats.version() used to fail:
    # `does not generate repository "nats_2_14_0_linux_amd64"`); the root
    # module's tags override them per server version and may add versions.
    # Other modules' tags are ignored.
    pins = {}
    for mod in mctx.modules:
        if mod.name == "rules_nats" and not mod.is_root:
            pins.update(_pins(mod))
    for mod in mctx.modules:
        if mod.is_root:
            pins.update(_pins(mod))
    for version, cli_version in pins.items():
        if version not in NATS_SERVER_VERSIONS:
            fail("rules_nats: nats.version(version = \"{}\") is not supported. Supported: {}".format(
                version,
                ", ".join(sorted(NATS_SERVER_VERSIONS.keys())),
            ))
        if cli_version not in NATS_CLI_VERSIONS:
            fail("rules_nats: nats.version(cli_version = \"{}\") is not supported. Supported: {}".format(
                cli_version,
                ", ".join(sorted(NATS_CLI_VERSIONS.keys())),
            ))
        for plat in PLATFORMS.keys():
            nats_binary_repo(
                name = "nats_{}_{}".format(
                    version.replace(".", "_"),
                    plat,
                ),
                server_version = version,
                cli_version    = cli_version,
                platform       = plat,
            )

nats = module_extension(
    implementation = _impl,
    tag_classes = {"version": _version_tag},
)
