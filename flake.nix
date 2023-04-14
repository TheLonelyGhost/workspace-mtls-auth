{
  description = "A basic flake with a shell";
  inputs.nixpkgs.url = "flake:nixpkgs";
  inputs.flake-utils.url = "flake:flake-utils";
  inputs.overlays.url = "github:thelonelyghost/blank-overlay-nix";

  outputs = { self, nixpkgs, flake-utils, overlays }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlays.overlays.default ];
          # config.allowUnfree = true;
        };
      in
      {
        devShell = pkgs.mkShell {
          nativeBuildInputs = [
            pkgs.bashInteractive
            pkgs.openssl
            pkgs.perl
            pkgs.tree
          ];
          buildInputs = [
          ];
        };
      });
}
