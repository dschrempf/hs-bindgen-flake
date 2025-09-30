This Nix Flake provides resources related to
[`hs-bindgen`](https://github.com/well-typed/hs-bindgen), which automatically
generates Haskell bindings from C header files.

In particular, this Flake provides the following outputs:
- The `hs-bindgen` client package.
- The `hsBindgenHook`: A Nix-specific hook setting up environment variables for
  `hs-bindgen` to interact with `libclang`.
- A Nix overlay adding `hs-bindgen`-related libraries to the Haskell package sets.
- Development shells for `hs-bindgen` with different versions of GHC and LLVM.
