# A virtualized list has no place for a row outside its `for`

**Status:** Open
**Systems:** virtualized list (reachstart, reachend), recipes (chat-thread)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

A chat transcript loads older messages from `reachstart`, which fires only on
`list virtualized=true` with one direct keyed `for` (`contract vocab reachstart`). So the
list has no place for a row that is not a message: a spinner at the top while older
messages load, or "This is the beginning of the chat" once there are none. Messages and
other chat apps show both. The app shows neither.

The workaround would be fake rows in the data module's list (a "loading" or "start"
message with its own key), which mixes view state into the data.

Cost: about 3 minutes to decide, and a chat that gives no sign that it is loading.

## What would help

- A header and a footer slot on a virtualized list, outside its `for` (as a table view has
  its header and footer views).
- Or a line in the `chat-thread` recipe that shows how a transcript says it is loading
  older messages.

## Evidence

Seen on 2026-10-27 at exact2 `cee509ac82`, on iOS.
