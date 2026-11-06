import { expect, test } from 'bun:test';
import { appearance } from './appearance.ts';

// independently measure the palette's public color strings in linear srgb.
const luminance = (hex: string) => {
  const channels = hex.slice(1).match(/../g)!.map(c => parseInt(c, 16) / 255)
    .map(c => c > 0.04045 ? Math.pow((c + 0.055) / 1.055, 2.4) : c / 12.92);
  return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
};
const contrast = (a: string, b: string) => (Math.max(luminance(a), luminance(b)) + 0.05)
  / (Math.min(luminance(a), luminance(b)) + 0.05);
const sides = (css: string) => css.match(/#[0-9a-f]{6}/g)!;

test('chosen colors remain exact and their foregrounds stay readable', () => {
  const colors = ['#ffffff', '#000000', '#ffff00', '#007aff', '#ff00ff'];
  for (let r = 0; r < 256; r += 17) for (let g = 0; g < 256; g += 17) for (let b = 0; b < 256; b += 17) {
    colors.push(`#${[r, g, b].map(c => c.toString(16).padStart(2, '0')).join('')}`);
  }
  for (const color of colors) {
    const p = appearance(color);
    expect(p.fill).toBe(color);
    // own bubbles: 4.5:1 always; white on the accent or a shade of it at most 25% deeper (the same
    // hue), else black on the accent itself.
    expect(contrast(p.bubble, p.onFill)).toBeGreaterThanOrEqual(4.5);
    if (p.onFill === '#000000') expect(p.bubble).toBe(color);
    const [r, g, b] = [1, 3, 5].map(i => parseInt(color.slice(i, i + 2), 16));
    const [br, bg, bb] = [1, 3, 5].map(i => parseInt(p.bubble.slice(i, i + 2), 16));
    for (const [c, d] of [[r, br], [g, bg], [b, bb]]) {
      expect(d).toBeLessThanOrEqual(c);
      expect(d).toBeGreaterThanOrEqual(Math.floor(c * 0.75) - 1);
    }
    const [lightTint, darkTint] = sides(p.tint), [lightInk, darkInk] = sides(p.onTint);
    for (const [tint, ink, backgrounds] of [
      [lightTint, lightInk, ['#ffffff', '#f2f2f7', '#e9e9eb']],
      [darkTint, darkInk, ['#000000', '#1c1c1e', '#2c2c2e', '#262629']],
    ] as const) {
      expect(contrast(tint, ink)).toBeGreaterThanOrEqual(3);
      for (const bg of backgrounds) expect(contrast(tint, bg)).toBeGreaterThanOrEqual(4.5);
    }
  }
});

test('own text is white on the default blue and on dark colours, black on light ones', () => {
  expect(appearance('#007aff').onFill).toBe('#ffffff');
  expect(appearance('#007aff').fill).toBe('#007aff');
  expect(appearance('#007aff').bubble).not.toBe('#007aff');
  expect(appearance('#5b2a86').onFill).toBe('#ffffff');
  expect(appearance('#5b2a86').bubble).toBe('#5b2a86');
  expect(appearance('#ffcc00').onFill).toBe('#000000');
  expect(appearance('#7fd8be').onFill).toBe('#000000');
});

test('invalid persisted values recover to default blue and hex normalizes', () => {
  expect(appearance('invalid').fill).toBe('#007aff');
  expect(appearance('#ABCDEF').fill).toBe('#abcdef');
});
