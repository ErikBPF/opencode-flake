# opencode-flake maintenance recipes

# Fast eval check
check:
    nix flake check --no-build

# Full check suite (schema validation, module render, lint)
check-full:
    nix flake check

# Format the tree
fmt:
    nix fmt .

# Exit 1 if upstream opencode is newer than the package
update-check:
    ./scripts/update-opencode.sh --check

# Update the packaged opencode to the latest upstream release
update:
    ./scripts/update-opencode.sh

# Pin the packaged opencode to a specific version
update-to VERSION:
    ./scripts/update-opencode.sh --version {{VERSION}}

# V2 is an independent official npm binary lane; V1 recipes stay unchanged.
update-v2-check:
    ./scripts/update-opencode-v2.sh --check

update-v2:
    ./scripts/update-opencode-v2.sh

update-v2-to VERSION:
    ./scripts/update-opencode-v2.sh --version {{quote(VERSION)}}
