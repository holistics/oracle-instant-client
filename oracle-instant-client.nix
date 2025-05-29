# Adapted from https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/or/oracle-instantclient/package.nix
{ stdenv, lib, system, pkgs, ... }:

let
  unpackTool = if stdenv.isDarwin then "7zz x -snld -aoa" else if stdenv.isLinux then "unzip" else "unsupported-unpack-tool";

  throwSystem = throw "Unsupported system: ${stdenv.hostPlatform.system}";

  # assemble list of components
  components = [
    "basic"
    "sqlplus"
    "sdk"
  ];

  # determine the version number, there might be different ones per architecture
  version =
    {
      x86_64-linux = "21.10.0.0.0";
      aarch64-darwin = "23.3.0.23.09";
    }
    .${stdenv.hostPlatform.system} or throwSystem;

  directory =
    {
      x86_64-linux = "2110000";
      aarch64-darwin = "233023";
    }
    .${stdenv.hostPlatform.system} or throwSystem;

  # hashes per component and architecture
  hashes =
    {
      x86_64-linux = {
        basic = "sha256-uo0QBOmx7TQyroD+As60IhjEkz//+0Cm1tWvLI3edaE=";
        sdk = "sha256-TIBFi1jHLJh+SUNFvuL7aJpxh61hG6gXhFIhvdPgpts=";
        sqlplus = "sha256-mF9kLjhZXe/fasYDfmZrYPL2CzAp3xDbi624RJDA4lM=";
        tools = "sha256-ay8ynzo1fPHbCg9GoIT5ja//iZPIZA2yXI/auVExiRY=";
        odbc = "sha256-3M6/cEtUrIFzQay8eHNiLGE+L0UF+VTmzp4cSBcrzlk=";
      };
      aarch64-darwin = {
        basic = "sha256-G83bWDhw9wwjLVee24oy/VhJcCik7/GtKOzgOXuo1/4=";
        sdk = "sha256-PerfzgietrnAkbH9IT7XpmaFuyJkPHx0vl4FCtjPzLs=";
        sqlplus = "sha256-khOjmaExAb3rzWEwJ/o4XvRMQruiMw+UgLFtsOGn1nY=";
        tools = "sha256-gA+SbgXXpY12TidpnjBzt0oWQ5zLJg6wUpzpSd/N5W4=";
        odbc = "sha256-JzoSdH7mJB709cdXELxWzpgaNTjOZhYH/wLkdzKA2N0=";
      };
    }
    .${stdenv.hostPlatform.system} or throwSystem;

  # rels per component and architecture, optional
  rels =
    {
      aarch64-darwin = {
        basic = "1";
        tools = "1";
      };
    }
    .${stdenv.hostPlatform.system} or { };

  # convert platform to oracle architecture names
  arch =
    {
      x86_64-linux = "linux.x64";
      aarch64-linux = "linux.arm64";
      x86_64-darwin = "macos.x64";
      aarch64-darwin = "macos.arm64";
    }
    .${stdenv.hostPlatform.system} or throwSystem;

  shortArch =
    {
      x86_64-linux = "linux";
      aarch64-linux = "linux";
      x86_64-darwin = "mac";
      aarch64-darwin = "mac";
    }
    .${stdenv.hostPlatform.system} or throwSystem;

  suffix =
    {
      aarch64-darwin = ".dmg";
    }
    .${stdenv.hostPlatform.system} or "dbru.zip";

  # calculate the filename of a single zip file
  srcFilename =
    component: arch: version: rel:
    "instantclient-${component}-${arch}-${version}" + (lib.optionalString (rel != "") "-${rel}") + suffix;

  # fetcher for the non clickthrough artifacts
  fetcher =
    srcFilename: hash:
    pkgs.fetchurl {
      url = "https://download.oracle.com/otn_software/${shortArch}/instantclient/${directory}/${srcFilename}";
      sha256 = hash;
    };

  # assemble srcs
  srcs = map (
    component:
    (fetcher (srcFilename component arch version rels.${component} or "") hashes.${component} or "")
  ) components;

  isDarwinAarch64 = stdenv.hostPlatform.system == "aarch64-darwin";

  srcsScript = lib.concatMapStringsSep "\n" (src: ''
    cp ${src} $(basename ${src})
    ${unpackTool} $(basename ${src})
  '') srcs;
in

stdenv.mkDerivation rec {
  pname = "oracle-instant-client-sdk";
  inherit version;

  buildInputs =
    [
      (lib.getLib stdenv.cc.cc)
    ]
    ++ lib.optional stdenv.isLinux pkgs.libaio;

  # Tried to use undmg but as of 2025-05-24 it does not work on APFS
  # So use 7zz instead
  nativeBuildInputs = with pkgs; lib.optionals stdenv.isLinux [ unzip autoPatchelfHook ]
    ++ lib.optionals stdenv.isDarwin [ _7zz ];

  unpackPhase = ''
    mkdir -p sources
    cd sources
    ${srcsScript}
    cd ..
  '';

  installPhase = ''
    mkdir -p $out/oracle
    # Normalize timestamp
    find sources -type f -exec touch -d "@0" {} +
    cp -pr --no-preserve=ownership sources/* $out/oracle/
  '';

  meta = with lib; {
    description = "Oracle Instant Client SDK";
    homepage = "https://www.oracle.com/database/technologies/instant-client.html";
    license = licenses.unfree;
    platforms = platforms.linux ++ platforms.darwin;
  };

  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
}
