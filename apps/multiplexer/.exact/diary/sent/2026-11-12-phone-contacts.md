surfaces: ios
agent: codex
task: connect a device address book to search

### Rough
- finding the contacts permission declaration required searching the device capability registry and a package test fixture (about 5 minutes). the permissions recipe covered location but did not point to the address book query example. a contacts recipe linking the query and purpose declaration would help.
- the first native build seeded cached crates but still recompiled the framework and bindings. native verification had to wait several minutes; a build estimate separating framework and module work would help.

### Lean in
- the contract compiler accepted the search and settings composition on the first check.

### Needed
- contacts: by hand for reading and observing the native store; permission purpose declaration provided.

### Checkpoints
- editing app.contract / app.ts: smooth
- iOS build: rough (rebuild wait above)
