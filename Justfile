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
