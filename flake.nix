{
  description = "Delta CLI only, packaged for Nix (no desktop app bundle)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      # Same release assets the official installer downloads, pinned.
      releases = builtins.fromJSON (builtins.readFile ./releases.json);
      release = releases.stable or releases.nightly or null;
      hasRelease = system: release != null && release.systems ? ${system};
    in
    {
      packages = forAllSystems (
        system:
        nixpkgs.lib.optionalAttrs (hasRelease system) (
          let
            pkgs = import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            };
            delta = pkgs.callPackage ./package.nix {
              inherit release;
              asset = release.systems.${system};
              platform = pkgs.stdenv.hostPlatform.system;
            };
          in
          {
            inherit delta;
            default = delta;
          }
        )
      );

      apps = forAllSystems (
        system:
        nixpkgs.lib.optionalAttrs (hasRelease system) {
          delta = {
            type = "app";
            program = nixpkgs.lib.getExe self.packages.${system}.delta;
            meta.description = "Run the Delta CLI";
          };
          default = self.apps.${system}.delta;
        }
      );

      checks = forAllSystems (
        system:
        nixpkgs.lib.optionalAttrs (hasRelease system) {
          inherit (self.packages.${system}) delta;
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
    };
}
