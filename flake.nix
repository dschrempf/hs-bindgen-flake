{
  description = "Automatically generate Haskell bindings from C header files";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    libclang-bindings-src = {
      url = "github:well-typed/libclang";
      flake = false;
    };
    hs-bindgen-src = {
      url = "github:well-typed/hs-bindgen";
      flake = false;
    };
  };

  outputs =
    inputs@{
      flake-parts,
      nixpkgs,
      #
      libclang-bindings-src,
      hs-bindgen-src,
      ...
    }:
    let
      overlays = import ./nix/overlay {
        lib = nixpkgs.lib;
        inherit libclang-bindings-src hs-bindgen-src;
      };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      perSystem =
        {
          system,
          ...
        }:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ overlays.default ];
          };
          hsBindgen = import ./nix/hs-bindgen.nix { inherit pkgs; };
        in
        hsBindgen;
      flake.overlays = overlays;
    };
}
