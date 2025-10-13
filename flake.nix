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
      lib = nixpkgs.lib;
      libclangBindingsOverlay = import ./nix/libclang-bindings.nix { inherit libclang-bindings-src; };
      hsBindgenOverlay = import ./nix/hs-bindgen.nix { inherit hs-bindgen-src; };
      hsFixesOverlay = import ./nix/overrides.nix;
      rustBindgenOverlay = import ./nix/rust-bindgen.nix;
      overlays = [
        libclangBindingsOverlay
        hsBindgenOverlay
        hsFixesOverlay
        rustBindgenOverlay
      ];
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      perSystem =
        { system, ... }:
        let
          pkgs = import inputs.nixpkgs { inherit overlays system; };
          hsBindgenDev = import ./nix/hs-bindgen-dev.nix { inherit pkgs; };
        in
        {
          _module.args.pkgs = pkgs;

          packages = {
            inherit (pkgs) hsBindgenHook hs-bindgen-cli;
          };

          devShells = hsBindgenDev.devShells // {
            default = hsBindgenDev.devShellWith {
              inherit (pkgs) haskellPackages llvmPackages;
            };
            # Example `libpcap`.
            pcap = hsBindgenDev.devShellWith {
              haskellPackages = pkgs.haskell.packages.ghc912;
              llvmPackages = pkgs.llvmPackages;
              additionalPackages = [
                pkgs.libpcap
              ];
            };
            # Example `wlroots`.
            wlroots = hsBindgenDev.devShellWith {
              haskellPackages = pkgs.haskell.packages.ghc912;
              llvmPackages = pkgs.llvmPackages;
              additionalPackages = [
                pkgs.pixman
                pkgs.wayland
                pkgs.wlroots
              ];
              appendToShellHook = ''
                BINDGEN_EXTRA_CLANG_ARGS="-isystem ${pkgs.wlroots}/include/wlroots-0.19 ''${BINDGEN_EXTRA_CLANG_ARGS}"
              '';
            };
          };

        };
      flake.overlays = {
        default = lib.composeManyExtensions overlays;
        inherit
          libclangBindingsOverlay
          hsBindgenOverlay
          hsFixesOverlay
          rustBindgenOverlay
          ;
      };
    };
}
