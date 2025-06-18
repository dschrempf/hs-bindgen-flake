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
              haskellPackages.friendly
              # Rust.
              pkgs.rust-bindgen
              # Clang.
              llvmPackages.clang
              llvmPackages.libclang
              llvmPackages.llvm
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
        devShells = {
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
