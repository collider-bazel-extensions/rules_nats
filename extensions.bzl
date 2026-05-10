"""Bzlmod extension. Single `version` tag — fetches both nats-server
and nats CLI for each supported platform.
"""

load("//private:repositories.bzl", "nats_binary_repo")
load("//private:versions.bzl", "PLATFORMS")

_version_tag = tag_class(attrs = {
    "version":     attr.string(mandatory = True),  # nats-server version
    "cli_version": attr.string(mandatory = True),  # nats CLI version
})

def _impl(mctx):
    # Only honor `version` tags from the root module — same is_root
    # guard as rules_opa / rules_atlas / rules_kind. Without this,
    # rules_nats's own MODULE.bazel and the consumer would each emit
    # `@nats_<ver>_<plat>` repos and Bazel would collide them.
    for mod in mctx.modules:
        if not mod.is_root:
            continue
        for tag in mod.tags.version:
            for plat in PLATFORMS.keys():
                nats_binary_repo(
                    name = "nats_{}_{}".format(
                        tag.version.replace(".", "_"),
                        plat,
                    ),
                    server_version = tag.version,
                    cli_version    = tag.cli_version,
                    platform       = plat,
                )

nats = module_extension(
    implementation = _impl,
    tag_classes = {"version": _version_tag},
)
