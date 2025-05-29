{
  description = "Oracle Instant Client SDK flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-darwin" ] (system:
      let
        pkgs = import nixpkgs {
          inherit system; 
          config.allowUnfree = true;
        };
      in {
        packages.oracle-instant-client = pkgs.callPackage ./oracle-instant-client.nix { inherit system; };
        defaultPackage = self.packages.${system}.oracle-instant-client;
      });
}
