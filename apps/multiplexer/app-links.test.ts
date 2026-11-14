import { expect, test } from 'bun:test';
import { appLinkSources as sources } from './app-links';

test('a link asks the native module whether an installed app takes it', async () => {
  const requests: unknown[] = [];
  const native = { available: true, later: async (r: unknown) => { requests.push(r); return { url: 'https://maps.app.goo.gl/x', opened: true }; } };
  const result = await sources.openInApp(['https://maps.app.goo.gl/x'], {} as never, {} as never, native as never);
  expect(requests).toEqual([{ op: 'openInApp', url: 'https://maps.app.goo.gl/x' }]);
  expect(result).toEqual({ url: 'https://maps.app.goo.gl/x', opened: true });
});

test('without the native module, or when it fails, the link stays in the app', async () => {
  expect(await sources.openInApp(['https://example.com/'], {} as never, {} as never, undefined as never))
    .toEqual({ url: 'https://example.com/', opened: false });
  const failing = { available: true, later: async () => { throw new Error('gone'); } };
  expect(await sources.openInApp(['https://example.com/'], {} as never, {} as never, failing as never))
    .toEqual({ url: 'https://example.com/', opened: false });
});
