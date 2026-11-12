surfaces: ios
agent: codex gpt-6.1-sol
task: preserve remote notifications across preview and store builds

### Rough
- the documented share command builds and uploads its own unsigned archive without the app's post-build notification extension step. finding this required reading scripts/share.mjs and the uploader's package documentation (about five minutes). the app cannot insert its extension before share uploads. the existing extension/entitlement limitation (finding 118) also affects previews; a declared extension or a supported packaging hook would remove this gap.

### Lean in
- the existing unsigned archive command can be reused by a separate signing and packaging step.

### Needed
- notifications: by hand; every archive needs the service extension and matching shared entitlements.

### Checkpoints
- distribution artifact verification: production archive and signed export passed, including matching app/extension symbols and notification grants.
- preview packaging: a complete ipa retained the notification extension and sender-photo activity type; the old incomplete preview was rejected.
