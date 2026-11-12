// the page's own script: reveal the words, fly the title's plane, then load the 3d plane once the
// page has painted.
import { startTitleFlight } from "./title-flight.js";

const root = document.documentElement;
requestAnimationFrame(() => document.body.classList.add("ready"));
startTitleFlight();

// the bar turns to frosted glass once the page has moved
const bar = document.querySelector(".bar");
const onScroll = () => bar?.classList.toggle("scrolled", scrollY > 24);
addEventListener("scroll", onScroll, { passive: true });
onScroll();

// the route's line ends at its last dot (the stacked layout on a phone)
const route = document.querySelector(".route");
const lastDot = route?.querySelector("li:last-child .dot");
function measureRoute() {
  if (!route || !lastDot) return;
  const y = lastDot.getBoundingClientRect().top - route.getBoundingClientRect().top + lastDot.offsetHeight / 2;
  route.style.setProperty("--last-dot", `${y}px`);
}
new ResizeObserver(measureRoute).observe(route ?? document.body);

// sections fade in as they come into view
const seen = new IntersectionObserver(
  (entries) => {
    for (const e of entries) {
      if (!e.isIntersecting) continue;
      e.target.classList.add("seen");
      seen.unobserve(e.target);
    }
  },
  { rootMargin: "0px 0px -12% 0px" },
);
for (const el of document.querySelectorAll(".observe")) seen.observe(el);

// the 3d plane is the heaviest part, so it loads after the first paint and never blocks the words
const canvas = document.getElementById("plane");
const stage = canvas?.parentElement;

function webglAvailable() {
  try {
    const c = document.createElement("canvas");
    return !!(c.getContext("webgl2") || c.getContext("webgl"));
  } catch {
    return false;
  }
}

function start() {
  if (!canvas || !stage) return;
  if (!webglAvailable()) {
    stage.classList.add("no-gl");
    return;
  }
  import("./scene.js")
    .then(({ startScene }) => startScene(canvas))
    .then(() => canvas.classList.add("live"))
    .catch(() => stage.classList.add("no-gl"));
}

const idle = window.requestIdleCallback ?? ((fn) => setTimeout(fn, 120));
if (document.readyState === "complete") idle(start);
else addEventListener("load", () => idle(start), { once: true });

root.classList.add("js");
