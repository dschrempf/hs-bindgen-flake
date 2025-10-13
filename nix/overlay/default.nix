{
  lib,
  libclang-bindings-src,
  hs-bindgen-src,
}:
let
  libclangBindings = import ./libclang-bindings.nix {
    inherit libclang-bindings-src;
  };
  hsBindgen = import ./hs-bindgen.nix {
    inherit hs-bindgen-src;
  };
  hsFixes = import ./overrides.nix;
  rustBindgen = import ./rust-bindgen.nix;
  default = lib.composeManyExtensions [
    libclangBindings
    hsBindgen
    hsFixes
    rustBindgen
  ];
in
{
  inherit
    libclangBindings
    hsBindgen
    hsFixes
    rustBindgen
    default
    ;
}
