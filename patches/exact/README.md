# Pinned Exact integration

`mux-integration.patch` is the source difference from public upstream commit
`94b8671f70fe2e25b307a40e7fce66dc27c9f802` to the validated local integration
`6f4917bdab8b5392a78c2e4e6b6d8d3b28e9317c`. It preserves scroll return, keyboard
toolbar, navigation tint, recording levels, archive packaging and Mac toolbar
behavior. It also finishes the passive scroll-touch recognizer after its final contact
ends or is cancelled, with focused native regression coverage. Physical rebuilt
Home-indicator acceptance remains pending.

Prepare a fresh source checkout with `bun scripts/setup-exact.ts <new-directory>`.
The command checks the patched Git tree against
`d01576d564783957ae64e0b0f3d8cee1a07d4922`, so it does not depend on the local
integration commit being published upstream. It refuses an existing destination.
The integration remains an uncommitted patch for inspection; the shared maintainer
checkout is not modified. Run Exact's setup in the resulting directory afterward.

The framework-derived patch is distributed with Exact's MIT license in `LICENSE`.
The application source retains its repository license.
