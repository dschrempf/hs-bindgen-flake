We have integrated this Nix Flake into the upstream [`hs-bindgen` repository](https://github.com/well-typed/hs-bindgen).

# Nix Flake for `hs-bindgen`

This Nix Flake provides resources related to
[`hs-bindgen`](https://github.com/well-typed/hs-bindgen), which automatically
generates Haskell bindings from C header files.

In particular, this Flake provides the following outputs:
- The `hsBindgenCli` client package (the name of the binary is
  `hs-bindgen-cli`).
- The `hsBindgenHook`: A Nix-specific hook setting up environment variables for
  `hs-bindgen` to interact with `libclang`. This hook is automatically used by
  outputs provided by this Flake, but may be useful in other circumstances too.
- A Nix overlay adding `hs-bindgen`-related libraries to the Haskell package sets.
- Development shells for `hs-bindgen` with different versions of GHC and LLVM.
