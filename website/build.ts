// builds the site into dist/: bun bundles the page, its css, fonts and script (hashed names),
// splits the 3d scene into its own file, and we add what lives at fixed addresses.
import { rm, cp } from "node:fs/promises";

// files under src/public keep their names and paths (the fonts, preloaded by the page)

await rm("dist", { recursive: true, force: true });
const result = await Bun.build({
  entrypoints: ["./src/index.html"],
  outdir: "./dist",
  minify: true,
  splitting: true,
  sourcemap: "none",
  // the fonts and the title plane are copied from src/public with their names
  external: ["/fonts/*", "/img/*"],
});
if (!result.success) {
  for (const log of result.logs) console.error(log);
  process.exit(1);
}
await cp("./src/public", "./dist", { recursive: true });
await cp("./src/img/mux-share.jpg", "./dist/share.jpg");

// preload the two text faces, which bun would otherwise try to bundle from the html
const preload = ["sora-latin-wght-normal", "geist-latin-wght-normal"]
  .map((f) => `<link rel="preload" href="/fonts/${f}.woff2" as="font" type="font/woff2" crossorigin>`)
  .join("");
const page = await Bun.file("./dist/index.html").text();
await Bun.write("./dist/index.html", page.replace("<head>", `<head>${preload}`));
await cp("./src/vercel.json", "./dist/vercel.json");
for (const o of result.outputs) console.log(`${(o.size / 1024).toFixed(1).padStart(7)} KB  ${o.path.replace(process.cwd() + "/", "")}`);
