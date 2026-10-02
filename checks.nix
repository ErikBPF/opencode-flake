{
  inputs,
  pkgs,
  self,
}: let
  inherit (pkgs) lib;

  defaults = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      self.homeManagerModules.withPackage
      {
        home = {
          username = "opencode-test";
          homeDirectory = "/home/opencode-test";
          stateVersion = "25.11";
        };
        programs.opencode-profile.enable = true;
      }
    ];
  };

  enabled = defaults.extendModules {
    modules = [
      {
        programs.opencode-profile = {
          tui.enable = true;
          style.enable = true;
          rtk.enable = true;
          agents.extraText = "profile-check-marker";
        };
      }
    ];
  };

  withoutMcp = defaults.extendModules {
    modules = [{programs.opencode-profile.mcpNixos.enable = false;}];
  };

  enabledFiles = enabled.config.xdg.configFile;
  defaultsFiles = defaults.config.xdg.configFile;

  settingsJson = enabledFiles."opencode/opencode.json".source;
  tuiJson = enabledFiles."opencode/tui.json".source;
  agentsMd = enabledFiles."opencode/AGENTS.md".source;

  # Schemas come from the package the evaluated config actually installs, so
  # schema and binary cannot diverge. Paths are spelled out because nixpkgs'
  # `passthru.jsonschema` uses `placeholder "out"`, which only resolves
  # inside the opencode derivation itself.
  opencodePkg = enabled.config.programs.opencode.package;

  mockUpdateNix = pkgs.writeShellApplication {
    name = "nix";
    text = ''
      if [ "$*" = "eval --raw .#opencode.version" ]; then
        printf '%s\n' "1.0.0"
        exit 0
      fi
      printf 'unexpected nix args: %s\n' "$*" >&2
      exit 2
    '';
  };

  mockNixUpdate = pkgs.writeShellApplication {
    name = "nix-update";
    runtimeInputs = [pkgs.gnused];
    text = ''
      version=""
      file=""
      while [ "$#" -gt 0 ]; do
        case "$1" in
          --version) version="$2"; shift 2 ;;
          --override-filename) file="$2"; shift 2 ;;
          *) shift ;;
        esac
      done
      test -n "$version"
      test -n "$file"
      sed -i "s/^  version = \"[^\"]*\";/  version = \"$version\";/" "$file"
    '';
  };
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

  # One build over the final rendered artifacts: schema validation plus the
  # G1/G3/context/plugin render assertions (jq inspects the same files the
  # schemas validate, so DAG-ordered rule rendering is covered too).
  render-and-schema =
    pkgs.runCommand "opencode-render-and-schema" {
      nativeBuildInputs = [pkgs.check-jsonschema pkgs.jq];
    } ''
      check-jsonschema --schemafile ${opencodePkg}/share/opencode/config.json ${settingsJson}
      check-jsonschema --schemafile ${opencodePkg}/share/opencode/tui.json ${tuiJson}

      jq -e '.permission.edit."**/*.sops" == "deny"' ${settingsJson}
      jq -e '.permission.edit."flake.lock" == "ask"' ${settingsJson}
      jq -e '.permission.bash."rm -rf /*" == "deny"' ${settingsJson}
      jq -e '.mcp.nix.type == "local"' ${settingsJson}
      jq -e '.mcp.nix.enabled == true and (.mcp.nix.command | length) == 1' ${settingsJson}
      test -x "$(jq -r '.mcp.nix.command[0]' ${settingsJson})"
      jq -e '.theme == "tokyonight"' ${tuiJson}
      grep -q "profile-check-marker" ${agentsMd}
      grep -q "caveman" ${agentsMd}
      grep -q "rtk rewrite" ${enabledFiles."opencode/plugins/rtk.ts".source}
      touch "$out"
    '';

  # Defaults posture, asserted at eval time so `nix flake check --no-build`
  # already catches regressions: flake package installed, no tui.json, no
  # rtk plugin, CLAUDE.md fallback disabled.
  defaults-posture = assert lib.assertMsg (!(defaultsFiles ? "opencode/tui.json"))
  "tui.json rendered despite tui.enable = false";
  assert lib.assertMsg (!(defaultsFiles ? "opencode/plugins/rtk.ts"))
  "rtk plugin rendered despite rtk.enable = false";
  assert lib.assertMsg (defaults.config.home.sessionVariables.OPENCODE_DISABLE_CLAUDE_CODE == "1")
  "OPENCODE_DISABLE_CLAUDE_CODE not set";
  assert lib.assertMsg
  (lib.count (p: lib.hasPrefix "opencode" (lib.getName p)) defaults.config.home.packages == 1)
  "expected exactly one opencode package in home.packages";
  assert lib.assertMsg
  (let
    command = defaults.config.programs.opencode.settings.mcp.nix.command;
  in
    builtins.length command
    == 1
    && lib.hasPrefix "${builtins.storeDir}/" (builtins.head command)
    && lib.hasSuffix "/bin/mcp-nixos" (builtins.head command))
  "nix MCP must launch a built executable without runtime flake resolution";
  assert lib.assertMsg (!((withoutMcp.config.programs.opencode.settings.mcp or {}) ? nix))
  "nix MCP registered despite mcpNixos.enable = false";
    pkgs.runCommand "opencode-defaults-posture" {} "touch $out";

  updater-mutation-only = pkgs.runCommand "opencode-updater-mutation-only" {} ''
    cp -r ${self} source
    chmod -R u+w source
    cd source
    PATH="${mockUpdateNix}/bin:${mockNixUpdate}/bin:${pkgs.jq}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.gnused}/bin:${pkgs.gnugrep}/bin" \
      ${pkgs.bash}/bin/bash ./scripts/update-opencode.sh --version 9.9.9
    grep -Fq 'version = "9.9.9";' packages/opencode/package.nix
    touch "$out"
  '';
}
