#!/usr/bin/env bash
# Consumer checks against the commit's release archive (git archive honours
# .gitattributes export-ignore, as GitHub's tag tarballs do):
#   1. no nats.version() in the root resolves, and a nats_test runs against
#      rules_nats's own pinned nats-server
#   2. the same tag twice in the root resolves
#   3. an unsupported version fails, naming nats.version
#   4. @rules_nats//... loads (tests/ and tools/ are not shipped)
# Usage: .github/consumer/check.sh <scratch dir>
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
work="$1"
src="$work/rules_nats"
rm -rf "$work"; mkdir -p "$src"
git -C "$repo" archive HEAD | tar -x -C "$src"
for d in tests tools; do
    if [[ -e "$src/$d" ]]; then echo "FAIL: archive contains $d/" >&2; exit 1; fi
done
own="$(grep '^nats.version(' "$src/MODULE.bazel")"
own_version="$(sed -n 's/.*[( ]version = "\([^"]*\)".*/\1/p' <<<"$own")"
own_cli="$(sed -n 's/.*cli_version = "\([^"]*\)".*/\1/p' <<<"$own")"
[[ -n "$own_version" && -n "$own_cli" ]] || { echo "FAIL: no nats.version() in MODULE.bazel" >&2; exit 1; }
kubectl_commit="$(grep -A3 'module_name = "rules_kubectl"' "$src/MODULE.bazel" | sed -n 's/.*commit = "\([0-9a-f]*\)".*/\1/p')"

consumer() { # <name> <extra MODULE.bazel lines>
    local c="$work/$1"
    mkdir -p "$c"
    if [[ -f "$repo/.bazelversion" ]]; then cp "$repo/.bazelversion" "$c/"; fi
    cat > "$c/MODULE.bazel" <<MOD
module(name = "consumer")
bazel_dep(name = "rules_nats")
local_path_override(module_name = "rules_nats", path = "$src")
bazel_dep(name = "rules_kubectl", version = "0.2.0")
git_override(
    module_name = "rules_kubectl",
    remote = "https://github.com/collider-bazel-extensions/rules_kubectl",
    commit = "$kubectl_commit",
)
$2
MOD
    cat > "$c/BUILD.bazel" <<'BUILD'
load("@rules_nats//:defs.bzl", "nats_test")

nats_test(
    name = "pub_test",
    srcs = ["pub_test.sh"],
    jetstream = False,
)
BUILD
    cat > "$c/pub_test.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
"$NATS_CLI" --server "$NATS_URL" pub consumer.check hello
SH
    chmod +x "$c/pub_test.sh"
    echo "$c"
}

# 1. No nats.version(): resolves; a nats_test runs; the server is rules_nats's own.
c="$(consumer untagged "")"
(cd "$c" && bazel mod deps >/dev/null && bazel test //:pub_test --test_output=errors)
server="$(cd "$c" && bazel info output_base)/external/rules_nats++nats+nats_${own_version//./_}_linux_amd64"
[[ -d "$server" ]] || { echo "FAIL: no repo for nats-server $own_version" >&2; exit 1; }
echo "PASS: untagged root resolves, nats_test runs against nats-server $own_version"

# 2. The same tag twice in the root.
c="$(consumer twice "nats = use_extension(\"@rules_nats//:extensions.bzl\", \"nats\")
nats.version(version = \"$own_version\", cli_version = \"$own_cli\")
nats.version(version = \"$own_version\", cli_version = \"$own_cli\")")"
(cd "$c" && bazel mod deps >/dev/null && bazel build //:pub_test)
echo "PASS: repeated identical nats.version resolves"

# 3. An unsupported version fails with a message naming nats.version.
c="$(consumer unsupported "nats = use_extension(\"@rules_nats//:extensions.bzl\", \"nats\")
nats.version(version = \"0.0.1\", cli_version = \"$own_cli\")")"
if (cd "$c" && bazel mod deps) > "$work/unsupported.out" 2>&1; then
    echo "FAIL: unsupported version resolved" >&2; exit 1
fi
grep -q 'nats.version(version = "0.0.1") is not supported' "$work/unsupported.out" || {
    cat "$work/unsupported.out" >&2; echo "FAIL: unsupported version: wrong error" >&2; exit 1; }
echo "PASS: unsupported version fails clearly"

# 4. //... loads.
(cd "$work/untagged" && bazel query @rules_nats//... >/dev/null)
echo "PASS: @rules_nats//... loads"
