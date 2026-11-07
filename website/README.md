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
| `src/styles.css` | The look: deep space, glass, and the logo's turquoise, blue and lime (`docs/brand.md`). |
| `src/main.js` | Reveals, the frosted bar, and the deferred load of the scene. |
| `src/scene.js` | The plane: three glass panels meeting at a lime nose, with three streams of light converging into it. |
| `src/public/` | Copied as is: the fonts (Sora, Geist, Geist Mono; SIL OFL) and `404.html`. |
| `src/img/` | The logo cuts, the share image and the network logos. |
| `build.ts` | Bundles `src/index.html` into `dist/` and adds the fixed-address files. |

```sh
bun install
bun run dev        # a dev server with reload
bun run build      # dist/, ready for any static host
./deploy.sh        # build and publish to Vercel (project "mux")
```

Keep each claim true to the repository: `tasks/plan.md` is the source.
