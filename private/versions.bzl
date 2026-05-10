"""nats-server + natscli binary pins.

Each entry pairs a `nats-server` major.minor.patch with a
`natscli` major.minor.patch — the two are released independently
upstream, so a consumer pinning `nats.version(version =
"2.14.0", cli_version = "0.4.0")` selects both sides.

Maintainer flow:
    bash tools/update_versions.sh <server-ver> <cli-ver>

URL scheme:
- nats-server: tar.gz from
    https://github.com/nats-io/nats-server/releases/download/v<ver>/nats-server-v<ver>-<plat>.tar.gz
  (extracts to `nats-server-v<ver>-<plat>/nats-server`)
- nats CLI: zip (NOT tar.gz) from
    https://github.com/nats-io/natscli/releases/download/v<ver>/nats-<ver>-<plat>.zip
  (extracts to `nats-<ver>-<plat>/nats`)

SHA256 sums for both come from the release's SHA256SUMS asset.
"""

NATS_SERVER_VERSIONS = {
    "2.14.0": {
        "linux_amd64": {
            "url": "https://github.com/nats-io/nats-server/releases/download/v2.14.0/nats-server-v2.14.0-linux-amd64.tar.gz",
            "sha256": "3d8b74dfad39af184c765a6dd120441ed1c648d6672eddf6b304f222661251b8",
            "strip_prefix": "nats-server-v2.14.0-linux-amd64",
        },
        "linux_arm64": {
            "url": "https://github.com/nats-io/nats-server/releases/download/v2.14.0/nats-server-v2.14.0-linux-arm64.tar.gz",
            "sha256": "ce7dc5f7d97b70dabc38b13157fed28d7d06227860676143c15c62c5c297996c",
            "strip_prefix": "nats-server-v2.14.0-linux-arm64",
        },
        "darwin_amd64": {
            "url": "https://github.com/nats-io/nats-server/releases/download/v2.14.0/nats-server-v2.14.0-darwin-amd64.tar.gz",
            "sha256": "c307afaa5810dea24bfe5bb0cd895ddc7c47946f359823336ef3be1a41bdddfa",
            "strip_prefix": "nats-server-v2.14.0-darwin-amd64",
        },
        "darwin_arm64": {
            "url": "https://github.com/nats-io/nats-server/releases/download/v2.14.0/nats-server-v2.14.0-darwin-arm64.tar.gz",
            "sha256": "36f28cf166e5ae5dd88d700a609c810b97ffad641e0c51b49cf8fae25fb3fac7",
            "strip_prefix": "nats-server-v2.14.0-darwin-arm64",
        },
    },
}

NATS_CLI_VERSIONS = {
    "0.4.0": {
        "linux_amd64": {
            "url": "https://github.com/nats-io/natscli/releases/download/v0.4.0/nats-0.4.0-linux-amd64.zip",
            "sha256": "8dbd437c826b953dbd7432cf890ef22ba3c33dccc3dce5e71b3e8d055427849c",
            "strip_prefix": "nats-0.4.0-linux-amd64",
        },
        "linux_arm64": {
            "url": "https://github.com/nats-io/natscli/releases/download/v0.4.0/nats-0.4.0-linux-arm64.zip",
            "sha256": "9ce0c8a6653cd697d0b32687fcb53b59c13a2ad7a6ade7af8ad8a1c0f7357a87",
            "strip_prefix": "nats-0.4.0-linux-arm64",
        },
        "darwin_amd64": {
            "url": "https://github.com/nats-io/natscli/releases/download/v0.4.0/nats-0.4.0-darwin-amd64.zip",
            "sha256": "87cbc208a9fb1dcd3be364ab351a14901c9c29d50ef6a7a2fd897362dbb0db47",
            "strip_prefix": "nats-0.4.0-darwin-amd64",
        },
        "darwin_arm64": {
            "url": "https://github.com/nats-io/natscli/releases/download/v0.4.0/nats-0.4.0-darwin-arm64.zip",
            "sha256": "39a68a0673f1b87d0887f48b02ca17f5d803f5689d4a9cff8e74b6411d6baef7",
            "strip_prefix": "nats-0.4.0-darwin-arm64",
        },
    },
}

PLATFORMS = {
    "linux_amd64":  ["@platforms//os:linux", "@platforms//cpu:x86_64"],
    "linux_arm64":  ["@platforms//os:linux", "@platforms//cpu:arm64"],
    "darwin_amd64": ["@platforms//os:osx",   "@platforms//cpu:x86_64"],
    "darwin_arm64": ["@platforms//os:osx",   "@platforms//cpu:arm64"],
}
