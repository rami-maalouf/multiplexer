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

## Pull request (2026-11-03)

https://github.com/ccheever/exact2/pull/1359 (fixes part of it): `contract vocab <tag>` prints the tag's attributes and events, and `listStyle` lists its values. Values for every property are a design question.

## Seen again at `ed43ad09a0` (2026-11-03), before that pull request

A custom voice-message player (a hidden `audio` and the app's own play button, progress and
speed): `contract vocab audio` answered only "tag, Video (html); sets semanticTag=audio;
positional src". `vocab playbackRate`, `preservesPitch`, `paused` and `timeupdate` each answered
by name, but the list of what the media node takes (and that an `audio` without `controls` draws
no box, so a custom player is a hidden `audio`) came from the video LLP (§3 and §8). About 5
minutes. A recipe for "a custom audio player" (play and pause through `paused`, progress through
`timeupdate`, `ended`, speed through `playbackRate`) would have saved the search; once found,
each of these worked on the first drive.


## Further evidence: desktop keys, 2026-11-08

At Exact `afac7b1370`, ordinary shortcut and keyboard vocabulary searches did not
lead to textarea key handling. The keyboard-and-focus recipe covers input submit;
compiler diagnostics and the `KeyboardEvent` card supplied `isComposing`. About
4 minutes looking through docs and source. An Enter-to-send example with
Shift+Enter and composition handling would make the desktop path discoverable.
