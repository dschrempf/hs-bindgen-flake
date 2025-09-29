{
  stdenv,
  haskellPackages,
  hsBindgenHook,
}:

stdenv.mkDerivation {
  pname = "hs-bindgen";
  version = haskellPackages.hs-bindgen.version;

  propagatedBuildInputs = [
    hsBindgenHook
  ];

  buildCommand = ''
    mkdir -p $out/bin
    ln -s ${haskellPackages.hs-bindgen}/bin/hs-bindgen-cli $out/bin/hs-bindgen-cli
    ln -s ${haskellPackages.hs-bindgen}/bin/hs-bindgen-cli $out/bin/hs-bindgen
  '';
}
