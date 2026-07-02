# opencode-flake

Home Manager **profile module** for [opencode](https://opencode.ai). It layers
opinionated policy on top of upstream `programs.opencode` — it does not
reimplement config rendering, and it does not manage auth or session state
(`~/.local/share/opencode/`).

Design record: `desktop-nixos/docs/proposals/2026-07-01-opencode-flake.md`
(decisions D1–D6).

## What it manages

- **Permission guardrails** (on by default): allow-by-default with secrets
  (`*.sops`, `.env*`, `*.age`, `secrets/`) denied for edit, `flake.lock`
  edits behind a prompt, destructive / raw remote-deploy shell commands
  denied.
- **mcp-nixos** MCP server entry (on by default).
- **Global `AGENTS.md`** via `programs.opencode.context`: preamble, optional
  caveman response style, free-form extra text.
- **`OPENCODE_DISABLE_CLAUDE_CODE=1`** (on by default): opencode must not
  fall back to `~/.claude/CLAUDE.md`; the profile owns its instructions.
- **RTK plugin** (opt-in): installs `plugins/rtk.ts`, which rewrites bash
  tool commands through `rtk rewrite`. Requires `rtk` on PATH at runtime.
- **TUI** (opt-in): tokyonight theme, attention sounds, `ctrl+x` leader.
- **Package**: upstream's default (`pkgs.opencode`) — the conservative
  lane; a future `withPackage` module will provide the flake-owned fast
  lane. Override `programs.opencode.package` directly. A files-only profile
  (`package = null`) is not possible: upstream crashes on it
  (`versionAtLeast null` in its tui deprecation warning) — worth an
  upstream report.

## Usage

```nix
{
  inputs.opencode-flake.url = "github:ErikBPF/opencode-flake";

  # in home-manager config:
  imports = [inputs.opencode-flake.homeManagerModules.default];

  programs.opencode-profile = {
    enable = true;
    tui.enable = true;
    rtk.enable = true;
    style.enable = true;
    style.level = "lite";
  };
}
```

Provider policy deliberately stays out of this flake (decision D3) — set
`programs.opencode.settings.provider` host-side; attrsets merge with the
profile's settings.

## Fast package lane

The flake owns a vendored `packages.opencode` (nixpkgs expression with the
`passthru.jsonschema` bug fixed) so consumers can get opencode releases
without waiting for their nixpkgs pin:

```nix
imports = [inputs.opencode-flake.homeManagerModules.withPackage];
```

A daily workflow checks upstream `anomalyco/opencode` releases, bumps
version + hashes via `nix-update --subpackage node_modules`, builds and
smoke-tests, then opens an auto-merge PR gated on required checks (which
include the package build). Merges to main are tagged `opencode-vX.Y.Z`
and published to FlakeHub as rolling releases.

## Trust modes

- **Rolling** (FlakeHub wildcard / `main`): every commit that passed the
  required checks, fastest.
- **Version pin** (`opencode-vX.Y.Z` tag): reproducible, best default.
- **Commit pin**: highest assurance, combine with local builds.

What you trust with `withPackage`: this repo's update workflow (SHA-pinned
actions, auto-merge only after required checks), upstream release
artifacts, and the binary cache if one is configured. The default module
without `withPackage` uses your own nixpkgs' `pkgs.opencode` instead.

## Checks

`nix flake check` validates the rendered `opencode.json` / `tui.json`
against the JSON schemas shipped by `pkgs.opencode`
(`passthru.jsonschema`), asserts the guardrails/context/plugin render, and
asserts the off-by-default posture (no package, no tui.json, no plugin).

## Roadmap

- Cachix binary cache: workflow step is wired (cache `erikbpf`) but dormant
  until the cache exists and `CACHIX_AUTH_TOKEN` is set in repo secrets.
- desktop-nixos adoption + laptop config migration (RFC §5).
