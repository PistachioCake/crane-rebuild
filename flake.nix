{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, crane }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };
        rustToolchain = pkgs.rust-bin.stable.latest.default;
        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

        nativeBuildInputs = with pkgs; [ rustToolchain pkg-config alsaLib ];
        buildInputs = with pkgs; [ ];

        src = craneLib.cleanCargoSource ./.;
        commonArgs = {
          inherit src buildInputs nativeBuildInputs;
          NIX_OUTPATH_USED_AS_RANDOM_SEED = "pistachiok";
          # strictDeps = true;
        };
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;
        bin = craneLib.buildPackage (commonArgs // {
          inherit cargoArtifacts;
          cargoExtraArgs = "--locked -vvv";
          doInstallCargoArtifacts = true;
          cargoTestCommand = "echo $PKG_CONFIG_PATH";
        });

      in
      {
        devShells.default = with pkgs; craneLib.devShell {
          inputsFrom = [ bin ];
          packages = [
            rust-analyzer
          ];
        };

        packages = {
          default = bin;
        };

        checks = {
          inherit bin; # for convenience and reuse

          formatCheck = craneLib.cargoFmt {
            inherit src;
          };

          clippyCheck = craneLib.cargoClippy (commonArgs // {
            inherit cargoArtifacts;
          });
        };
      }
    );
}
