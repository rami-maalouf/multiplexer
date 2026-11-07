// the hero's scene: mux's glass paper plane, made of the logo's three folded paths (two wings
// and the keel) meeting at one lime nose. it climbs: three streams of light run back from its
// tails, sparks shed off them, and shooting stars pass the other way. slow, quiet, and it stops
// when nobody can see it.

import {
  AdditiveBlending,
  BufferGeometry,
  CanvasTexture,
  CatmullRomCurve3,
  Color,
  DoubleSide,
  DynamicDrawUsage,
  EdgesGeometry,
  Float32BufferAttribute,
  Group,
  LineBasicMaterial,
  LineSegments,
  MathUtils,
  Matrix4,
  Mesh,
  PerspectiveCamera,
  Points,
  PointsMaterial,
  Scene,
  ShaderMaterial,
  SRGBColorSpace,
  Sprite,
  SpriteMaterial,
  TubeGeometry,
  Vector2,
  Vector3,
  WebGLRenderer,
} from "three";

// the logo's colours, sampled from the icon: each path deep at its tail and bright toward the
// nose, where they meet in lime
const TEAL_DEEP = new Color("#0497a8");
const TEAL = new Color("#16c4ca");
const RIBBON_DEEP = new Color("#2a6fd6");
const RIBBON = new Color("#4592ee");
const BLUE_DEEP = new Color("#0553b2");
const BLUE = new Color("#22a8fc");
const LIME = new Color("#d8f758");
// the streams and sparks: the same three, a little brighter so they read as light
const TURQUOISE = new Color("#2fe0d6");
const BLUE_LIGHT = new Color("#4aa8ff");

const V = (x, y, z) => new Vector3(x, y, z);

// the plane in its own space: the nose points along +x, the spine runs along y = 0.
const NOSE = V(1.95, 0, 0);
// each panel: its triangles (two tail corners each, the third corner is the nose), its colour
// at the tail and toward the nose
const PANELS = [
  // the upper wing: broad, teal, with a soft fold along its middle
  { tail: TEAL_DEEP, near: TEAL, tris: [[V(-1.55, 0.03, -0.06), V(-1.6, 0.07, -0.58)], [V(-1.6, 0.07, -0.58), V(-1.72, 0.2, -1.18)]] },
  // the keel: the narrow middle path, blue; its tail ends short
  { tail: RIBBON_DEEP, near: RIBBON, tris: [[V(-1.32, -0.03, 0), V(-1.22, -0.44, 0)]] },
  // the lower wing: broad, deep blue brightening to sky blue
  { tail: BLUE_DEEP, near: BLUE, tris: [[V(-1.55, 0.03, 0.06), V(-1.6, 0.07, 0.58)], [V(-1.6, 0.07, 0.58), V(-1.72, 0.2, 1.18)]] },
];
const TAILS = [V(-1.72, 0.2, -1.18), V(-1.22, -0.44, 0), V(-1.72, 0.2, 1.18)];

// each triangle nose-a-b becomes a lime tip and a body that runs from the panel's deep tail
// colour to its bright colour near the nose, as the icon's paths do.
function planeGeometry() {
  const pos = [];
  const col = [];
  // colours go in as display (srgb) values, so a blend across a panel looks as it does in the
  // icon; the shader turns them to linear light after the blend
  const push = (p, c) => {
    const d = c.clone().convertLinearToSRGB();
    pos.push(p.x, p.y, p.z);
    col.push(d.r, d.g, d.b);
  };
  for (const panel of PANELS) {
    for (const [a, b] of panel.tris) {
      const a2 = NOSE.clone().lerp(a, 0.09);
      const b2 = NOSE.clone().lerp(b, 0.09);
      const near = panel.near;
      push(NOSE, LIME), push(a2, near), push(b2, near);
      push(a2, near), push(a, panel.tail), push(b, panel.tail);
      push(a2, near), push(b, panel.tail), push(b2, near);
    }
  }
  const g = new BufferGeometry();
  g.setAttribute("position", new Float32BufferAttribute(pos, 3));
  g.setAttribute("color", new Float32BufferAttribute(col, 3));
  g.computeVertexNormals();
  return g;
}

// a soft round glow, drawn once
function glowTexture() {
  const c = document.createElement("canvas");
  c.width = c.height = 128;
  const x = c.getContext("2d");
  const g = x.createRadialGradient(64, 64, 0, 64, 64, 64);
  g.addColorStop(0, "rgba(255,255,255,1)");
  g.addColorStop(0.25, "rgba(255,255,255,0.45)");
  g.addColorStop(1, "rgba(255,255,255,0)");
  x.fillStyle = g;
  x.fillRect(0, 0, 128, 128);
  const t = new CanvasTexture(c);
  t.colorSpace = SRGBColorSpace;
  return t;
}

// a stream: a thin tube from a tail back into the distance; its light runs away from the plane
const streamVertex = /* glsl */ `
  varying vec2 vUv;
  void main() {
    vUv = uv;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  }
`;
const streamFragment = /* glsl */ `
  uniform float uTime;
  uniform float uReveal;
  uniform float uOffset;
  uniform vec3 uColor;
  varying vec2 vUv;
  void main() {
    float u = vUv.x;                                  // 0 far away, 1 at the plane
    float shown = smoothstep(1.0 - uReveal, 1.0 - uReveal + 0.08, u);
    float fade = smoothstep(0.25, 0.85, u);
    float pulse = pow(fract(u * 2.4 + uTime * 0.55 + uOffset), 16.0);
    float alpha = shown * fade * (0.22 + 1.6 * pulse);
    gl_FragColor = vec4(uColor * (0.9 + 1.4 * pulse), alpha);
  }
`;

function stream(points, color, offset) {
  const curve = new CatmullRomCurve3(points, false, "catmullrom", 0.35);
  const geometry = new TubeGeometry(curve, 220, 0.012, 6, false);
  const material = new ShaderMaterial({
    uniforms: {
      uTime: { value: 0 },
      uReveal: { value: 0 },
      uOffset: { value: offset },
      uColor: { value: color.clone() },
    },
    vertexShader: streamVertex,
    fragmentShader: streamFragment,
    transparent: true,
    depthWrite: false,
    blending: AdditiveBlending,
  });
  return new Mesh(geometry, material);
}

// sparks shed from the three tails and fall back behind the plane. every spark is computed in
// the shader from its seed and the time, so nothing is updated on the cpu.
const sparkVertex = /* glsl */ `
  attribute vec3 aStart;
  attribute vec3 aDrift;
  attribute vec3 aColor;
  attribute float aSeed;
  uniform float uTime;
  uniform float uRate;
  uniform float uReveal;
  uniform vec3 uBack;
  uniform float uPixel;
  varying vec3 vColor;
  varying float vAlpha;
  void main() {
    float age = fract(uTime * uRate + aSeed);
    vec3 p = aStart + uBack * (age * 4.0) + aDrift * age;
    vColor = aColor;
    vAlpha = pow(1.0 - age, 1.6) * smoothstep(0.0, 0.06, age) * uReveal;
    vec4 mv = modelViewMatrix * vec4(p, 1.0);
    gl_PointSize = uPixel * (1.0 - age * 0.6) * (6.0 / -mv.z);
    gl_Position = projectionMatrix * mv;
  }
`;
const sparkFragment = /* glsl */ `
  varying vec3 vColor;
  varying float vAlpha;
  void main() {
    float d = length(gl_PointCoord - 0.5);
    float core = smoothstep(0.5, 0.0, d);
    gl_FragColor = vec4(vColor * (1.0 + 1.5 * core), vAlpha * core);
  }
`;

function sparks(tails, colors, back, count) {
  const start = new Float32Array(count * 3);
  const drift = new Float32Array(count * 3);
  const color = new Float32Array(count * 3);
  const seed = new Float32Array(count);
  for (let i = 0; i < count; i++) {
    const k = i % tails.length;
    const t = tails[k];
    start.set([t.x + MathUtils.randFloatSpread(0.08), t.y + MathUtils.randFloatSpread(0.08), t.z + MathUtils.randFloatSpread(0.08)], i * 3);
    drift.set([MathUtils.randFloatSpread(0.5), MathUtils.randFloatSpread(0.5), MathUtils.randFloatSpread(0.5)], i * 3);
    const c = colors[k].clone().lerp(new Color(1, 1, 1), Math.random() * 0.35);
    color.set([c.r, c.g, c.b], i * 3);
    seed[i] = Math.random();
  }
  const g = new BufferGeometry();
  g.setAttribute("position", new Float32BufferAttribute(start, 3));
  g.setAttribute("aStart", new Float32BufferAttribute(start, 3));
  g.setAttribute("aDrift", new Float32BufferAttribute(drift, 3));
  g.setAttribute("aColor", new Float32BufferAttribute(color, 3));
  g.setAttribute("aSeed", new Float32BufferAttribute(seed, 1));
  const m = new ShaderMaterial({
    uniforms: {
      uTime: { value: 0 },
      uRate: { value: 0.42 },
      uReveal: { value: 0 },
      uBack: { value: back.clone() },
      uPixel: { value: 7 },
    },
    vertexShader: sparkVertex,
    fragmentShader: sparkFragment,
    transparent: true,
    depthWrite: false,
    blending: AdditiveBlending,
  });
  const points = new Points(g, m);
  points.frustumCulled = false;
  return points;
}

// shooting stars: thin streaks far behind the plane, passing the other way, so it climbs
function shootingStars(count, back, side, up) {
  const pos = new Float32Array(count * 6);
  const col = new Float32Array(count * 8);
  const g = new BufferGeometry();
  g.setAttribute("position", new Float32BufferAttribute(pos, 3).setUsage(DynamicDrawUsage));
  g.setAttribute("color", new Float32BufferAttribute(col, 4).setUsage(DynamicDrawUsage));
  const lines = new LineSegments(
    g,
    new LineBasicMaterial({ vertexColors: true, transparent: true, depthWrite: false, blending: AdditiveBlending }),
  );
  lines.frustumCulled = false;
  const tints = [TURQUOISE, BLUE_LIGHT, new Color("#ffffff"), LIME];
  const stars = Array.from({ length: count }, () => ({ at: new Vector3(), life: 0, span: 1, speed: 1, len: 1, tint: tints[0] }));
  const head = new Vector3();
  const tail = new Vector3();
  function spawn(s, first) {
    // somewhere ahead and around the plane, and behind it in depth, so it streaks past
    s.at.set(0, 0, 0)
      .addScaledVector(side, MathUtils.randFloatSpread(10))
      .addScaledVector(up, MathUtils.randFloat(-2, 6))
      .addScaledVector(back, -MathUtils.randFloat(5, 10));
    s.at.z -= MathUtils.randFloat(2, 8);
    s.span = MathUtils.randFloat(0.9, 1.8);
    s.life = first ? -Math.random() * 4 : -Math.random() * 2.5;
    s.speed = MathUtils.randFloat(7, 12);
    s.len = MathUtils.randFloat(1.6, 3.2);
    s.tint = tints[(Math.random() * tints.length) | 0];
  }
  for (const s of stars) spawn(s, true);
  function update(dt) {
    stars.forEach((s, i) => {
      s.life += dt;
      if (s.life > s.span) spawn(s, false);
      const live = s.life > 0 ? s.life / s.span : 0;
      const a = s.life > 0 ? Math.sin(live * Math.PI) : 0;
      head.copy(s.at).addScaledVector(back, Math.max(s.life, 0) * s.speed);
      tail.copy(head).addScaledVector(back, -s.len);
      pos.set([head.x, head.y, head.z, tail.x, tail.y, tail.z], i * 6);
      col.set([s.tint.r, s.tint.g, s.tint.b, a, s.tint.r, s.tint.g, s.tint.b, 0], i * 8);
    });
    g.attributes.position.needsUpdate = true;
    g.attributes.color.needsUpdate = true;
  }
  return { lines, update };
}

function starfield(count) {
  const pos = new Float32Array(count * 3);
  for (let i = 0; i < count; i++) {
    pos[i * 3] = MathUtils.randFloatSpread(40);
    pos[i * 3 + 1] = MathUtils.randFloatSpread(24);
    pos[i * 3 + 2] = MathUtils.randFloat(-30, -4);
  }
  const g = new BufferGeometry();
  g.setAttribute("position", new Float32BufferAttribute(pos, 3));
  const m = new PointsMaterial({
    size: 0.05,
    color: new Color("#9fc4ff"),
    transparent: true,
    opacity: 0.55,
    depthWrite: false,
    sizeAttenuation: true,
  });
  return new Points(g, m);
}

const easeOut = (t) => 1 - Math.pow(1 - MathUtils.clamp(t, 0, 1), 3);

export async function startScene(canvas) {
  const still = matchMedia("(prefers-reduced-motion: reduce)").matches;

  const renderer = new WebGLRenderer({ canvas, antialias: true, alpha: true, powerPreference: "default" });
  const pixelRatio = Math.min(devicePixelRatio, 2);
  renderer.setPixelRatio(pixelRatio);
  renderer.outputColorSpace = SRGBColorSpace;
  renderer.setClearColor(0x000000, 0);

  const scene = new Scene();

  const camera = new PerspectiveCamera(30, 1, 0.1, 100);
  camera.position.set(0, 0.2, 9);


  const sky = starfield(still ? 220 : 420);
  scene.add(sky);

  // the plane and everything that travels with it
  const flight = new Group();
  const plane = new Group();
  flight.add(plane);
  scene.add(flight);

  const geometry = planeGeometry();
  // the glass, in the logo's own colours: each panel lit from within, brighter toward the nose,
  // with a thin rim of light where it turns away from us. no scene lighting can wash it out.
  const glass = new ShaderMaterial({
    vertexShader: /* glsl */ `
      attribute vec3 color;
      varying vec3 vColor;
      varying vec3 vNormal;
      varying vec3 vView;
      varying float vAlong;
      void main() {
        vColor = color;
        vAlong = position.x;
        vec4 mv = modelViewMatrix * vec4(position, 1.0);
        vNormal = normalize(normalMatrix * normal);
        vView = -mv.xyz;
        gl_Position = projectionMatrix * mv;
      }
    `,
    fragmentShader: /* glsl */ `
      varying vec3 vColor;
      varying vec3 vNormal;
      varying vec3 vView;
      varying float vAlong;
      void main() {
        vec3 n = normalize(vNormal);
        if (!gl_FrontFacing) n = -n;
        float facing = abs(dot(n, normalize(vView)));
        float rim = pow(1.0 - facing, 3.0);
        float lift = smoothstep(-1.8, 1.95, vAlong);
        vec3 base = pow(vColor, vec3(2.2));
        vec3 col = base * (0.9 + 0.25 * lift) + vec3(0.75, 1.0, 0.98) * rim * 0.1;
        gl_FragColor = vec4(col, 0.94);
        #include <colorspace_fragment>
      }
    `,
    transparent: true,
    side: DoubleSide,
  });
  plane.add(new Mesh(geometry, glass));

  // the glass's bright edges
  const edges = new LineSegments(
    new EdgesGeometry(geometry, 1),
    new LineBasicMaterial({ color: 0xbffcf6, transparent: true, opacity: 0.5, blending: AdditiveBlending, depthWrite: false }),
  );
  plane.add(edges);


  const glow = new Sprite(new SpriteMaterial({ map: glowTexture(), color: LIME, blending: AdditiveBlending, depthWrite: false, transparent: true, opacity: 0.85 }));
  glow.position.copy(NOSE);
  glow.scale.setScalar(0.6);
  plane.add(glow);

  const halo = new Sprite(new SpriteMaterial({ map: glowTexture(), color: BLUE, blending: AdditiveBlending, depthWrite: false, transparent: true, opacity: 0.12 }));
  halo.position.set(0, 0, -0.2);
  halo.scale.setScalar(5.5);
  plane.add(halo);

  // the pose that reads like the icon: nose up and to the right, toward us, wing tops in view
  const fwd = V(1, 0.62, 0.7).normalize();
  const side = fwd.clone().cross(V(-0.15, 1, 0.55).normalize()).normalize();
  const up = side.clone().cross(fwd).normalize();
  plane.quaternion.setFromRotationMatrix(new Matrix4().makeBasis(fwd, up, side));
  const back = fwd.clone().negate();

  // the tails in the flight's space, where the streams, sparks and shooting stars live
  const tails = TAILS.map((t) => t.clone().applyQuaternion(plane.quaternion));
  const colors = [TURQUOISE, BLUE_LIGHT, LIME];

  // three streams run back from the tails, apart in the distance
  const trail = (t, spreadSide, spreadUp, color, offset) => {
    const at = (d, k) => t.clone().addScaledVector(back, d).addScaledVector(side, spreadSide * k).addScaledVector(up, spreadUp * k);
    return stream([at(13, 1), at(7, 0.55), at(3, 0.18), at(0.9, 0.03), t], color, offset);
  };
  const streams = [
    trail(tails[0], -1.6, 0.9, colors[0], 0.0),
    trail(tails[1], 0.2, -1.5, colors[1], 0.37),
    trail(tails[2], 1.7, 0.4, colors[2], 0.71),
  ];
  for (const st of streams) flight.add(st);

  const shed = sparks(tails, colors, back, still ? 0 : 150);
  shed.material.uniforms.uPixel.value = 7 * pixelRatio;
  if (!still) flight.add(shed);

  const passing = shootingStars(still ? 0 : 12, back, side, up);
  if (!still) flight.add(passing.lines);

  // where the plane sits: to the right of the words on a wide screen, above them on a phone
  const home = new Vector3();
  let scale = 1;
  function layout() {
    const w = canvas.clientWidth || innerWidth;
    const h = canvas.clientHeight || innerHeight;
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    if (camera.aspect >= 1.05) {
      home.set(MathUtils.mapLinear(Math.min(camera.aspect, 2.2), 1.05, 2.2, 1.3, 2.35), 0.45, 0);
      scale = 0.78;
    } else {
      home.set(-0.1, 1.15, 0);
      scale = MathUtils.mapLinear(MathUtils.clamp(camera.aspect, 0.45, 1.05), 0.45, 1.05, 0.4, 0.72);
    }
  }
  layout();
  new ResizeObserver(() => {
    layout();
    if (still) render(9, 0);
  }).observe(canvas);

  // the pointer leans the plane a little
  const lean = new Vector2();
  const leanTo = new Vector2();
  addEventListener(
    "pointermove",
    (e) => leanTo.set((e.clientX / innerWidth) * 2 - 1, (e.clientY / innerHeight) * 2 - 1),
    { passive: true },
  );

  const startPos = V(-7, -2.6, -3);
  function render(t, dt) {
    const intro = still ? 1 : easeOut(t / 2.8);
    const reveal = still ? 1 : easeOut((t - 0.4) / 3.2);
    lean.lerp(leanTo, 0.035);

    flight.position.lerpVectors(startPos, home, intro);
    flight.position.y += Math.sin(t * 0.7) * 0.07;
    flight.scale.setScalar(scale * MathUtils.lerp(0.6, 1, intro));
    flight.rotation.set(
      Math.sin(t * 0.55) * 0.05 + lean.y * 0.1,
      lean.x * 0.16,
      Math.sin(t * 0.45) * 0.035 + (1 - intro) * 0.25,
    );

    for (const s of streams) {
      s.material.uniforms.uTime.value = t;
      s.material.uniforms.uReveal.value = reveal;
    }
    shed.material.uniforms.uTime.value = t;
    shed.material.uniforms.uReveal.value = reveal;
    if (!still) passing.update(dt);
    glow.material.opacity = 0.7 + Math.sin(t * 1.6) * 0.15;
    sky.rotation.y = t * 0.004;
    sky.position.x = -lean.x * 0.25;

    renderer.render(scene, camera);
  }

  if (still) {
    render(9, 0);
    return;
  }

  // run only while the hero can be seen and the tab is in front
  let visible = true;
  let running = false;
  let last = performance.now();
  let clock = 0;
  function frame(now) {
    if (!visible || document.hidden) {
      running = false;
      return;
    }
    const dt = Math.min((now - last) / 1000, 0.05);
    clock += dt;
    last = now;
    render(clock, dt);
    requestAnimationFrame(frame);
  }
  function run() {
    if (running) return;
    running = true;
    last = performance.now();
    requestAnimationFrame(frame);
  }
  new IntersectionObserver(([e]) => {
    visible = e.isIntersecting;
    if (visible) run();
  }).observe(canvas);
  document.addEventListener("visibilitychange", () => !document.hidden && run());

  render(0, 0);
  run();
}
