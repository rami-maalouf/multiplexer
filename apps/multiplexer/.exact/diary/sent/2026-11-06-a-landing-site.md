surfaces: web
agent: Claude Opus 5.5
task: a one-page landing site for a chat app, from `exact new` and `pattern site`, dark only, with a brand's colours; built ahead (`render=build`) for a static host

### Rough
- A radial gradient with an explicit size, `radial-gradient(960px 576px at 78% 0%, #519AFF38, transparent 70%)`, was refused with "a stop's colour is a CSS colour (hex, `rgb()`, ...)". The colours were fine: only extent keywords are taken for the size. Tried `rem`, then `px`, then hex for `rgba()`; found the grammar in the kernel's gradient source. About 5 minutes. A message that names the size ("an explicit radial size is not taken; use an extent keyword: `closest-side`, ...") would have saved it; `contract vocab gradients` lists what is refused but not this.
- Removing the pattern's API (its `.env`, `server.ts` and app.json's `env`) and its `grants` line failed the type check: `Property 'grants' does not exist on type ...`. A site with no network needs `export const grants = ""`. About 2 minutes. The site recipe could say it in its "A setting" section.
- A width branch never showed its wide side on a built page. `exactViewport()` read on the root, `derive wide = viewport.width >= 720`, `if wide` around the section links. The page is built at a phone's width; at 1280 px the checkpoint says `data-wake="[["(width >= 720px)",false]]"`, the runtime does wake (`app.js` loads, `self.exact.ready`), but the links stay out until the window is resized, after which they show. LLP 1048.007 D2 (2026-10-31) says a woken page asks the device's sources again. Seen at exact2 `31063d7dbb` in a painting headless Chromium. Before that, the same branch inside a child component also stayed narrow. About 25 minutes. Workaround: no width branch at all; the links are one unbreakable group in a wrapping, clipped row, so CSS hides them where they do not fit.
- `font-size="clamp(42px, 8vw, 64px)"` was refused ("expected number"); a fluid title needed a width branch, which the item above ruled out, so the title has one size. About 2 minutes.
- `verify`'s contrast check reported a pill's label as 1.2:1 (`#0c1118 on #152a2f`): the pill's fill is a `background-image` gradient (about 6:1), and the check read the page under it. The same for numbered circles. Accepted in `verify.accept` with a reason. About 3 minutes.
- `verify.accept` took a `fixed-type` finding for a text with a literal `testId` (`phone-*` matched `phone-clock`), not for one whose `testId` is a template inside a `for` (`` testId=`phone-name-${c.id}` ``). Workaround: one fixed size on the rows' parent and `em` sizes on the texts. About 5 minutes.
- The document's own background is `var(--exact-background)`, black in dark mode, and a dark-only brand page (`#0C1118`) has no documented way to set it, so the overscroll above and below the page shows black. Not fixed. About 5 minutes of looking.

### Lean in
- `tamber` tokens with `scheme=fixed` turned 46 one-scheme colour warnings into a 22-token brand file in one step, and the page reads `brand.blue`, not a hex.
- `verify` caught real faults at once: a glow 5 px wider than a phone, grey text at 3.6:1, display text 2 to 4 px taller than its line box, a title column that ran 118 px off a phone at the largest text, and every fixed `font-size`. Each message named the fix.
- `web-build` takes about a second, and `dist/` serves from any static host as it is.
- The capture script keeps a built page script-free until it is needed: no JavaScript ran for the whole page.

### Needed
- deep links: provided (`#why` section links)
- none else beyond views and data

### Checkpoints
- `exact new`: smooth
- web dev loop (`web-build`, `serve dist`): smooth
- editing app.contract / app.ts: rough (gradient size, `grants`, the width branch, `clamp`)
- driving the app (`test web`, `agent web`): smooth
- verify: rough (gradient contrast, template testIds), then clean
- deploy: smooth (`dist/` on a static host)

### Later the same day
- The site was asked to show a WebGL (Three.js) scene. The native views recipe shows Swift views
  only, and I found no documented way to place a web canvas from a module in a built site, so the
  site was rebuilt as plain HTML with a bundler instead. Not measured as a cost; a pointer in the
  website recipe ("a canvas or WebGL scene on a site: ...") would settle it either way.
