{
  description = "hs-bindgen development environment";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  inputs.libclang-bindings-src = {
    url = "github:well-typed/libclang/dom/loosen-bounds";
    flake = false;
  };

  inputs.hs-bindgen-src = {
    url = "github:well-typed/hs-bindgen/dom/1019/loosen-bounds";
    flake = false;
  };

  outputs =
    {
      self,
      flake-utils,
      nixpkgs,
      #
      libclang-bindings-src,
      hs-bindgen-src,
    }:
    let

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
      perSystem =
        system:
        let
          pkgs = import nixpkgs { inherit system overlays; };
          hsBindgenDev = import ./nix/hs-bindgen-dev.nix { inherit pkgs; };
        in
        {
          packages = {
            inherit (pkgs) hsBindgenHook hsBindgenCli;
          };

          devShells = {
            inherit (hsBindgenDev) matrix;
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
    in
    {
      overlays.default = nixpkgs.lib.composeManyExtensions overlays;
    }
    // flake-utils.lib.eachDefaultSystem perSystem;
}
