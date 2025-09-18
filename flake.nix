{
  description = "hs-bindgen development environment";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    {
      self,
      flake-utils,
      nixpkgs,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        # NOTE: May be used to overwrite the version of `rust-bindgen` which has
        # to align with the one used to create the fixtures.
        rOverlay = final: prev: {
          rust-bindgen-unwrapped = prev.rust-bindgen-unwrapped.overrideAttrs (old: rec {
            version = "0.71.1";
            src = prev.fetchCrate {
              pname = "bindgen-cli";
              inherit version;
              hash = "sha256-RL9P0dPYWLlEGgGWZuIvyULJfH+c/B+3sySVadJQS3w=";
            };
            cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
              pname = old.pname;
              inherit version src;
              hash = "sha256-4EyDjHreFFFSGf7UoftCh6eI/8nfIP1ANlYWq0K8a3I=";
            };
          });
        };
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            rOverlay
          ];
        };
        devShellWith =
          {
            haskellPackages,
            llvmPackages,
            additionalPackages ? [ ],
            appendToShellHook ? "",
          }:
          pkgs.mkShell {
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
              # NOTE: The `bindgen` hook just collects all library dependencies
              # in the closure and adds them to the include directory. Since we
              # have GCC in the closure (and not only Clang), the GCC includes
              # end up in BINDGEN_EXTRA_CLANG_ARGS. I think we should just live
              # with that.
              #
              # We could use a `clangStdenv` Nixpkgs overlay, but that requires
              # recompilation of the complete toolchain; see, e.g.,
              # https://nixos.wiki/wiki/Using_Clang_instead_of_GCC.
              pkgs.rustPlatform.bindgenHook
            ]
            ++
              # Additional packages (e.g., of example libraries to generate
              # bindings for).
              additionalPackages;
            shellHook = ''
              PROJECT_ROOT=$(git rev-parse --show-toplevel)
              export PROJECT_ROOT

              # TODO: Setting the linker library path still seems to be
              # necessary, because otherwise TH issues a warning that it cannot
              # find `libclang.so`. However, the actual call to `libclang` does
              # find all libraries due to BINDGEN_EXTRA_CLANG_ARGS (see
              # `bindgenHook` provided by Nixpkgs).

              # The examples in manual also use shared libraries.

              LD_LIBRARY_PATH="$PROJECT_ROOT/manual/c:${llvmPackages.libclang.lib}/lib"
              export LD_LIBRARY_PATH

              # We set the builtin include directory using
              # BINDGEN_EXTRA_CLANG_ARGS (see `bindgenHook` provided by
              # Nixpkgs).
              BINDGEN_BUILTIN_INCLUDE_DIR=disable
              export BINDGEN_BUILTIN_INCLUDE_DIR

              # PATH="$HOME/.local/bin:$PATH"
              # export PATH
            ''
            + appendToShellHook;
          };
      in
      {
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
