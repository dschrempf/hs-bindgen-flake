{
  pkgs,
}:

let
  hsBindgenDev = import ./hs-bindgen-dev.nix { inherit pkgs; };
in
{
  _module.args.pkgs = pkgs;

  packages = {
    inherit (pkgs) hsBindgenHook hs-bindgen-cli;
  };

  devShells = hsBindgenDev.devShells // {
    default = pkgs.callPackage hsBindgenDev.devShellWith { };
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

}
