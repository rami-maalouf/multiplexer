surfaces: ios
agent: Codex gpt-6-astra
task: distinguish a scrolling performance regression from a gesture lifecycle repair

### Rough
- the foreground diagnostic reports whether a list moved, but not frame cadence, so passing return tests did not establish smooth scrolling. about ten minutes collecting an external profile; a native hitch metric alongside gesture completion would make this gap visible.
- comparing a one-line native change in a separate framework checkout required repointing the app's generated cargo paths with `exact update`; the initial environment-only override was rejected. about two minutes. a scoped native-source comparison build would avoid rewriting unrelated generated project metadata.

### Lean in
- the numeric return log confirmed that the repaired touch observer finishes and the list moves after system Home returns without exposing app content.

### Needed
- scroll performance: external profiling; attribution still under investigation

### Checkpoints
- physical return diagnostics: observer finishes and scrolling responds
- automated inbox profiling: frame hitches measured; automation adds accessibility overhead
- manual profiling: no usable scrolling baseline obtained
- comparison build: prior observer lifecycle built; temporary project/framework edits restored; not installed
- attribution: pending a controlled comparison; no additional runtime fix claimed
