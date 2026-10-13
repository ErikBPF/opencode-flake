# OpenCode v2 terminal client (official Linux x64 npm release).
#
# Upstream ships a self-contained Bun-compiled binary, so this is a
# binary-fetch derivation: autoPatchelf only. The Bun payload must survive
# ELF fixup intact, hence dontStrip/dontPatchELF. V1 is built from source
# (packages/opencode); v2 has no equivalent source build here yet.
{
  lib,
  stdenvNoCC,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  openssl,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}: let
  version = "2.0.27";
in
  stdenvNoCC.mkDerivation {
    pname = "opencode-v2";
    inherit version;

    src = fetchurl {
      url = "https://registry.npmjs.org/@opencode/cli-linux-x64/-/cli-linux-x64-${version}.tgz";
      hash = "sha512-QPGrzBSSs5ATG3nM4XjS4tmWXUB22Di36H0vfMuhKwk6i3PR3Nb4sm+l00gvTdcyCRohYsKwqjvD67T0DPcQLQ==";
    };

    nativeBuildInputs = [autoPatchelfHook];
    buildInputs = [stdenv.cc.cc.lib openssl];

    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;
    dontPatchELF = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 bin/opencode $out/bin/opencode
      runHook postInstall
    '';

    nativeInstallCheckInputs = [
      versionCheckHook
      # v2 writes logs under $HOME/.local/share; give installCheck a writable HOME.
      writableTmpDirAsHomeHook
    ];
    doInstallCheck = true;
    versionCheckProgramArg = "--version";
    versionCheckKeepEnvironment = ["HOME"];

    meta = {
      description = "AI coding agent built for the terminal (OpenCode v2)";
      homepage = "https://opencode.ai";
      license = lib.licenses.mit;
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
      platforms = ["x86_64-linux"];
      mainProgram = "opencode";
    };
  }
