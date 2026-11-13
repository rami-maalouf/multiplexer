surfaces: ios
agent: codex gpt-6-astra
task: coordinate an outgoing bubble with the conversation's automatic scrolling

### Rough
- confirming automatic end-follow animation required reading the collection runner and its smooth-follow tests after comparing the template. a smooth scrollIntoView request after a send does not animate the earlier end-follow correction. about 10 minutes; a chat-thread recipe line showing scroll-behavior on the list would have made the distinction explicit.

### Lean in
- the existing scroll-behavior property controls end-follow animation without a framework patch.

### Needed
- scrolling: provided, including smooth end-follow and reduced-motion selection.

### Checkpoints
- diagnosis: rough, see Rough.
- visual verification: smooth; a standalone recording shows intermediate list positions during the bubble flight.
- native verification: smooth, all 14 tests pass; light/dark and 16 largest-text screens clean.

feedback: local pending separate approval; earlier approval covered only the already-sent animation diary.
