surfaces: ios
agent: codex, gpt-6-astra
task: compare a template on its pinned runtime and a newer runtime after a gesture repair

### Rough

- The unchanged chat template failed to bake on current main: `column` has no attribute `swipe` or `swipe-direction`, layout-margin variables are unknown, and `calc(100cqw - 32px)` is refused. Its pinned branch has features absent from main. About three minutes for the failed native build; continuing with the pinned template as a product comparison, without claiming a same-app runtime A/B. A template compatibility matrix would make this limitation clear before building.
- A template's native-list structure looked comparable, but its pinned framework did not contain the touch observer being investigated. Checking the pin's actual source was necessary before treating it as a control. Template documentation that names the runtime differences would make cross-version comparisons easier.

### Lean in

- The template generator accepts an explicit framework checkout and warns when that checkout does not include its pin. Separate app identities allow both variants to coexist on one simulator.
- The supported pin builds successfully and all 14 authored native tests pass, including long history, draft persistence, reply and search. All 13 data tests pass too.

### Needed

- navigation: provided
- keyboard dismissal: provided
- background work: provided; system-return gesture verification still needs native device automation

### Checkpoints

- exact new: smooth; both variants generated through the template's supported command
- iOS build: smooth on the supported pin; rough on current main, as described above
- driving the app: smooth native test run; Home returns and subsequent history scrolling worked on the simulator, without establishing physical-device equivalence
