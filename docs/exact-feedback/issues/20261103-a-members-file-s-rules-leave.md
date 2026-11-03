# A members file's rules do not say whether it may also hold components, and `contract vocab` does not know `members`

**Status:** Open
**Systems:** docs (contract-grammar, "Components and actions"), `contract vocab`
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

To keep a shared root small (two agents edit it at the same time), a feature's state, resource,
mutation, tasks and actions went into a members file (`members "./details-members.contract"` in
the root, `members App` in the file). Its components and `fn`s needed a home too. The grammar
says a members file "holds one `members` block" and that "any other name a members file calls (a
shape, a `fn`, a component) comes from its own `use` lines", but not whether the same file may
also declare the components and `fn`s that its members and the root use. The app wrote two files
rather than try. `bun exact.mjs contract vocab members` answers "`members` is not a tag, an
attribute, a standard function, a recipe or a pattern", so the lookup that the start-here page
recommends finds nothing; the rule was found by grepping the docs and `apps/excord`.

Cost: about 5 minutes.

## What would help

- One sentence in the grammar: a members file may (or may not) declare components, shapes and
  `fn`s beside its block.
- `contract vocab members` answering with the members file's card: the root's line, the block,
  what it may hold, and `apps/excord/typing.contract` as an example.

Both are pull request candidates.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`.

## Pull request (2026-11-03)

https://github.com/ccheever/exact2/pull/1364 (fixes it): a members file may declare shapes, `fn`s and components beside its block (its block calls them as they are; another file names them on a `use` line). The grammar says so, and `contract vocab members` answers with a two-file example.

More evidence on 2026-11-03 at `ed43ad09a0`: a members file's `mutation renamed as shape Reply`
named a shape of the root, and `contract-use-missing` said "`Reply` is declared in
`app.contract`, which uses this file: naming it here would make a cycle; move it to a file both
can use". Moving a shape that 20 of the root's mutations use would touch a file other agents
edit, so the feature's file declared a second `ok: bool` shape. A members file sees its root's
state; seeing its root's shapes too would remove the copy. About 2 minutes.
