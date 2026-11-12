surfaces: ios
agent: codex gpt-6.1-sol
task: make native notification builds reproducible with another signing identity

### Rough
- remote notification identities still require a post-build app-owned packager, because the manifest cannot declare the custom notification service, its shared app/keychain groups, and push entitlements (known finding 118). self-hosted builds must keep manifest identity, runtime session access and final signed products consistent. a declared extension and entitlement model would remove this extra synchronization.
- confirming that the device build accepts the profile through EXACT_PROFILE required reading framework signing sources (about two minutes). a documented profile option beside the device build command would have made this direct.
- small native configuration edits rebuilt the complete native module, including vendor bindings: the production module step took 79.7 seconds. this repeats finding 1; separate cached vendor compilation would reduce the loop.

### Lean in
- the framework's public source revision and a source patch can reproduce the previously validated integration tree exactly.

### Needed
- notifications: by hand; compile and sign a service extension sharing the app's session.

### Checkpoints
- public framework setup: reconstructed the validated source tree from the public upstream revision and bundled patch.
- custom signing configuration: focused fixtures passed, including native runtime metadata and a pre-build mismatched-profile refusal.
- device install: complete wrapper succeeded with configured metadata and strict app/extension signatures; no app launch.
- native authored tests: all 13 passed on the owned simulator, then it was shut down.
