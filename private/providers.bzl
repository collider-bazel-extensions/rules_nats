"""Providers exposed by rules_nats."""

NatsBinaryInfo = provider(
    doc = "NATS toolchain binaries — server + CLI.",
    fields = {
        "server_version":   "string — pinned nats-server version",
        "cli_version":      "string — pinned natscli version",
        "nats_server_bin":  "File — the nats-server executable",
        "nats_cli_bin":     "File — the `nats` CLI executable",
    },
)
