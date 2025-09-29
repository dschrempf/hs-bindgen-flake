final: prev:
let
  hlib = final.haskell.lib.compose;
in
{
  haskell = prev.haskell // {
    packageOverrides =
      hfinal: hprev:
      prev.haskell.packageOverrides hfinal hprev
      // {
        debruijn = hlib.doJailbreak (hlib.markUnbroken hprev.debruijn);
        # TODO_PR: See
        # https://gitlab.haskell.org/ghc/ghc/-/issues/25681.
        optics = hlib.dontCheck hprev.optics;
        skew-list = hlib.doJailbreak (hlib.markUnbroken hprev.skew-list);
      };
  };
}
