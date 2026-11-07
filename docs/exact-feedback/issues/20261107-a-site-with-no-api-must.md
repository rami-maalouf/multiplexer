# A site with no API must still export grants

**Status:** Open
**Systems:** docs, web
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-07

## What happens

`pattern site` writes an API stand-in (`server.ts`, `.env`, app.json's `env`, and
`export const grants = \`net.fetch ${API}\`` in app.ts). A landing page with no API removes
them, and the type check fails: `__exact_entry.ts(4,35): error TS2339: Property 'grants' does
not exist on type ...`. The data module must still export `grants`, as an empty string.

Cost: about 2 minutes.

## What would help

One line in the website recipe's "A setting" section: "With no API, keep `export const grants
= ''`", or a message that names the missing export.

## Evidence

Seen on 2026-11-06 at exact2 `31063d7dbb`.

