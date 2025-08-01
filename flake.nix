{
  description = "hs-bindgen development environment";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  inputs.hs-bindgen = {
    url = "github:well-typed/hs-bindgen";
    flake = false;
  };

  outputs =
    {
      self,
      flake-utils,
      nixpkgs,
      hs-bindgen,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        hsBindgenPkgNames = [
          "ansi-diff"
          "c-expr"
          "clang"
          "hs-bindgen"
          "hs-bindgen-runtime"
          "hs-bindgen-test-runtime"
          "userland-capi"
        ];
        hMkPackage = { callCabal2nix, ... }: name: callCabal2nix name ("${hs-bindgen}/${name}") { };
        hOverlay = nfinal: nprev: {
          haskell = nprev.haskell // {
            packageOverrides =
              hfinal: hprev:
              nprev.haskell.packageOverrides hfinal hprev
              // nixpkgs.lib.genAttrs hsBindgenPkgNames (hMkPackage hfinal)
              // {
                debruijn = nfinal.haskell.lib.doJailbreak (nfinal.haskell.lib.markUnbroken hprev.debruijn);
                skew-list = nfinal.haskell.lib.doJailbreak (nfinal.haskell.lib.markUnbroken hprev.skew-list);
              };
          };
        };
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
            hOverlay
          ];
        };
        hsBindgenPkgsWith = hpkgs: nixpkgs.lib.genAttrs hsBindgenPkgNames (n: hpkgs.${n});
        devShellWith =
          {
            haskellPackages,
            llvmPackages,
          }:
          haskellPackages.shellFor {
            packages = _: builtins.attrValues (hsBindgenPkgsWith haskellPackages);
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
              # Misc.
              # # Fails to compile for GHC 9.12.
              # haskellPackages.friendly
            ];
            doBenchmark = true;
            withHoogle = true;
            shellHook = ''
              PROJECT_ROOT=$(git rev-parse --show-toplevel)
              export PROJECT_ROOT

              # TODO: Setting the library path still seems to be necessary,
              # because otherwise TH issues a warning that it cannot find
              # `libclang.so`. However, the actual call to `libclang` does find
              # all libraries due to BINDGEN_EXTRA_CLANG_ARGS (see below).
              LD_LIBRARY_PATH="${llvmPackages.libclang.lib}/lib"

              # Examples in manual require shared libraries.
              LD_LIBRARY_PATH="$PROJECT_ROOT/manual/c/''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
              export LD_LIBRARY_PATH

              # Similar to `rust-bindgen`, `hs-bindgen` allows usage of
              # environment variables to define `clang` arguments. See
              # `rust-bindgen-hook.sh` in Nixpkgs.
              BINDGEN_EXTRA_CLANG_ARGS="$(< ${llvmPackages.clang}/nix-support/cc-cflags) $(< ${llvmPackages.clang}/nix-support/libc-cflags) $(< ${llvmPackages.clang}/nix-support/libcxx-cxxflags) $NIX_CFLAGS_COMPILE"
              export BINDGEN_EXTRA_CLANG_ARGS
            '';
          };
      in
      {
        packages = {
          default = (hsBindgenPkgsWith pkgs.haskellPackages).hs-bindgen;
        };
        # TODO: Automatically create a matrix for a list of GHC and LLVM versions.
        devShells = {
          ghc98 = devShellWith {
            haskellPackages = pkgs.haskell.packages.ghc98;
            llvmPackages = pkgs.llvmPackages;
          };
          ghc910 = devShellWith {
            haskellPackages = pkgs.haskell.packages.ghc910;
            llvmPackages = pkgs.llvmPackages;
          };
          # Does not work. Multiple packages expect `base` 4.20 or lower.
          ghc912 = devShellWith {
            haskellPackages = pkgs.haskell.packages.ghc912;
            llvmPackages = pkgs.llvmPackages;
          };
          default = devShellWith {
            haskellPackages = pkgs.haskellPackages;
            llvmPackages = pkgs.llvmPackages;
          };
        };
      }
    );
}
