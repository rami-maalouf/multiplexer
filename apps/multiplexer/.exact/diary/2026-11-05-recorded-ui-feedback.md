surfaces: ios
agent: t3 code / gpt-6-astra
task: document a recorded phone UI comparison without implementation

### Rough

No new framework-tooling friction was exercised in this documentation-only task. Browser
retrieval trouble was tooling outside the framework and is not filed as framework feedback.
The recording shows unresolved horizontal list movement, an app-return scrolling complaint
and material differences; these are product evidence, not a proven framework cause. Prior
narrow drag-release tests cannot establish absence of whole-list horizontal movement.

### Lean in

Authored backdrop and input hierarchy are readable in source, allowing the report to name
likely surfaces while keeping visible behavior separate from an unproved host diagnosis.

### Needed

- scrolling: reliable vertical-list interaction through app foregrounding; not validated here
- materials: continuous native underlay and safe-area readability; recorded expectations only

### Checkpoints

- source/evidence review: smooth; requirements, private source frames and explicit limits recorded
- editing app contracts, building, driving and testing: not performed
- framework feedback: local only; no new root-cause claim or public send
