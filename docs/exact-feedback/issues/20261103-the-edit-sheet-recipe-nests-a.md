# The edit-sheet recipe nests a sheet's header as lower-header-nested warns against

**Status:** Open
**Systems:** compiler, docs
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A sheet route whose content is a component, written as the edit-sheet recipe writes one, warned
`lower-header-nested`:

```contract
if e.name == "pick"
  column navigationKey=`${e.id}` navigationPresentation="modal" position="absolute" inset=0
    PickSheet(...)            // its root is a column whose first child is the header
```

"this `header` is not its route's first child (it is inside the `column` that is), so on iOS it is
not the navigation bar … Make it the route's first child: move the route's `navigationKey`, with
its `navigationPresentation`, `navigationScroll` and the rest, onto the box that holds the header
(a screen component's root) …". The fix it names worked (the component takes the route's id as a
prop and its root carries the navigation props).

But the edit-sheet recipe (`docs/recipes/edit-sheet.md`) has the same shape (the route's
`column` → `for` → `EditLift(...)` → `column` → `header`), and it compiles with no warning
(its first block, compiled on its own at `ed43ad09a0`: `[]`). So the recipe teaches a shape that
the rule says is not a bar, or the rule misses the recipe's `for`.

Cost: about 5 minutes.

## What would help

The recipe and the rule agreeing: the recipe putting the navigation props on the component's
root (as the warning says), or the rule accepting both shapes.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`.
