{
  pkgs,
}:

let
  lib = pkgs.lib;
  hpkgs = pkgs.haskell.packages;
  ghcs = {
    ghc98 = hpkgs.ghc98;
    ghc910 = hpkgs.ghc910;
    ghc912 = hpkgs.ghc912;
  };
  llvms = {
    llvm18 = pkgs.llvmPackages_18;
    llvm19 = pkgs.llvmPackages_19;
    llvm20 = pkgs.llvmPackages_20;
    llvm21 = pkgs.llvmPackages_21;
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
  matrix = lib.mapAttrs (
    _: hpkgs:
    lib.mapAttrs (
      _: lpkgs:
      devShellWith {
        haskellPackages = hpkgs;
        llvmPackages = lpkgs;
      }
    ) llvms
  ) ghcs;
in
{
  inherit matrix devShellWith;
}
