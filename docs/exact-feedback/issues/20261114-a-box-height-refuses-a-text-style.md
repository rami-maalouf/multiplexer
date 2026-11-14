# A box's height refuses a text-style length, and the refusal prints seven times

- date: 2026-11-14
- severity: P3
- cost: about two minutes

A button lines up a symbol and a label. Symbols of different shapes draw at different heights,
so labels in one row did not line up. The fix was a box of one height around each symbol, as
tall as the symbol's size: `height="min(-exact-title3, 24px)"`, the same value the symbol takes
as `font-size`.

`contract build --json --errors-only` refused it: "`height=\"min(-exact-title3, 24px)\"` is not a
valid `height`: expected a length: a text style is a `font-size`". The same diagnostic appeared
seven times in the JSON array, once per use site of the component, with the same file, line and
column.

What worked: `font-size="min(-exact-title3, 24px)"` on the box and `height="1.2em"`.

What would help:
- The refusal suggesting the `em` form (`font-size` on the box, then a height in `em`).
- One diagnostic per source location, so a short error list stays short.

No app name, account or message content is included.
