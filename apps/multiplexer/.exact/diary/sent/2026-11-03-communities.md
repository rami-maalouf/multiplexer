surfaces: ios
agent: Claude Opus 5.5
task: a chat app's filter sheet lists the account's communities (chat groups that a bridge puts in a parent group) after its networks, and choosing one narrows the chat list to its chats

### Rough
- `overflow-wrap="break-word"` on a row's name, so one long word stops spilling at the largest text size, made iOS hyphenate names at a break: "Insta-gram", "Commu-nity". `contract vocab hyphens` says the default is `manual`, which in CSS adds a hyphen only at a soft hyphen in the text. I took the attribute out and moved the row's count under the name at the accessibility sizes instead. About 5 minutes and one drive. What would have helped: the iOS host breaking without a hyphen under `hyphens: manual`, as a browser does, or the vocab entry saying that iOS hyphenates a broken word.

### Lean in
- `check` at the largest text size named the one word that spilled ("its text is 16 pt wider than its box"), in a row that an earlier task had built, so the fix was found on the way.
- `tap <scroll> drag 0 -300 from <x> <y>` scrolled a sheet's rows in a drive, and its refusal for a start point outside the screen said which point left it.

### Needed
- none

### Checkpoints
- Core: the rule that tells a bridge's own group from a community, the order by name, the filter and its counts, and the group graph, in unit tests; an end-to-end test of a group made by a test user.
- Drive on a real account (read only): 14 communities after the first sync caught up (12 before), the bridges' own groups left out; one community narrowed the list to its 2 chats; `check` clean in dark, light and the largest text size.
- `verify ios`: clean.
