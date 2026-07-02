{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.opencode-profile;
  inherit (lib) mkEnableOption mkIf mkOption optionalString types;

  # G1 permission guardrails: yolo defaults, secrets denied, raw remote
  # deploys denied (correct paths go through `just` recipes).
  permissionDefaults = {
    edit = {
      "*" = "allow";
      "flake.lock" = "ask";
      "**/*.sops" = "deny";
      "**/.env.sops" = "deny";
      "**/.env" = "deny";
      "**/.env.*" = "deny";
      "secrets/**" = "deny";
      "**/*.age" = "deny";
    };
    bash = {
      "*" = "allow";
      "rm -rf /*" = "deny";
      "rm -rf ~*" = "deny";
      "docker volume rm *" = "deny";
      "nixos-rebuild switch --target-host *" = "deny";
      "ssh *nixos-rebuild switch*" = "deny";
      "ssh *docker compose*up*" = "deny";
    };
  };

  # G3 theme + attention tui.json (tokyonight).
  tuiDefaults = {
    theme = cfg.tui.theme;
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
    else if cfg.style.name == "caveman"
    then cavemanText
    else "";

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

    package = mkOption {
      type = types.package;
      default = pkgs.opencode;
      defaultText = "pkgs.opencode";
      description = ''
        opencode package to install. A files-only profile
        (`programs.opencode.package = null`) is not supported: the upstream
        Home Manager module crashes on a null package
        (`versionAtLeast null` in its tui deprecation warning).
      '';
    };

    permissions = {
      enable = mkOption {
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
    };

    mcpNixos.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Register the mcp-nixos server in `programs.opencode.settings.mcp`.";
    };

    tui = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Manage `tui.json` (theme, attention sounds, leader key) via `programs.opencode.tui`.";
      };

      theme = mkOption {
        type = types.str;
        default = "tokyonight";
        description = "opencode TUI theme.";
      };
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

      name = mkOption {
        type = types.enum ["caveman" "custom"];
        default = "caveman";
        description = "Built-in style guidance to render when `style.text` is null.";
      };

      level = mkOption {
        type = types.enum ["lite" "full" "ultra"];
        default = "full";
        description = "Caveman style intensity.";
      };

      text = mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = "Custom response style guidance.";
      };
    };

    rtk.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Install the RTK opencode plugin
        (`~/.config/opencode/plugins/rtk.ts`). The plugin rewrites bash tool
        commands through `rtk rewrite` and disables itself when `rtk` is not
        on PATH. Requires rtk >= 0.23.0 at runtime.
      '';
    };

    disableClaudeFallback = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Set `OPENCODE_DISABLE_CLAUDE_CODE=1` so opencode does not fall back
        to reading `~/.claude/CLAUDE.md` and Claude Code skills. The profile
        owns the global `AGENTS.md` instead.
      '';
    };
  };

  config = mkIf cfg.enable {
    programs.opencode = {
      enable = true;

      # mkDefault so a consumer can point programs.opencode.package elsewhere
      # without fighting the profile.
      package = lib.mkDefault cfg.package;

      settings =
        (lib.optionalAttrs cfg.permissions.enable {
          permission = permissionDefaults;
        })
        // (lib.optionalAttrs cfg.mcpNixos.enable {
          mcp.nix = {
            type = "local";
            command = ["nix" "run" "github:utensils/mcp-nixos"];
            enabled = true;
          };
        });

      tui = mkIf cfg.tui.enable tuiDefaults;

      context = mkIf cfg.agents.enable contextText;
    };

    xdg.configFile."opencode/plugins/rtk.ts" = mkIf cfg.rtk.enable {
      source = ../plugins/rtk.ts;
    };

    home.sessionVariables = mkIf cfg.disableClaudeFallback {
      OPENCODE_DISABLE_CLAUDE_CODE = "1";
    };
  };
}
