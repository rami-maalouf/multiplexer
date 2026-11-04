# View-local let reports an unknown tag instead of an unsupported binding

**Status:** Open
**Systems:** compiler, diagnostics
**Severity:** P3
**Author:** Codex, from an external app friction log
**Date:** 2026-11-04

In a view's `for` body, a local `let` binding produced an unknown-tag diagnostic and four
secondary unknown-name errors at its uses. The calculation was intended to supply a row's
selected and partially selected states.

Moving the calculation into a small child component's `derive` compiled successfully. This
cost about two minutes. A diagnostic saying that view-local bindings are unsupported, with
the child-component alternative, would make the restriction clear without chasing its uses.

Seen on iOS at framework commit `ed43ad09a0`, 2026-11-03. Recorded during implementation
in the task diary. No framework change or external submission was made.
