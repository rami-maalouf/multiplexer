// the title's full stop is mux's plane. on load it flies one flight through the title:
// it winds up around the O, is thrown high from the O's left side and falls onto the l, presses
// down the l like a spring, snaps straight up, rolls over the top of an arc, and lands on the dot
// with a bounce. then it rests as the full stop, aims at the cursor, and a click launches it again.
// readers who ask for reduced motion see only the resting plane.

const ART = -26; // the plane in the art points 26 degrees above the horizontal
const REST = -26; // and rests that way, as the logo does
// wind-up, throw, press, hold, release straight up, the arc to the dot, the landing
const LEGS = [2.0, 1.8, 1.5, 0.45, 0.3, 1.6, 1.4];
const TOTAL = LEGS.reduce((a, b) => a + b, 0);
const LANDS_AT = LEGS.slice(0, 6).reduce((a, b) => a + b, 0);
const COLORS = ["#16c4ca", "#2f86ff", "#d8f758"];

const lerp = (a, b, t) => a + (b - a) * t;
const angleLerp = (a, b, t) => a + (((((b - a) % 360) + 540) % 360) - 180) * t;
const easeOutCubic = (u) => 1 - Math.pow(1 - u, 3);
const easeInOut = (u) => (u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2);

export function startTitleFlight() {
  const title = document.getElementById("hero-title");
  const box = title?.parentElement;
  const plane = box?.querySelector(".title-plane");
  if (!title || !box || !plane) return;
  const pick = (name) => title.querySelector(`[data-flight="${name}"]`);
  const marks = { o: pick("o"), l: pick("l"), lBase: pick("l-base"), slot: pick("slot"), slotBase: pick("slot-base") };
  const trail = title.querySelector(".trail");
  const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const ctx = document.createElement("canvas").getContext("2d");

  // where the letters are, in the box's space: glyph sizes from the font's own metrics, and
  // baselines from zero-height markers that sit on them
  let geo = null;
  let size = 24;
  function measure() {
    const cr = box.getBoundingClientRect();
    const cs = getComputedStyle(title);
    const fs = parseFloat(cs.fontSize);
    ctx.font = `300 ${fs}px Sora`;
    const mO = ctx.measureText("O");
    ctx.font = `600 ${fs}px Sora`;
    const mL = ctx.measureText("l");
    const o = marks.o.getBoundingClientRect();
    const l = marks.l.getBoundingClientRect();
    const lb = marks.lBase.getBoundingClientRect();
    const s = marks.slot.getBoundingClientRect();
    const sb = marks.slotBase.getBoundingClientRect();
    const oBase = lb.top - parseFloat(cs.lineHeight);
    size = fs * 0.4;
    geo = {
      o: { x: o.left - cr.left + o.width / 2, y: oBase - cr.top - mO.actualBoundingBoxAscent / 2, r: mO.actualBoundingBoxAscent / 2 },
      lx: l.left - cr.left + (mL.actualBoundingBoxRight - mL.actualBoundingBoxLeft) / 2 + mL.actualBoundingBoxLeft,
      lBottom: lb.top - cr.top,
      lTop: lb.top - cr.top - mL.actualBoundingBoxAscent,
      stop: { x: s.left - cr.left + s.width / 2, y: sb.top - cr.top - size * 0.32 },
    };
  }

  // the flight: each leg is a function of its own 0..1
  function path(t) {
    const { o: O, lx, lBottom, lTop, stop: S } = geo;
    const R = O.r * 1.02;
    const onRing = (a) => ({ x: O.x + Math.cos((a * Math.PI) / 180) * R, y: O.y + Math.sin((a * Math.PI) / 180) * R });
    const P = onRing(180); // the release: the O's left side, moving up
    const T = { x: lx, y: lTop - size * 0.3 }; // the top of the l
    const B = { x: lx, y: lBottom - size * 0.45 }; // the bottom of the l, the spring fully pressed
    const U = { x: lx, y: lTop - size * 3.4 }; // where the straight climb ends
    // a throw: x steady, y a parabola from P over a high top down to T, as under gravity
    const A = P.y - size * 5.5;
    const r = Math.sqrt((P.y - A) / (T.y - A));
    const uv = r / (1 + r);
    const k = (P.y - A) / (uv * uv);
    // the arc after the release, and the share of the climb run at the arc's starting speed,
    // so the climb hands its speed to the arc without a pause
    const top2 = U.y - size * 4.2;
    const r2 = Math.sqrt((U.y - top2) / (S.y - top2));
    const v2 = r2 / (1 + r2);
    const k2 = (U.y - top2) / (v2 * v2);
    const hand = Math.min(1.9, Math.max(0, ((2 * k2 * v2) / LEGS[5]) * LEGS[4] / (B.y - U.y)));
    const legs = [
      // wind-up: one and a half turns, slow to fast; behind the O on its far half
      (u) => {
        const p = onRing(-360 + 540 * Math.pow(u, 2.3));
        return { p, behind: p.y < O.y };
      },
      // the throw, behind line one on the way down
      (u) => ({ p: { x: lerp(P.x, T.x, u), y: A + k * (u - uv) * (u - uv) }, behind: u > 0.55 && u < 0.93 }),
      // the spring presses: down the l, slower and slower
      (u) => ({ p: { x: T.x, y: lerp(T.y, B.y, easeOutCubic(u)) }, heading: 90, press: u }),
      // held at the bottom, trembling, turning to face up
      (u) => ({ p: { x: B.x + Math.sin(u * 60) * size * 0.04 * (1 - u), y: B.y }, heading: 90 + 180 * easeInOut(Math.min(1, u * 1.4)), press: 1 }),
      // released: snaps straight up the l
      (u) => ({ p: { x: T.x, y: B.y - (B.y - U.y) * (hand * u + (1 - hand) * (1 - (1 - u) * (1 - u))) }, heading: -90, release: u }),
      // the arc: leaves straight up, rolls over the top, drops onto the dot
      (u) => {
        const roll = u > 0.22 && u < 0.62 ? ((u - 0.22) / 0.4) * 360 : 0;
        return { p: { x: lerp(U.x, S.x, Math.pow(u, 1.6)), y: top2 + k2 * (u - v2) * (u - v2) }, behind: u > 0.06 && u < 0.96, roll };
      },
      // the landing: a damped spring, pressed into the dot, back up above it, smaller each time
      (u) => {
        const spring = Math.exp(-3.4 * u) * Math.sin(u * 19);
        return { p: { x: S.x, y: S.y + spring * size * 0.75 }, landing: u, spring };
      },
    ];
    let acc = 0;
    for (let i = 0; i < legs.length; i++) {
      if (t <= acc + LEGS[i]) return { ...legs[i]((t - acc) / LEGS[i]), seg: i };
      acc += LEGS[i];
    }
    return { p: S, seg: legs.length };
  }

  function place(p, angle, opacity = 1, squash = 1, roll = 1) {
    plane.style.width = plane.style.height = `${size}px`;
    // along the flight line: squash shortens it, roll turns it over (its width passes through zero)
    plane.style.transform = `translate(${p.x - size / 2}px, ${p.y - size / 2}px) rotate(${angle}deg) scale(${squash}, ${(2 - squash) * roll}) rotate(${-ART}deg)`;
    plane.style.opacity = opacity;
  }

  function spark(x, y, dirDeg, only) {
    const el = document.createElement("i");
    el.className = "flight-spark";
    const color = only || COLORS[(Math.random() * 3) | 0];
    el.style.background = color;
    el.style.boxShadow = `0 0 6px ${color}`;
    el.style.left = `${x}px`;
    el.style.top = `${y}px`;
    box.appendChild(el);
    const d = ((dirDeg + (Math.random() * 50 - 25)) * Math.PI) / 180;
    const len = (10 + Math.random() * 24) * (size / 24);
    el.animate(
      [{ transform: "translate(0, 0)", opacity: 1 }, { transform: `translate(${Math.cos(d) * len}px, ${Math.sin(d) * len}px)`, opacity: 0 }],
      { duration: 450 + Math.random() * 400, easing: "cubic-bezier(.22, 1, .36, 1)" },
    ).onfinish = () => el.remove();
  }

  function ripple(x, y) {
    const el = document.createElement("i");
    el.className = "flight-ripple";
    el.style.left = `${x}px`;
    el.style.top = `${y}px`;
    el.style.width = `${size * 1.2}px`;
    el.style.height = `${size * 0.5}px`;
    box.appendChild(el);
    el.animate(
      [{ transform: "translate(-50%, -50%) scale(.2)", opacity: 0.9 }, { transform: "translate(-50%, -50%) scale(2.6)", opacity: 0 }],
      { duration: 900, easing: "cubic-bezier(.22, 1, .36, 1)" },
    ).onfinish = () => el.remove();
  }

  // state: flying, resting, or launching off after a click
  let mode = still ? "rest" : "fly";
  let t = still ? TOTAL : 0;
  let heading = REST;
  let launch = 0;
  let mouse = null;
  let prev = null;
  let landed = false;
  let burst = false;
  let arrival = null;
  let running = false;
  let last = 0;
  let measuring = 0; // seconds left in which the title may still move (its entrance)

  function restart() {
    t = 0;
    mode = "fly";
    prev = null;
    landed = burst = false;
    arrival = null;
    heading = REST;
    trail.style.clipPath = "inset(0 0 100% 0)";
    plane.style.opacity = 1;
    // the 3d plane in the hero times its arrival to this landing
    window.__muxTitleLandsAt = performance.now() + LANDS_AT * 1000;
    wake();
  }

  function frame(now) {
    const dt = Math.min((now - last) / 1000, 0.05);
    last = now;
    if (measuring > 0) {
      measuring -= dt;
      measure();
    }
    if (mode === "fly") {
      t = Math.min(t + dt, TOTAL);
      const f = path(t);
      plane.style.zIndex = f.behind ? 1 : 3;
      const ahead = path(Math.min(t + 0.03, TOTAL)).p;
      const speed = Math.hypot(ahead.x - f.p.x, ahead.y - f.p.y) / 0.03;
      const dir = speed > 8 ? (Math.atan2(ahead.y - f.p.y, ahead.x - f.p.x) * 180) / Math.PI : heading;
      if (f.heading !== undefined) heading = f.heading;
      else if (f.landing !== undefined) {
        // rock from the angle it struck at down to rest, as a dart does
        if (arrival === null) arrival = Math.max(-45, Math.min(45, angleLerp(REST, heading, 1) - REST));
        heading = REST + arrival * Math.exp(-5 * f.landing) * Math.cos(f.landing * 16);
      } else heading = prev === null ? dir : angleLerp(heading, dir, 0.35);
      // the l fills with teal from its top as the spring presses, and stays lit
      if (f.press !== undefined && f.seg === 2) trail.style.clipPath = `inset(0 0 ${(1 - f.press) * 100}% 0)`;
      if (f.seg >= 3) trail.style.clipPath = "inset(0 0 0 0)";
      const squash =
        f.seg === 2 ? 1 - 0.12 * f.press
        : f.seg === 3 ? 0.88
        : f.seg === 4 ? 0.88 + 0.12 * f.release
        : f.seg === 6 ? 1 + 0.32 * f.spring
        : 1;
      place(f.p, heading, 1, squash, f.roll ? Math.cos((f.roll * Math.PI) / 180) : 1);
      if (f.seg === 4 && !burst) {
        burst = true;
        for (let i = 0; i < 16; i++) spark(f.p.x, f.p.y, 90 + (Math.random() * 120 - 60));
      }
      if (f.seg === 6 && !landed) {
        landed = true;
        ripple(geo.stop.x, geo.stop.y + size * 0.3);
        for (let i = 0; i < 12; i++) spark(f.p.x, f.p.y, 180 + (Math.random() * 160 - 80), COLORS[2]);
      }
      // sparks follow the plane's speed
      if (prev && t < TOTAL && Math.random() < Math.min(0.9, speed / 700)) spark(f.p.x, f.p.y, heading + 180);
      prev = f.p;
      if (t >= TOTAL) mode = "rest";
    } else if (mode === "rest") {
      plane.style.zIndex = 3;
      const S = geo.stop;
      const aim = mouse ? (Math.atan2(mouse.y - S.y, mouse.x - S.x) * 180) / Math.PI : REST;
      heading = angleLerp(heading, aim, 0.14);
      place(S, heading);
      // at rest, stop the loop once the plane has turned to where it aims
      if (Math.abs(angleLerp(heading, aim, 1) - heading) < 0.2 && measuring <= 0) {
        running = false;
        return;
      }
    } else if (mode === "launch") {
      launch += dt;
      const S = geo.stop;
      const rad = (heading * Math.PI) / 180;
      const d = Math.pow(launch / 1.2, 2) * 800;
      const p = { x: S.x + Math.cos(rad) * d, y: S.y + Math.sin(rad) * d };
      place(p, heading, 1 - launch / 1.2);
      if (Math.random() < 0.5) spark(p.x, p.y, heading + 180);
      if (launch >= 1.2) restart();
    }
    requestAnimationFrame(frame);
  }

  function wake() {
    if (running) return;
    running = true;
    last = performance.now();
    requestAnimationFrame(frame);
  }

  const hero = box.closest(".hero") ?? box;
  hero.addEventListener(
    "pointermove",
    (e) => {
      const r = box.getBoundingClientRect();
      mouse = { x: e.clientX - r.left, y: e.clientY - r.top };
      if (mode === "rest") wake();
    },
    { passive: true },
  );
  hero.addEventListener("pointerleave", () => {
    mouse = null;
    if (mode === "rest") wake();
  });
  title.addEventListener("click", () => {
    if (mode !== "rest" || still) return;
    mode = "launch";
    launch = 0;
    wake();
  });
  title.style.cursor = still ? "" : "pointer";
  new ResizeObserver(() => {
    measure();
    wake();
  }).observe(box);

  // tell the 3d plane when to arrive before it loads: the flight starts 0.6 s after the font
  if (!still) window.__muxTitleLandsAt = performance.now() + 600 + LANDS_AT * 1000;

  // start once the font is in, so the letters are where they will stay; keep measuring while
  // the title makes its entrance (it slides up as it fades in)
  const ready = document.fonts ? document.fonts.load(`600 1em Sora`).then(() => document.fonts.ready) : Promise.resolve();
  ready.then(() => {
    measure();
    measuring = 2.2;
    if (still) {
      trail.style.clipPath = "inset(0 0 0 0)";
      wake();
    } else setTimeout(restart, 600); // once the title has begun to fade in
  });
}
