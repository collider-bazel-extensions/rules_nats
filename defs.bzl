"""Public API for rules_nats.

Hermetic server (test-time):
  nats_server         — long-running nats-server fixture; writes
                        $TEST_TMPDIR/<name>.env with NATS_URL when ready.
  nats_health_check   — pairs with nats_server for itest_service compositions.
  nats_test           — sh_test macro that auto-launches a nats_server
                        and exec's the user test with NATS_URL in env.

Cluster install (kind / production):
  nats_install              — applies the pinned NATS Helm chart into
                              a cluster.
  nats_install_health_check — paired readiness probe.
"""

load("//private:install.bzl",
     _nats_install = "nats_install",
     _nats_install_health_check = "nats_install_health_check")
load("//private:providers.bzl",
     _NatsBinaryInfo = "NatsBinaryInfo")
load("//private:server.bzl",
     _nats_server = "nats_server",
     _nats_health_check = "nats_health_check",
     _NatsServerInfo = "NatsServerInfo")
load("//private:test.bzl", _nats_test = "nats_test")

nats_server = _nats_server
nats_health_check = _nats_health_check
nats_test = _nats_test
nats_install = _nats_install
nats_install_health_check = _nats_install_health_check

NatsBinaryInfo = _NatsBinaryInfo
NatsServerInfo = _NatsServerInfo
