{ lib, stdenvNoCC, fetchurl, unzip, buildNpmPackage, nodejs_24, makeWrapper, writeShellApplication }:
let
  # Public maintainer release artifacts, SHA-256 from GitHub release asset metadata.
  releaseBinary = { pname, version, sha256 }:
    stdenvNoCC.mkDerivation {
      inherit pname version;
      src = fetchurl {
        url = "https://github.com/kunchenguid/${pname}/releases/download/v${version}/${pname}-v${version}-darwin-arm64.tar.gz";
        inherit sha256;
      };
      sourceRoot = ".";
      dontBuild = true;
      installPhase = ''
        runHook preInstall
        install -Dm755 ${pname} "$out/bin/${pname}"
        runHook postInstall
      '';
      meta = { platforms = [ "aarch64-darwin" ]; license = lib.licenses.mit; };
    };
in {
  treehouse = releaseBinary {
    pname = "treehouse";
    version = "3.1.6";
    sha256 = "094ae248f53bc61d82ae5862ed66e578e28b8b13553390ad51bde4f009e8258f";
  };
  no-mistakes = releaseBinary {
    pname = "no-mistakes";
    version = "1.84.0";
    sha256 = "2e5f838303ab727edccd1a60a4834068024606c68ae7d97fdc0fdeecd7bd4d90";
  };
  gh = stdenvNoCC.mkDerivation {
    pname = "gh";
    version = "2.103.2";
    src = fetchurl {
      url = "https://github.com/cli/cli/releases/download/v2.103.2/gh_2.103.2_macOS_arm64.zip";
      sha256 = "5416000f5d17580a187339e0c4068a01ca5c87f7d4fe6ca64933696f967bc418";
    };
    nativeBuildInputs = [ unzip ];
    sourceRoot = "gh_2.103.2_macOS_arm64";
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin"
      install -m755 bin/gh "$out/bin/gh"
      runHook postInstall
    '';
    meta = { platforms = [ "aarch64-darwin" ]; license = lib.licenses.mit; };
  };
  axi = buildNpmPackage {
    pname = "mac-foundation-axi";
    version = "1.0.0";
    src = ./axi;
    nodejs = nodejs_24;
    npmDepsHash = "sha256-DQqjk+AC6M6vbFHFFLTrXbksTe9aN1tuizBSR75zOs8=";
    npmFlags = [ "--ignore-scripts" ];
    dontNpmBuild = true;
    nativeBuildInputs = [ makeWrapper ];
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib/axi" "$out/bin"
      cp -R node_modules "$out/lib/axi/"
      for command in gh-axi chrome-devtools-axi lavish-axi quota-axi tasks-axi; do
        target=$(readlink "node_modules/.bin/$command")
        makeWrapper ${nodejs_24}/bin/node "$out/bin/$command" \
          --add-flags "$out/lib/axi/node_modules/.bin/$target" \
          --prefix PATH : ${lib.makeBinPath [ nodejs_24 ]}
      done
      runHook postInstall
    '';
    meta = { platforms = [ "aarch64-darwin" ]; license = lib.licenses.mit; };
  };
  # Repository-authored, intentionally small Keychain-only interface. No copied state.
  kc = writeShellApplication {
    name = "kc";
    text = builtins.readFile ../scripts/kc.sh;
  };
}
