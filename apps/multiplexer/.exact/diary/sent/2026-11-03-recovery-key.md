surfaces: ios
agent: Claude Opus 5.5
task: in a chat app's Settings, an Encryption section: the account's key backup status, and a field to enter the recovery key so this device reads older end-to-end encrypted messages

### Rough
- `verify ios` reported "1 problem": "recovery refused its kept answer: kept for ["",true], this launch asks for ["",false]", listed under "refused at run time … a call or a wiring the app got wrong". The resource took a second argument, whether Settings was open, so a launch kept the answer of a run where Settings was open. Other resources in the same app show the same line in a drive's log without `verify` counting it. The fix was to key the resource by the account only, as the profile is. About 5 minutes. What would have helped: the finding saying why a refused kept answer is a problem (a wasted first answer?) and suggesting to leave view state out of a resource's arguments.

### Lean in
- A `match` in a `derive` over a mutation's reply (`match unlocked { case some(r) => … }`) gave the refusal text under the field in one line.
- `input type="password"` masked the key in the drive's output and screenshots, so a drive could type a real key without showing it.

### Needed
- a secret typed by the reader: provided (`type="password"`, masked in drives)

### Checkpoints
- The app's core library: a new test, an encrypted message from before a device signed in waits, a wrong key is refused, and the right key shows it; the account's recovery is reset through the server's API before and after.
- Drives as a test user: Settings shows Off, Needs Your Key (with the field), a wrong key's refusal, and On after the right key; `check both` clean.
- `verify ios`: clean (5 tests). `bun test`: 7 passed.
