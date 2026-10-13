#!/usr/bin/env bash
set -euo pipefail

log() { printf '[opencode-v2-update] %s\n' "$*" >&2; }
die() { log "ERROR: $*"; exit 2; }

check_only=false
target=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --check) check_only=true; shift ;;
    --version)
      [ "$#" -ge 2 ] || die '--version requires a version'
      target="$2"
      [[ "$target" =~ ^2\.[0-9]+\.[0-9]+$ ]] || die 'expected a stable V2 version'
      shift 2 ;;
    --help)
      printf 'Usage: scripts/update-opencode-v2.sh [--check] [--version 2.X.Y]\n'
      exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

readonly package='packages/opencode-v2/package.nix'
[ -f flake.nix ] && [ -f "$package" ] || die 'run from opencode-flake root'
for command in curl jq sed; do
  command -v "$command" >/dev/null 2>&1 || die "$command is required"
done

current="$(sed -n 's/^  version = "\([^"]*\)";/\1/p' "$package")"
current_hash="$(sed -n 's/^      hash = "\([^"]*\)";/\1/p' "$package")"
[[ "$current" =~ ^2\.[0-9]+\.[0-9]+$ ]] && [ -n "$current_hash" ] || die 'malformed package version/hash'
metadata="$(curl -fsSL "https://registry.npmjs.org/@opencode%2fcli-linux-x64/${target:-latest}")" || die 'npm metadata fetch failed'
validated="$(printf '%s\n' "$metadata" | jq -ser --arg target "$target" '
  select(length == 1) | .[0] | select(type == "object")
  | select(.name == "@opencode/cli-linux-x64")
  | select(.version | type == "string" and test("^2\\.[0-9]+\\.[0-9]+$"))
  | select($target == "" or .version == $target)
  | select(.dist.integrity | type == "string" and test("^sha512-[A-Za-z0-9+/]{85}[AQgw]==$"))
  | select(.dist.tarball == ("https://registry.npmjs.org/@opencode/cli-linux-x64/-/cli-linux-x64-" + .version + ".tgz"))
  | [.version, .dist.integrity] | @tsv
')" || die 'malformed npm package metadata'
IFS=$'\t' read -r latest hash <<< "$validated"

log "current: $current"
log "latest:  $latest"
if [ "$current" = "$latest" ] && [ "$current_hash" = "$hash" ]; then
  log 'already up to date'
  exit 0
fi
if [ "$check_only" = true ]; then
  log "update available: $current -> $latest"
  exit 1
fi

# npm supplies the fixed-output SRI hash; updating never builds or runs Nix.
sed -i \
  -e "s|^  version = \"[^\"]*\";|  version = \"$latest\";|" \
  -e "s|^      hash = \"[^\"]*\";|      hash = \"$hash\";|" \
  "$package"
log "updated $package"
