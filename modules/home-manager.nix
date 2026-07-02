{
  config,
  lib,
  ...
}: let
  cfg = config.programs.opencode-profile;
  inherit (lib) mkEnableOption mkIf mkOption optionalString types;

  # opencode permission rules are last-match-wins, and upstream renders
  # `settings` with a DAG-ordered JSON generator: pin every specific rule
  # after the "*" catch-all instead of relying on attr-name sort order.
  # Each rule is mkDefault so a consumer can override one leaf without
  # mkForce.
  rule = value: lib.mkDefault (lib.hm.dag.entryAfter ["*"] value);

  # G1 permission guardrails: yolo defaults, secrets denied, raw remote
  # deploys denied (correct paths go through `just` recipes).
  permissionDefaults = {
    edit = {
      "*" = lib.mkDefault "allow";
      "flake.lock" = rule "ask";
      "**/*.sops" = rule "deny";
      "**/.env.sops" = rule "deny";
      "**/.env" = rule "deny";
      "**/.env.*" = rule "deny";
      "secrets/**" = rule "deny";
      "**/*.age" = rule "deny";
    };
    bash = {
      "*" = lib.mkDefault "allow";
      "rm -rf /*" = rule "deny";
      "rm -rf ~*" = rule "deny";
      "docker volume rm *" = rule "deny";
      "nixos-rebuild switch --target-host *" = rule "deny";
      "ssh *nixos-rebuild switch*" = rule "deny";
      "ssh *docker compose*up*" = rule "deny";
    };
  };

  # G3 theme + attention tui.json (tokyonight). All leaves mkDefault so a
  # consumer overrides via `programs.opencode.tui` without mkForce.
  tuiDefaults = lib.mapAttrsRecursive (_: lib.mkDefault) {
    theme = "tokyonight";
    diff_style = "auto";
    mouse = true;
    leader_timeout = 2000;
    scroll_speed = 3;
    attention = {
      enabled = true;
      notifications = true;
      sound = true;
      volume = 0.4;
      sound_pack = "opencode.default";
    };
    keybinds = {
      leader = "ctrl+x";
      command_list = "ctrl+p";
    };
  };

  cavemanText = ''
    ## Default Response Style

    Use caveman ${cfg.style.level} style by default for assistant prose:

    - terse, high-signal technical language
    - no pleasantries, filler, or decorative recap
    - fragments are fine when meaning stays clear
    - keep code, file paths, commands, API names, and exact errors unchanged
    - preserve the user's language

    Drop compression when it could make security warnings, irreversible-action
    confirmations, or ordered multi-step instructions ambiguous. Resume terse
    style after the clear part.

    Stop using this style only when the user asks for normal mode or explicitly
    requests a different tone.
  '';

  styleText =
    if cfg.style.text != null
    then cfg.style.text
    else cavemanText;

  contextText =
    lib.concatStringsSep "\n\n"
    (lib.filter (text: text != "") [
      cfg.agents.preamble
      (optionalString cfg.style.enable styleText)
      cfg.agents.extraText
    ]);
in {
  options.programs.opencode-profile = {
    enable = mkEnableOption "opencode profile layered on programs.opencode";

    permissions.enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Set the G1 permission guardrails in
        `programs.opencode.settings.permission`: allow-by-default with
        secrets (`*.sops`, `.env*`, `*.age`, `secrets/`) denied for edit,
        `flake.lock` edits behind a prompt, and destructive or raw
        remote-deploy shell commands denied.
      '';
    };

    mcpNixos.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Register the mcp-nixos server in `programs.opencode.settings.mcp`.";
    };

    tui.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Manage `tui.json` (tokyonight theme, attention sounds, leader key)
        via `programs.opencode.tui`. Individual leaves are `mkDefault`, so
        overrides merge without `mkForce`.
      '';
    };

    agents = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Manage the global `AGENTS.md` via `programs.opencode.context`.";
      };

      preamble = mkOption {
        type = types.lines;
        default = ''
          # opencode Defaults

          These instructions apply to every opencode session for this user.
        '';
        description = "Text rendered at the start of the global `AGENTS.md`.";
      };

      extraText = mkOption {
        type = types.lines;
        default = "";
        description = "Additional text appended to the global `AGENTS.md`.";
      };
    };

    style = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Render default response style guidance into `AGENTS.md`.";
      };

      level = mkOption {
        type = types.enum ["lite" "full" "ultra"];
        default = "full";
        description = "Caveman style intensity.";
      };

      text = mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = "Custom response style guidance replacing the caveman text.";
      };
    };

    rtk.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Install the RTK opencode plugin
        (`~/.config/opencode/plugins/rtk.ts`). The plugin rewrites bash tool
        commands through `rtk rewrite`. rtk itself is deliberately not
        nix-managed here (no reusable package exists); the plugin
        self-disables when `rtk` is missing from PATH at session start.
        Requires rtk >= 0.23.0.
      '';
    };

    disableClaudeFallback = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Set `OPENCODE_DISABLE_CLAUDE_CODE=1` so opencode does not fall back
        to reading `~/.claude/CLAUDE.md` and Claude Code skills. The profile
        owns the global `AGENTS.md` instead. Set via
        `home.sessionVariables`, so it covers shells and GUI sessions but
        not systemd-launched `opencode serve` — wrap the package if that
        launch path ever matters.
      '';
    };
  };

  config = mkIf cfg.enable {
    programs.opencode = {
      enable = true;
      # The package is upstream's default (pkgs.opencode); override
      # `programs.opencode.package` directly. `null` (files-only) is not
      # supported: upstream crashes on it (`versionAtLeast null` in its tui
      # deprecation warning).

      settings =
        (lib.optionalAttrs cfg.permissions.enable {
          permission = permissionDefaults;
        })
        // (lib.optionalAttrs cfg.mcpNixos.enable {
          # Pinned tag, not a floating branch: `nix run` re-resolves at MCP
          # server start, so an unpinned ref would drift per session.
          mcp.nix = {
            type = "local";
            command = ["nix" "run" "github:utensils/mcp-nixos/v2.4.3"];
            enabled = true;
          };
        });

      tui = mkIf cfg.tui.enable tuiDefaults;

      context = mkIf cfg.agents.enable contextText;
    };

    # Verbatim output of `rtk init -g --opencode` (rtk 0.35.0); refresh the
    # vendored copy with that command when rtk bumps the plugin. Upstream
    # programs.opencode has no plugins option (yet) — raw file drop is the
    # documented opencode mechanism and matches what rtk itself installs.
    xdg.configFile."opencode/plugins/rtk.ts" = mkIf cfg.rtk.enable {
      source = ../plugins/rtk.ts;
    };

    home.sessionVariables = mkIf cfg.disableClaudeFallback {
      OPENCODE_DISABLE_CLAUDE_CODE = "1";
    };
  };
}
