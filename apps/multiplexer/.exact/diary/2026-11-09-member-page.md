surfaces: ios
agent: Devin (T3 Code)
task: a member's own page (face, name, network, a direct chat away) opened from the group's sender picture and from the members' list on the chat's info page

### Rough
- `clock until state <path> != "<literal>"` is refused: `clock until state` takes only `== <literal>`. Two failed ops across two drives; the workaround was `clock data` + `clock +N`. What would have helped: the error hinting the supported comparisons (`==` only), or supporting `!=`.
- An `if` condition cannot continue on the next line with `and`: two syntax errors (`syntax-expected-name`, `syntax-bad-dedent`). The condition had to stay on one long line (175 chars). What would have helped: the grammar doc naming the rule, or the parser accepting a leading `and` continuation.
- `analyze-send-twice` flags two `if` branches that each call an action which ends in the same `send` (`follow` → `keepDraftNow` → `send keptDraft`), even though the `if`s test one value (`top(nav).name`) against different literals and can never both run. Merged the condition into one `if`; lost the per-case comment placement. What would have helped: the same-value-different-literals exemption covering calls inside actions, or the error naming that merging the `if`s is the intended fix.
- `go(nav, "/room/<other>")` pushes a second `room` entry instead of popping to or replacing the existing one; a stacked second room then reads the first room's resources (the app derives the open room from the first `room` entry). Expected `go` to collapse a same-route visit or warn. Hand-collapsed the stack with `replace(back(nav)…)` by depth instead. About 15 minutes including two verification drives. What would have helped: `go` documented as never reusing an existing entry of the same route, or a nav function that replaces the nearest entry of a named route.

### Lean in
- `path("member", room, user)` + `top(nav).params.user` gave a typed per-member route in one line; `%40`-encoded user ids round-trip cleanly.
- A mutation's `then` action ran the navigation only when the recorded visit id still matched the top entry, which made the "page becomes the chat" transition safe for free.
- Reusing the members' resource for the page meant a tap deep-linked straight into already-loaded data (name, picture, initials) with no new data source.

### Needed
- navigation to an existing route with collapse: by hand (`replace(back(nav)…)` by depth)
- a per-person profile: composed from the chat's members' resource (name, picture, id)

### Checkpoints
- contract build (`--errors-only`): smooth
- iOS build: smooth
- driving the app (`exact.mjs agent`): rough (op syntax refusals at first; then clean drives)
