# An empty list passed to a source cannot be typed

**Status:** Open
**Systems:** Contract compiler (types)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A source takes a list of ids (`recent: string[]`) from one caller. A second caller has no ids
to pass:

```contract
resource chatFound = loadSearch(session.userId, chatSearching, chatQuery.trim(), chatKind, [], infoRoom) as shape SearchFound else empty()
```

"cannot infer what `?[]` passes to `loadSearch`: nothing here says its type; pass a typed value
(a state, `some(x)`, a list from a source or `map`/`filter`)". The first caller passes a
`string[]` state to the same parameter, but that does not type it. The workaround is a state
that exists only to be an empty list of strings:

```contract
// the search in a chat shows no recent chats: an empty list of their ids, typed for the source.
state noChats: string[] = []
```

Cost: about 2 minutes, and a state with no other use.

## What would help

- A source's parameter typed by its other calls (or by the data module's TypeScript), so `[]`
  takes that type.
- Else, a typed empty list literal, and the refusal naming it.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS Simulator (iOS 26.5).
