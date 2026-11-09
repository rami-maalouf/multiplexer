# `docs svg` opens the theme recipe instead of the symbols recipe

**Status:** Open
**Systems:** exact.mjs, docs
**Severity:** P3
**Author:** Codex, from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-09

## What happens

`bun exact.mjs docs svg` is meant to open the symbols recipe. The docs topic map had no
`svg` entry, so the lookup ranked the theme recipe first (it mentions SVG icons). The
framework's own docs test asserts that `docs svg` prints the symbols recipe, and that
assertion failed.

Cost: about five minutes to find the missing topic key and add it.

## What would help

Keep a topic key for every docs word the CLI tests (and the help) invite, including `svg`
→ the symbols recipe.

## Evidence

Seen on 2026-11-09 while moving an app onto the public framework checkout at
`94b8671f7`. Fixed locally by adding `svg: 'Recipe: symbols'` to the docs topic map in
`scripts/exact.mjs`; the filtered docs test then passed.
