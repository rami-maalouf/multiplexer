surfaces: ios
agent: Claude Opus 5.5
task: a chat app's list rows with no preview for chats whose newest event is no message, and bridged captions shown with raw markdown: read the real events, fill the rows from the server's newest message, and turn captions' html into text

### Rough
- A drive cannot wait in real time for work the app does off its clock (requests in the background). `clock until state <path> > 0` is refused (only `==` with a JSON literal), and a `clock until` that times out ends the drive. I used a condition that is never true as a 60 s wait, then a second drive to read the state. About 5 minutes.

### Needed
- A real-time wait step (`wait 60000`), or `clock until` with a comparison, or a timeout that does not end the drive.

### Checkpoints
- Real data, read-only: 132 of 187 rows without a time before, 5 of 327 after (no readable messages). Captions show their title, then their link once.
