{
  inputs,
  pkgs,
  self,
}: let
  hmConfig = extraModules:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules =
        [
          self.homeManagerModules.default
          {
            home = {
              username = "opencode-test";
              homeDirectory = "/home/opencode-test";
              stateVersion = "25.11";
            };
          }
        ]
        ++ extraModules;
    };

  enabled = hmConfig [
    {
      programs.opencode-profile = {
        enable = true;
        tui.enable = true;
        style.enable = true;
        rtk.enable = true;
        agents.extraText = "profile-check-marker";
      };
    }
  ];

  defaults = hmConfig [
    {
      programs.opencode-profile.enable = true;
    }
  ];

  enabledFiles = enabled.config.xdg.configFile;
  defaultsFiles = defaults.config.xdg.configFile;

  settingsJson = enabledFiles."opencode/opencode.json".source;
  tuiJson = enabledFiles."opencode/tui.json".source;
  agentsMd = enabledFiles."opencode/AGENTS.md".source or (pkgs.writeText "missing" "");
in {
  lint =
    pkgs.runCommand "opencode-flake-lint" {
      nativeBuildInputs = [pkgs.alejandra pkgs.statix pkgs.deadnix];
    } ''
      cd ${self}
      alejandra --check .
      statix check .
      deadnix --fail .
      touch "$out"
    '';

  # Rendered opencode.json / tui.json must validate against the JSON schemas
  # shipped by the opencode package. Paths are spelled out because
  # `passthru.jsonschema` uses `placeholder "out"`, which only resolves
  # inside the opencode derivation itself (nixpkgs bug).
  schema-validate =
    pkgs.runCommand "opencode-schema-validate" {
      nativeBuildInputs = [pkgs.check-jsonschema];
    } ''
      check-jsonschema --schemafile ${pkgs.opencode}/share/opencode/config.json ${settingsJson}
      check-jsonschema --schemafile ${pkgs.opencode}/share/opencode/tui.json ${tuiJson}
      touch "$out"
    '';

  # G1 guardrails + mcp-nixos land in opencode.json; AGENTS.md carries the
  # profile content; the RTK plugin file is installed.
  module-render =
    pkgs.runCommand "opencode-module-render" {
      nativeBuildInputs = [pkgs.jq];
    } ''
      jq -e '.permission.edit."**/*.sops" == "deny"' ${settingsJson}
      jq -e '.permission.edit."flake.lock" == "ask"' ${settingsJson}
      jq -e '.permission.bash."rm -rf /*" == "deny"' ${settingsJson}
      jq -e '.mcp.nix.type == "local"' ${settingsJson}
      jq -e '.theme == "tokyonight"' ${tuiJson}
      grep -q "profile-check-marker" ${agentsMd}
      grep -q "caveman" ${agentsMd}
      grep -q "rtk rewrite" ${enabledFiles."opencode/plugins/rtk.ts".source}
      touch "$out"
    '';

  # Defaults posture: pkgs.opencode installed, no tui.json, no rtk plugin,
  # CLAUDE.md fallback disabled.
  defaults-posture =
    pkgs.runCommand "opencode-defaults-posture" {
      packagesJson = builtins.toJSON (map (p: p.name or "unnamed") defaults.config.home.packages);
      sessionVars = builtins.toJSON defaults.config.home.sessionVariables;
      hasTui = builtins.hasAttr "opencode/tui.json" defaultsFiles;
      hasRtkPlugin = builtins.hasAttr "opencode/plugins/rtk.ts" defaultsFiles;
      nativeBuildInputs = [pkgs.jq];
    } ''
      echo "$packagesJson" | jq -e 'map(select(startswith("opencode"))) | length == 1'
      echo "$sessionVars" | jq -e '.OPENCODE_DISABLE_CLAUDE_CODE == "1"'
      [ "$hasTui" = "" ] || { echo "tui.json rendered despite tui.enable = false" >&2; exit 1; }
      [ "$hasRtkPlugin" = "" ] || { echo "rtk plugin rendered despite rtk.enable = false" >&2; exit 1; }
      touch "$out"
    '';
}
