#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# Keep V2 inside the existing required CI gate, without replacing V1.
missing=0
for contract in \
  'scripts/update-opencode-v2.sh|' \
  'Justfile|update-v2-check:' \
  'Justfile|update-v2:' \
  'Justfile|update-v2-to VERSION:' \
  'checks.nix|updater-v2-mutation-only =' \
  '.github/workflows/check.yml|for package in opencode opencode-v2; do'; do
  file="${contract%%|*}"
  pattern="${contract#*|}"
  if ! test -f "$root/$file" || ! grep -Fq "$pattern" "$root/$file"; then
    printf 'FAIL: missing V2 contract: %s\n' "$contract" >&2
    missing=1
  fi
done
test "$missing" = 0 || exit 1
grep -Fq 'tests/opencode-v2-contract.sh' "$root/checks.nix" || fail 'V2 test not registered'
# shellcheck disable=SC2016 # Match literal workflow expressions.
grep -Fq 'nix build ".#$package"' "$root/.github/workflows/check.yml" || fail 'CI must build both packages'
# shellcheck disable=SC2016
grep -Fq 'grep -Fx -e "$version" -e "opencode v$version"' "$root/.github/workflows/check.yml" || fail 'CI must assert exact V1/V2 version output'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/source/packages/opencode" "$tmp/source/packages/opencode-v2" "$tmp/source/scripts" "$tmp/bin"
cp "$root/Justfile" "$tmp/source/"
cp "$root/scripts/update-opencode-v2.sh" "$tmp/source/scripts/"
cp "$root/flake.nix" "$tmp/source/"
cp "$root/packages/opencode/package.nix" "$tmp/source/packages/opencode/"
cp "$root/packages/opencode-v2/package.nix" "$tmp/source/packages/opencode-v2/"
cp "$root/scripts/update-opencode-v2.sh" "$tmp/source/update.sh"
cp "$tmp/source/packages/opencode/package.nix" "$tmp/v1-before"
cd "$tmp/source"

cat > "$tmp/bin/curl" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$TEST_REQUEST"
test "${TEST_CURL_FAIL:-0}" = 0 || exit 22
cat "$TEST_METADATA"
SH
cat > "$tmp/bin/nix" <<'SH'
#!/usr/bin/env bash
printf 'unexpected nix invocation\n' >&2
touch "$TEST_NIX_CALLED"
exit 125
SH
sed -i "1c#!$(command -v bash)" "$tmp/bin/curl" "$tmp/bin/nix"
cp "$tmp/bin/nix" "$tmp/bin/nix-update"
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"
export TEST_METADATA="$tmp/metadata.json" TEST_REQUEST="$tmp/request" TEST_NIX_CALLED="$tmp/nix-called"

integrity='sha512-QPGrzBSSs5ATG3nM4XjS4tmWXUB22Di36H0vfMuhKwk6i3PR3Nb4sm+l00gvTdcyCRohYsKwqjvD67T0DPcQLQ=='
jq -n --arg hash "$integrity" '{name:"@opencode/cli-linux-x64",version:"2.99.0",dist:{integrity:$hash,tarball:"https://registry.npmjs.org/@opencode/cli-linux-x64/-/cli-linux-x64-2.99.0.tgz"}}' > "$TEST_METADATA"

expect_status() {
  local expected="$1" status=0
  shift
  bash ./update.sh "$@" > "$tmp/output" 2>&1 || status=$?
  if test "$status" != "$expected"; then
    cat "$tmp/output" >&2
    fail "updater $*: exit $status, expected $expected"
  fi
}

cp packages/opencode-v2/package.nix "$tmp/v2-before"
status=0
just update-v2-to 'bad; printf V2_RECIPE_INJECTION' > "$tmp/recipe-output" 2>&1 || status=$?
test "$status" != 0 || fail 'recipe masked invalid-version failure with shell injection'
! grep -Fxq 'V2_RECIPE_INJECTION' "$tmp/recipe-output" || fail 'recipe executed version as shell syntax'
cmp packages/opencode-v2/package.nix "$tmp/v2-before" || fail 'invalid recipe argument mutated V2'
expect_status 1 --check
cmp packages/opencode-v2/package.nix "$tmp/v2-before" || fail '--check mutated V2'
grep -Fq 'https://registry.npmjs.org/@opencode%2fcli-linux-x64/latest' "$TEST_REQUEST" || fail 'wrong latest endpoint'
expect_status 0 --version 2.99.0
grep -Fq 'version = "2.99.0";' packages/opencode-v2/package.nix || fail 'version not updated'
grep -Fq "hash = \"$integrity\";" packages/opencode-v2/package.nix || fail 'integrity not updated'
grep -Fq 'https://registry.npmjs.org/@opencode%2fcli-linux-x64/2.99.0' "$TEST_REQUEST" || fail 'wrong version endpoint'
sed -e 's/version = "2.99.0";/version = "TEST";/' -e 's/hash = "[^"]*";/hash = "TEST";/' packages/opencode-v2/package.nix > "$tmp/after-normalized"
sed -e 's/version = "[^"]*";/version = "TEST";/' -e 's/hash = "[^"]*";/hash = "TEST";/' "$tmp/v2-before" > "$tmp/before-normalized"
cmp "$tmp/before-normalized" "$tmp/after-normalized" || fail 'updated more than version/hash'
expect_status 0 --check
cp "$TEST_METADATA" "$tmp/valid.json"
cp packages/opencode-v2/package.nix "$tmp/v2-updated"

for filter in '.version = null' '.version = "1.99.0"' '.version = "2.99.1"' '.name = "wrong-package"' '.dist.integrity = "sha512-invalid"' '.dist.tarball = "https://example.com/package.tgz"'; do
  jq "$filter" "$tmp/valid.json" > "$TEST_METADATA"
  expect_status 2 --version 2.99.0
  cmp packages/opencode-v2/package.nix "$tmp/v2-updated" || fail 'invalid metadata mutated V2'
done
printf 'not json\n' > "$TEST_METADATA"
expect_status 2 --version 2.99.0
cat "$tmp/valid.json" "$tmp/valid.json" > "$TEST_METADATA"
expect_status 2 --version 2.99.0
expect_status 2 --version
expect_status 2 --version 1.99.0
export TEST_CURL_FAIL=1
expect_status 2 --check
cmp packages/opencode-v2/package.nix "$tmp/v2-updated" || fail 'failed fetch mutated V2'
cmp packages/opencode/package.nix "$tmp/v1-before" || fail 'V1 package changed'
test ! -e "$TEST_NIX_CALLED" || fail 'updater invoked nix or nix-update'
printf 'PASS: V2 updater isolation, metadata validation, checks and required CI coverage\n'
