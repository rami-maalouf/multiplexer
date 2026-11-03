surfaces: ios
agent: Claude Opus 5.5
task: search in one chat, from its info page: a field at the bottom, the chat's messages with the words marked, and pages of its images, videos, links, files and audio, reusing the all-chats search's components

### Rough
- A `resource` declaration that ran onto a second line (`... , infoRoom)` then `as shape SearchFound else empty()` on the next) failed: "expected `as`, found end of line". The `derive` under it failed with a helpful message ("an indented line that starts with an operator continues the line above ... wrap the whole expression in parentheses"). The resource's message gives no way to wrap it, and parentheses do not apply to `as shape ... else ...`. Workaround: one 150-character line. About 1 minute. What would have helped: the resource's refusal saying "a declaration is one line", or a resource that can wrap after its call.
- An empty list passed to a source, `loadSearch(..., chatKind, [], infoRoom)`, failed: "cannot infer what `?[]` passes to `loadSearch`: nothing here says its type; pass a typed value (a state, `some(x)`, ...)". Clear, but the only typed empty list is a new state: `state noChats: string[] = []`, with a comment saying why it is there. About 2 minutes. What would have helped: the source's other call (`recentChats`, a `string[]`) typing the parameter, or a typed literal (`[] as string[]`).
- `press=(searching ? closeSearch : close)` on the info page's bar button failed: "`press=` needs an action name or `action(args)`". Workaround: an `if`/`else` with two buttons, each with its own `id="back"`. About 1 minute. What would have helped: `press=` taking a choice of two actions, as attributes take a choice of two values.
- An image's symbol sized `font-size="1.375rem"` grew past its 64-point circle at the largest text size (`check` found the overflow). `font-size="min(1.0625rem, 22px)"` was refused, "is not a valid `font-size`: expected number". The fixed size `(largeText ? "22px" : "1.0625rem")` built, then `verify ios` flagged all five as "stays 22 pt as Dynamic Type grows; a role (`font="-exact-title1"`) or a `rem` size ("1.5rem") scales". A role with a cap, `font-size="min(-exact-title3, 22px)"`, builds and passes `verify`, but no message names it: I found it in the same file's search field. About 6 minutes and three builds. This is finding 37's case again.
- A drive: `key Enter` (to press the keyboard's Search key) failed as "unknown op: key". The help says `type <target> <text>|key <Name>`, so `key` is a form of `type`; I read it as an op. About 1 minute. What would have helped: the refusal naming `type <target> key Enter`.
- A drive: `clock until state jumpedTo != "" within 20000` failed: only `==` is taken. Workaround: `clock data`, a fixed `clock +1500`, then `state jumpedTo`. About 1 minute. What would have helped: `!=` in `clock until state`, for "until it has any value".

### Lean in
- A `slot` on the info page (`if searching` then `children`, else its list) let the caller put the search in the page's place, with the page's own bar and Close. It worked the first time; the bar's title and buttons change with one prop.
- One search bar, kind button, picture tile and file row serve both searches: a `scope` prop names the chat in the placeholder, and an `inChat` prop shows the sender in place of the chat.
- `layout <testId>` showed the computed `flex_basis` and `font_size` of a row whose time wrapped under the name: the name's basis in `rem` was larger than the room beside a link's button. The cause was found in one drive.
- `check both` at the largest text size found a symbol that ran past the screen's edge (2 points), and `verify ios` found the fixed sizes; the capped role form fixed both.
- `symbol:icon.waveform` refused with a message that named the fix (an icon token in `app.tamber`, with an SF Symbol and an svg).

### Needed
- An image's `font-size` that takes `min(<rem>, <px>)`, and the fixed-type finding naming the capped role form (finding 37).
- `press=` with a choice of two actions; a typed empty list literal.

### Checkpoints
- MatrixCore: `SearchTests` 7 passed, with the new `testOneChatsMessagesAndKinds` (a photo named "snapshot" and a file named "Minutes ... .bin" are found by their type; a voice message under Audio; words narrow a kind by a word's start; another chat's message is not found).
- `bun test`: 7 passed (4 new, for the one-chat rows).
- Drives as a test user on the Simulator: the info page's Search, words, each kind, a found message opening the chat at it (marked), both X buttons back to the page; light, dark and the largest text size, `check both` clean.
- `verify ios`: clean (5 tests, check light and dark).
