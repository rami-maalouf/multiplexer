# Mux's website

The one-page site at [mux.orbitlabs.studio](https://mux.orbitlabs.studio): what Mux is, why it
exists and how it was built. It is an [Exact](https://github.com/ccheever/exact2) site, like
the app, and every page is built ahead (`render=build`), so `dist/` is plain files for any
static host.

| File | What it is |
|---|---|
| `app.contract` | The page: its sections, the drawn phone in the hero, the header and footer. |
| `app.ts` | The words: chats in the drawing, reasons, features, steps, stats, milestones. |
| `app.tamber` | The brand's colours from `docs/brand.md`, fixed (the site is dark only). |
| `app.test.contract` | Its tests. |
| `assets/` | The logo, cut from `apps/multiplexer/assets/mux-icon.png`, and the network logos. |

```sh
bun exact.mjs web-build --out dist   # build, about a second
bun exact.mjs serve dist             # serve on 127.0.0.1:8765, rebuilding on each edit
bun exact.mjs test web               # the tests
bun exact.mjs verify                 # tests, contrast, clipping, largest text: must be clean
./deploy.sh                          # build and publish to Vercel (project "mux")
```

Keep each claim true to the repository: `tasks/plan.md` and `server/README.md` are the
sources. The chats in the drawing are made up, so no real chat is ever shown.
