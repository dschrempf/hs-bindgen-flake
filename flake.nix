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
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        libclangBindingsOverlay = import ./nix/libclang-bindings.nix { inherit libclang-bindings-src; };
        hsBindgenOverlay = import ./nix/hs-bindgen.nix { inherit hs-bindgen-src; };
        hsFixesOverlay = import ./nix/overrides.nix;
        rustBindgenOverlay = import ./nix/rust-bindgen.nix;
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            libclangBindingsOverlay
            hsBindgenOverlay
            hsFixesOverlay
            rustBindgenOverlay
          ];
        };
        devShellWith =
          {
            haskellPackages,
            llvmPackages,
            additionalPackages ? [ ],
            appendToShellHook ? "",
          }:
          haskellPackages.shellFor {
            packages = p: [ p.hs-bindgen ];
            nativeBuildInputs = [
              # Haskell.
              haskellPackages.cabal-install
              haskellPackages.ghc
              haskellPackages.haskell-language-server
              # Rust.
              pkgs.rust-bindgen
              pkgs.rustfmt
              # Clang.
              llvmPackages.clang
              llvmPackages.libclang
              llvmPackages.llvm
              # Bindgen hook.
              #
              # NOTE: `hsBindgenHook` collects all library dependencies in the
              # closure and adds their `CFLAGS` and `CCFLAGS` to
              # `BINDGEN_EXTRA_CLANG_ARGS`. Since we have GCC in the closure
              # (and not only Clang), the GCC includes end up in
              # BINDGEN_EXTRA_CLANG_ARGS which is suboptimal. We could use a
              # `clangStdenv` Nixpkgs overlay, but that requires recompilation
              # of the complete toolchain; see, e.g.,
              # https://nixos.wiki/wiki/Using_Clang_instead_of_GCC.
              pkgs.hsBindgenHook
            ]
            ++
              # Additional packages (e.g., of example libraries to generate
              # bindings for).
              additionalPackages;
            shellHook = ''
              PROJECT_ROOT=$(git rev-parse --show-toplevel)
              export PROJECT_ROOT

              LD_LIBRARY_PATH="$PROJECT_ROOT/manual/c''${LD_LIBRARY_PATH:+:''${LD_LIBRARY_PATH}}"
              export LD_LIBRARY_PATH
            ''
            + appendToShellHook;
            withHoogle = true;
          };
      in
      {
        packages = {
          inherit (pkgs) hsBindgenHook hsBindgenCli;
        };

        devShells = {
          ghc98 = devShellWith {
            haskellPackages = pkgs.haskell.packages.ghc98;
            llvmPackages = pkgs.llvmPackages;
          };
          ghc910 = devShellWith {
            haskellPackages = pkgs.haskell.packages.ghc910;
            llvmPackages = pkgs.llvmPackages;
          };
          ghc912 = devShellWith {
            haskellPackages = pkgs.haskell.packages.ghc912;
            llvmPackages = pkgs.llvmPackages;
          };
          default = devShellWith {
            haskellPackages = pkgs.haskell.packages.ghc912;
            llvmPackages = pkgs.llvmPackages;
          };
          # Example `libcap`.
          pcap = devShellWith {
            haskellPackages = pkgs.haskell.packages.ghc912;
            llvmPackages = pkgs.llvmPackages;
            additionalPackages = [
              pkgs.libpcap
            ];
          };
          # Example `wlroots`.
          wlroots = devShellWith {
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
      }
    );
}
