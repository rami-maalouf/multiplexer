# Pinned Exact integration

`mux-integration.patch` is the source difference from public upstream commit
`94b8671f70fe2e25b307a40e7fce66dc27c9f802` to the validated local integration
`8536d208c40f97be3f132ea266d5029e2e3c10ba`. It preserves scroll return, keyboard
toolbar, navigation tint, recording levels, archive packaging and Mac toolbar
behavior. It includes the existing focused framework tests.

Prepare a fresh source checkout with `bun scripts/setup-exact.ts <new-directory>`.
The command checks the patched Git tree against
`bc7d0c19b7e492d6a198c3b7d0b044b5dff9a05d`, so it does not depend on the local
integration commit being published upstream. It refuses an existing destination.
The integration remains an uncommitted patch for inspection; the shared maintainer
checkout is not modified. Run Exact's setup in the resulting directory afterward.

The framework-derived patch is distributed with Exact's MIT license in `LICENSE`.
The application source retains its repository license.
