# `contract vocab` names a tag or a property but not its attributes or values

**Status:** Open
**Systems:** `contract vocab` (`contract/cli`)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

```
$ bun exact.mjs contract vocab input
input: tag, TextInput (html)
input: handler attribute
  event input
$ bun exact.mjs contract vocab listStyle
listStyle: prop attribute
  prop listStyle, str
```

The attributes that a sign-in field needs (`autocomplete`, `autocapitalize`,
`enterkeyhint`, `inputmode`) came from the tag table in `docs/card.md`. The list styles
(`inset-grouped`, `plain`, or none) came from a table in `docs/contract-for-agents.md`.
Cost: about 5 minutes.

## What would help

`vocab <tag>` printing the tag's line from the card (its attributes and events), and
`vocab <property>` printing the values it accepts.

## Evidence

Seen at exact2 `65577096ed`. The vocab code in `contract/cli/src/main.rs` is unchanged at
`cee509ac82`.
