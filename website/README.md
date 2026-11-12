# Mux's website

The one-page site at [mux.orbitlabs.studio](https://mux.orbitlabs.studio): what Mux is and
what it offers, in a few lines, around a Three.js scene of the glass paper plane.

It is plain HTML, CSS and one module, bundled by [Bun](https://bun.sh) into static files.
The words and layout load first; the 3D scene is a separate file that loads after the page
has painted, runs only while the hero is on screen, and holds still for readers who ask for
reduced motion. Without WebGL, the logo stands in for it.

| File | What it is |
|---|---|
| `src/index.html` | The page: hero, three reasons, how it works, the close. |
| `src/styles.css` | The look: deep space, glass, and the logo's turquoise, blue and lime ([brand guide](../docs/brand.md)). |
| `src/main.js` | Reveals, the frosted bar, the title flight, and the deferred load of the scene. |
| `src/title-flight.js` | The title's full stop is the plane: one flight around the O, onto the l like a spring, and down onto the dot; then it aims at the cursor, and a click launches it again. |
| `src/scene.js` | The 3D plane in the logo's colours: three glass panels meeting at a lime nose, sparks shed from its tails, shooting stars passing the other way. It arrives as the title's plane lands. |
| `src/public/` | Copied as is: the fonts (Sora, Geist, Geist Mono; SIL OFL), the title plane (`img/plane.png`) and `404.html`. |
| `src/img/` | The logo cuts, the share image and the network logos. |
| `build.ts` | Bundles `src/index.html` into `dist/` and adds the fixed-address files. |

From `website/`:

```sh
bun install --frozen-lockfile
bun run dev        # a dev server with reload
bun run build      # dist/, ready for any static host
# maintainer only, after reviewing the built site:
./deploy.sh        # publishes production to the existing Vercel project "mux"
```

The deploy helper assumes the Vercel CLI is installed and signed in to the
maintainer's project. It publishes immediately; a local build does not deploy.
For another host or account, deploy `dist/` through your own configuration.

Keep claims aligned with [platform status](../docs/install.md) and the latest
status entries in [the plan](../tasks/plan.md). Inspect the built page at desktop
and phone widths, including reduced motion, before publishing copy/layout edits.
Network glyph attribution is in [SOURCES.md](../apps/multiplexer/assets/networks/SOURCES.md).
Bundled fonts use the SIL Open Font License; their copyright and license texts
are copied with the site under [font licenses](src/public/fonts/licenses/).
