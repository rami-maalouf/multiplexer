import { expect, test } from 'bun:test';
import { deleteUntil, editUntil, within } from './limits.ts';

const sent = Date.UTC(2026, 10, 3, 12, 0, 0);
const minute = 60 * 1000;

test('a WhatsApp message can be edited for 15 minutes', () => {
  const until = editUntil('whatsapp', sent);
  expect(within(until, sent)).toBe(true);
  expect(within(until, sent + 14 * minute + 59_000)).toBe(true);
  expect(within(until, sent + 15 * minute)).toBe(false);
  expect(within(until, sent + 60 * minute)).toBe(false);
});

test('a WhatsApp message can be deleted for everyone for 48 hours', () => {
  const until = deleteUntil('whatsapp', sent);
  expect(within(until, sent + 16 * minute)).toBe(true);
  expect(within(until, sent + 47 * 60 * minute)).toBe(true);
  expect(within(until, sent + 48 * 60 * minute)).toBe(false);
});

test('other networks keep no limit', () => {
  for (const network of ['matrix', 'instagram', 'telegram', 'signal', '']) {
    expect(editUntil(network, sent)).toBe(0);
    expect(deleteUntil(network, sent)).toBe(0);
    expect(within(editUntil(network, sent), sent + 365 * 24 * 60 * minute)).toBe(true);
  }
});
