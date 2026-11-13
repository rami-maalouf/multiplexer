surfaces: ios
agent: claude opus 5.5
task: keep a composer field's width while a sent message leaves it, then shrink it

### Rough
- a glass field with `-exact-layout-transition` jumps to its new width in one frame, in both
  directions (a 167-point change between two 60 Hz frames). the transition resizes only the
  painted surface (`Surface.swift` `applySurface`: background, border, shadow); the glass
  material view keeps the laid-out frame. the motion recipe says a layout transition "resizes
  its surface (background, border, shadow)", which reads as covering a box's background, and
  says nothing about `backgroundMaterial`. finding it took frame-by-frame recordings and
  reading the iOS presenter, about forty minutes. what would help: resize a material (and a
  grouped glass slot) with the transition, or name the exception in the recipe and in a
  compiler note when a glass box declares a layout transition.
- the field's earlier "smooth widening" was accepted from six sampled screenshots: the
  neighbouring glass button fading over the field hid the jump. a recipe note that sampled
  screenshots cannot prove a layout transition would have caught it.
- a worktree that reaches the framework through a symlink failed again with "compiler input has
  no captured source identity". after `update` with the canonical path, the next build failed
  with two "mismatched types" errors between two copies of one framework crate: an unhashed
  `rlib` built through the symlink path survived in the target folder. deleting that rlib and its
  fingerprints fixed it. about fifteen minutes. what would help: canonicalize the framework path
  before any build output is written, or clean stale framework crates after `update` changes the
  path.

### Lean in
- the template's flight phases made it simple to hold the field until the message is clear.
- the presenter already hands every frame's shown size to one function (`applySurface`), so the
  material needed one more line there, plus giving its bounds back at the end. a glass group then
  draws the merge with the neighbouring button by itself.
- a delayed layout transition (`300ms 70ms ...`) chosen only when the field empties lets a
  button fade before the glass edge passes over it, with no task or timer.

### Needed
- a layout transition that resizes glass, or a documented way to animate a glass field's width.

### Checkpoints
- editing the view: smooth, two derives and one condition.
- building: rough, the symlink path and then the stale duplicate crate.
- verifying: rough, recordings showed the glass width jump that the transition was meant to cover.
- fixing the framework: smooth once found; a unit test fails without the change and passes with it.
- final recordings: the field shrinks over about 250 ms after a send and widens smoothly on typing.
