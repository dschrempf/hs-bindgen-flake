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
        ghcVersion = "ghc98";
        rBindgenVersion = "0.70.1";
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
                debruijn = nfinal.haskell.lib.markUnbroken hprev.debruijn;
                skew-list = nfinal.haskell.lib.doJailbreak (nfinal.haskell.lib.markUnbroken hprev.skew-list);
              };
          };
        };
        # See ./test/internal/Test/Internal/Rust.hs::rustBindgenVersion.
        rOverlay = final: prev: {
          rust-bindgen-unwrapped = prev.rust-bindgen-unwrapped.overrideAttrs (old: rec {
            version = rBindgenVersion;
            src = prev.fetchCrate {
              pname = "bindgen-cli";
              inherit version;
              hash = "sha256-6FRcW/VGqlmLjb64UYqk21HmQ8u0AdVD3S2F+9D/vQo=";
            };
            cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
              pname = old.pname;
              inherit version src;
              hash = "sha256-r4ZI+uybK3MzJMYlRwmNhZMBO3aMKCIIznOOdQ0ReqU=";
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
        hpkgs = pkgs.haskell.packages.${ghcVersion};
        lpkgs = pkgs.llvmPackages;
        hsBindgenPkgs = nixpkgs.lib.genAttrs hsBindgenPkgNames (n: hpkgs.${n});
      in
      {
        packages = hsBindgenPkgs // {
          # Does not build yet, because package versions in Nixpkgs are outdated.
          default = hsBindgenPkgs.hs-bindgen;
        };
        devShells.default = hpkgs.shellFor {
          packages = _: (builtins.attrValues hsBindgenPkgs);
          nativeBuildInputs = [
            # Haskell.
            hpkgs.cabal-install
            hpkgs.ghc
            # (hpkgs.ghc.override { stdenv = pkgs.clangStdenv; })
            hpkgs.haskell-language-server
            # Rust.
            pkgs.rust-bindgen
            # Clang.
            lpkgs.clang
            lpkgs.libclang
            lpkgs.llvm
          ];
          # # The interplay of Template Haskell and `libclang` is problematic
          # # because header files and libraries are not found in the Template
          # # Haskell stage of GHC compilation, which is executed in a restricted
          # # environment. Usually, setting `propagatedBuildInputs` is enough; not
          # # so here, see below.
          # propagatedBuildInputs = [
          #   lpkgs.clang
          #   lpkgs.libclang
          #   lpkgs.llvm
          # ];
          doBenchmark = true;
          withHoogle = true;
          shellHook = ''
            PROJECT_ROOT=$(git rev-parse --show-toplevel)
            export PROJECT_ROOT
            # When accessing the `libclang` interface during GHC compilation
            # with Template Haskell, the Nixpkgs wrapper does not work, and so
            # we need to set include paths manually.

            # TODO: Remove this when PR is merged.
            C_INCLUDE_PATH="$(< ${lpkgs.clang}/nix-support/orig-libc-dev)/include:$(< ${pkgs.gcc}/nix-support/orig-cc)/lib/gcc/x86_64-unknown-linux-gnu/14.2.1/include"
            export C_INCLUDE_PATH
            LD_LIBRARY_PATH="${lpkgs.libclang.lib}/lib"
            # Examples in manual require shared libraries.

            LD_LIBRARY_PATH="$PROJECT_ROOT/manual/c/''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
            export LD_LIBRARY_PATH

            # Similar to `rust-bindgen`, `hs-bindgen` allows usage of
            # environment variables to define `clang` arguments. See
            # `rust-bindgen-hook.sh` in Nixpkgs.
            BINDGEN_EXTRA_CLANG_ARGS="$(< ${lpkgs.clang}/nix-support/cc-cflags) $(< ${lpkgs.clang}/nix-support/libc-cflags) $(< ${lpkgs.clang}/nix-support/libcxx-cxxflags) $NIX_CFLAGS_COMPILE"
            export BINDGEN_EXTRA_CLANG_ARGS
          '';
        };
      }
    );
}
