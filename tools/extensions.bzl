"""Maintainer-only chart-fetch — fires only when rules_nats is the
root module. Consumers don't pull the chart .tgz.
"""

load("//tools:repositories.bzl", "nats_chart_repository")

_version_tag = tag_class(attrs = {
    "version": attr.string(mandatory = True),
})

def _impl(mctx):
    for mod in mctx.modules:
        if not mod.is_root:
            continue
        for tag in mod.tags.version:
            nats_chart_repository(
                name = "nats_chart_" + tag.version.replace(".", "_"),
                version = tag.version,
            )

nats_chart = module_extension(
    implementation = _impl,
    tag_classes = {"version": _version_tag},
)
