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
