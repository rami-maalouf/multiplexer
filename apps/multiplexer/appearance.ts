// the chosen fill stays exact. text tints adjust only lightness for the platform's surfaces.
const DEFAULT = '#007aff';
const rgb = (hex: string) => [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16));
const luminance = (hex: string) => rgb(hex).reduce((sum, c, i) => {
  const n = c / 255;
  return sum + [0.2126, 0.7152, 0.0722][i] * (n <= 0.04045 ? n / 12.92 : ((n + 0.055) / 1.055) ** 2.4);
}, 0);
const contrast = (a: string, b: string) => {
  const x = luminance(a), y = luminance(b);
  return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
};
const foreground = (fill: string) => contrast(fill, '#000000') >= contrast(fill, '#ffffff') ? '#000000' : '#ffffff';
const mix = (hex: string, end: number, fraction: number) => `#${rgb(hex).map(c =>
  Math.round(c + (end - c) * fraction).toString(16).padStart(2, '0')).join('')}`;
function tint(fill: string, dark: boolean) {
  // incoming links use this tint on the opaque bubble.incoming surface in app.tamber.
  const backgrounds = dark ? ['#000000', '#1c1c1e', '#2c2c2e', '#262629'] : ['#ffffff', '#f2f2f7', '#e9e9eb'];
  const readable = (color: string) => backgrounds.every(bg => contrast(color, bg) >= 4.5);
  if (readable(fill)) return fill;
  let lo = 0, hi = 1;
  for (let i = 0; i < 24; i++) {
    const mid = (lo + hi) / 2;
    if (readable(mix(fill, dark ? 255 : 0, mid))) hi = mid;
    else lo = mid;
  }
  return mix(fill, dark ? 255 : 0, hi);
}
export function appearance(chosen: string) {
  const fill = /^#[0-9a-f]{6}$/i.test(chosen) ? chosen.toLowerCase() : DEFAULT;
  const lightTint = tint(fill, false), darkTint = tint(fill, true);
  const lightInk = foreground(lightTint), darkInk = foreground(darkTint);
  return { fill, onFill: foreground(fill), tint: `light-dark(${lightTint}, ${darkTint})`,
    onTint: `light-dark(${lightInk}, ${darkInk})` };
}
