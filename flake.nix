{
  description = "Example GitOps flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      overlay = final: prev: {
        gitops-sync = final.writeShellApplication {
          name = "gitops-sync";
          runtimeInputs = [ final.git final.nixos-rebuild ];
          text = builtins.readFile ./scripts/gitops-sync;
        };
      };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; overlays = [ overlay ]; };
      in
      rec {
        packages.gitops-sync = pkgs.gitops-sync;
        defaultPackage = packages.gitops-sync;
      }
    ) // {
      overlays.default = overlay;
      nixosModules.gitops = import ./modules/gitops.nix;
    };
}
