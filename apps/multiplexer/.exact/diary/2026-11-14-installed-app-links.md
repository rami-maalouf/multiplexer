surfaces: ios
agent: claude opus 5.5
task: open any link an installed app claims in that app, else in the in-app browser

### Rough
- the framework's `openURL` has no "only if an app claims it" form (universal links only), so a link cannot try an installed app and fall back to the in-app browser from the contract. a small native op in the app's own module asks the system and answers whether an app took it; the contract then opens the in-app browser itself. about 10 minutes. an `openURL` option, or an in-app browser option to prefer a claiming app, would remove the module code.
- the app module's context has no log call (packages have `context.log`), so the op cannot journal what it asked under the agent. about 2 minutes: a build error, then the line was dropped.

### Lean in
- a mutation's `then` action can send the in-app browser after a native answer; the drive journal showed the browser held after the answer.

### Needed
- universal-link-only open with a fallback: by hand; a native op in the app module.

### Checkpoints
- drive: a reel link asks the module, which answers not opened under the agent; the in-app browser opens.
- 14 authored iOS tests and 61 bun tests pass.
