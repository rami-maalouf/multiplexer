// the hero's scene: mux's glass paper plane, made of the logo's three folded paths (two wings
// and the keel) meeting at one nose, with three streams of light flowing into it from far
// behind: many chats, one inbox. slow, quiet, and it stops when nobody can see it.

import {
  AdditiveBlending,
  BufferGeometry,
  CanvasTexture,
  CatmullRomCurve3,
  Color,
  DirectionalLight,
  DoubleSide,
  EdgesGeometry,
  Float32BufferAttribute,
  Group,
  LineBasicMaterial,
  LineSegments,
  Matrix4,
  MathUtils,
  MeshPhysicalMaterial,
  Mesh,
  PerspectiveCamera,
  PMREMGenerator,
  PointLight,
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
import { RoomEnvironment } from "three/examples/jsm/environments/RoomEnvironment.js";

const TURQUOISE = new Color("#57DED4");
const BLUE = new Color("#519AFF");
const DEEP_BLUE = new Color("#3d7ff0");
const LIME = new Color("#D4F46A");

const V = (x, y, z) => new Vector3(x, y, z);

// the plane in its own space: the nose points along +x, the spine runs along y = 0.
const NOSE = V(1.95, 0, 0);
const PANELS = [
  // the left wing: broad, with a soft fold along its middle; turquoise, as the logo's upper wing
  { color: TURQUOISE, tris: [[V(-1.55, 0.03, -0.06), V(-1.6, 0.07, -0.58)], [V(-1.6, 0.07, -0.58), V(-1.72, 0.2, -1.18)]] },
  // the keel: the narrow middle path, hanging below the spine; its tail ends short
  { color: BLUE, tris: [[V(-1.32, -0.03, 0), V(-1.22, -0.44, 0)]] },
  // the right wing: broad, blue
  { color: DEEP_BLUE, tris: [[V(-1.55, 0.03, 0.06), V(-1.6, 0.07, 0.58)], [V(-1.6, 0.07, 0.58), V(-1.72, 0.2, 1.18)]] },
];

// each triangle nose-a-b becomes a small lime tip and a coloured body, so only the very
// nose glows lime, as on the icon.
function planeGeometry() {
  const pos = [];
  const col = [];
  const push = (p, c) => {
    pos.push(p.x, p.y, p.z);
    col.push(c.r, c.g, c.b);
  };
  for (const panel of PANELS) {
    for (const [a, b] of panel.tris) {
      const a2 = NOSE.clone().lerp(a, 0.2);
      const b2 = NOSE.clone().lerp(b, 0.2);
      const mid = panel.color.clone().lerp(LIME, 0.35);
      push(NOSE, LIME), push(a2, mid), push(b2, mid);
      push(a2, mid), push(a, panel.color), push(b, panel.color);
      push(a2, mid), push(b, panel.color), push(b2, mid);
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

// a stream: a thin tube whose light runs toward the plane in slow pulses
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
    float fade = smoothstep(0.18, 0.7, u) * (1.0 - smoothstep(0.97, 1.0, u) * 0.6);
    float pulse = pow(fract(u * 2.2 - uTime * 0.22 + uOffset), 14.0);
    float alpha = shown * fade * (0.16 + 1.35 * pulse);
    gl_FragColor = vec4(uColor * (0.7 + 1.6 * pulse), alpha);
  }
`;

function stream(points, color, offset) {
  const curve = new CatmullRomCurve3(points, false, "catmullrom", 0.35);
  const geometry = new TubeGeometry(curve, 220, 0.011, 6, false);
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

function stars(count) {
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
  renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
  renderer.outputColorSpace = SRGBColorSpace;
  renderer.setClearColor(0x000000, 0);

  const scene = new Scene();
  const pmrem = new PMREMGenerator(renderer);
  scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
  pmrem.dispose();

  const camera = new PerspectiveCamera(30, 1, 0.1, 100);
  camera.position.set(0, 0.2, 9);

  // light: a cool key from above, a blue rim from behind, a lime spark at the nose
  const key = new DirectionalLight(0xffffff, 1.1);
  key.position.set(2, 5, 6);
  const rim = new DirectionalLight(BLUE, 2.2);
  rim.position.set(-4, 1, -5);
  scene.add(key, rim);

  const sky = stars(still ? 220 : 420);
  scene.add(sky);

  // the plane and everything that travels with it
  const flight = new Group();
  const plane = new Group();
  flight.add(plane);
  scene.add(flight);

  const geometry = planeGeometry();
  const glass = new MeshPhysicalMaterial({
    vertexColors: true,
    color: 0xffffff,
    metalness: 0.05,
    roughness: 0.12,
    transmission: 0.25,
    thickness: 0.35,
    ior: 1.45,
    clearcoat: 1,
    clearcoatRoughness: 0.08,
    iridescence: 0.35,
    iridescenceIOR: 1.3,
    emissive: new Color("#0b2a52"),
    emissiveIntensity: 0.9,
    envMapIntensity: 1.4,
    transparent: true,
    opacity: 0.94,
    side: DoubleSide,
  });
  plane.add(new Mesh(geometry, glass));

  // the glass's bright edges
  const edges = new LineSegments(
    new EdgesGeometry(geometry, 1),
    new LineBasicMaterial({ color: 0xd9fbf7, transparent: true, opacity: 0.42, blending: AdditiveBlending, depthWrite: false }),
  );
  plane.add(edges);

  const spark = new PointLight(LIME, 3, 3, 2);
  spark.position.copy(NOSE).add(V(0.15, 0.05, 0));
  plane.add(spark);

  const glow = new Sprite(new SpriteMaterial({ map: glowTexture(), color: LIME, blending: AdditiveBlending, depthWrite: false, transparent: true, opacity: 0.85 }));
  glow.position.copy(NOSE);
  glow.scale.setScalar(0.55);
  plane.add(glow);

  const halo = new Sprite(new SpriteMaterial({ map: glowTexture(), color: BLUE, blending: AdditiveBlending, depthWrite: false, transparent: true, opacity: 0.18 }));
  halo.position.set(0, 0, -0.2);
  halo.scale.setScalar(5.5);
  plane.add(halo);

  // the pose that reads like the icon: nose up and to the right, toward us, wing tops in view
  const fwd = V(1, 0.62, 0.7).normalize();
  const side = fwd.clone().cross(V(-0.15, 1, 0.55).normalize()).normalize();
  const up = side.clone().cross(fwd).normalize();
  plane.quaternion.setFromRotationMatrix(new Matrix4().makeBasis(fwd, up, side));

  // three streams trail behind the plane, apart in the distance and converging into its three
  // tails: many chats, one inbox. they live in the flight's space, so they follow its drift.
  const back = fwd.clone().negate();
  const trail = (end, spreadSide, spreadUp, color, offset) => {
    const t = end.clone().applyQuaternion(plane.quaternion);
    const at = (d, k) => t.clone().addScaledVector(back, d).addScaledVector(side, spreadSide * k).addScaledVector(up, spreadUp * k);
    return stream([at(13, 1), at(7, 0.55), at(3, 0.18), at(0.9, 0.03), t], color, offset);
  };
  const streams = [
    trail(V(-1.72, 0.2, -1.18), -1.6, 0.9, TURQUOISE, 0.0),
    trail(V(-1.22, -0.44, 0), 0.2, -1.5, BLUE, 0.37),
    trail(V(-1.72, 0.2, 1.18), 1.7, 0.4, LIME, 0.71),
  ];
  for (const st of streams) flight.add(st);

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
    if (still) render(9);
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
  function render(t) {
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
    glow.material.opacity = 0.7 + Math.sin(t * 1.6) * 0.15;
    sky.rotation.y = t * 0.004;
    sky.position.x = -lean.x * 0.25;

    renderer.render(scene, camera);
  }

  if (still) {
    render(9);
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
    clock += Math.min((now - last) / 1000, 0.05);
    last = now;
    render(clock);
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

  render(0);
  run();
}
