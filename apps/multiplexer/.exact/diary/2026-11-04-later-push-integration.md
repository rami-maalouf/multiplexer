surfaces: ios
agent: Codex GPT-6 Astra
task: integrate space and request screens with shared session storage

### Rough
- the combined native rebuild took 102.4 seconds before verification; the initial estimate for the whole verification was 65 seconds. the complete check took 186.9 seconds. existing native rebuild feedback applies; an estimate that includes invalidated native modules would help.

### Lean in
- the normal framework checkout verified the combined app without a local framework experiment.

### Needed
- none

### Checkpoints
- seven authored ios tests passed; light and dark checks were clean; nine largest-text screens had no overflow.
- authenticated fallback-preview display screenshots from the feature branch were inspected in both appearances; the integrated view code is identical.
- ios build: rough, see the rebuild estimate in Rough; verification passed without a workaround.
