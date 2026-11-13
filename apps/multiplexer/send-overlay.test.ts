import { expect, mock, test } from 'bun:test';
import type { Result, Write } from './app.contract.d.ts';

mock.module('@exact/clipboard', () => ({ ClipboardItem: class {}, write: async () => {} }));
mock.module('@exact/notifications', () => ({
  clearAppBadge: async () => {}, closeNotification: async () => {}, notificationStatus: async () => ({}),
  setAppBadge: async () => {}, showNotification: async () => {},
}));
const { overlay } = await import('./app.ts');
const args = ['room', true, 'Test room', 0, 'matrix', 'thread'] as const;
const empty: Result<'loadMessages'> = {
  room: 'room', atStart: true, group: false, firstUnread: '', settling: false, cached: false, messages: [],
};
const send = (token: string, body = 'Same text', room = 'room'): Write => ({
  id: Number(token.slice(-1)), mutation: 'sent', source: 'sendMessage',
  args: [room, body, '', token, '@test:example.org', 1000], answered: false, keep() {},
});
const project = (base: Result<'loadMessages'>, writes: Write[]) => overlay('loadMessages', [...args], base, writes) ?? base;

test('send makes room immediately and identical sends have separate row identities', () => {
  const thread = project(empty, [send('send-1'), send('send-2')]);
  expect(thread.messages.map(m => m.presentationId)).toEqual(['send-1', 'send-2']);
  expect(thread.messages.map(m => m.body)).toEqual(['Same text', 'Same text']);
  expect(thread.messages[0].endsRun).toBe(false);
  expect(thread.messages[0].status).toBe('');
  expect(thread.messages[1].startsGroup).toBe(false);
  expect(thread.messages[1].state).toBe('sending');
  expect(empty.messages).toEqual([]);
});

test('a native echo arriving before the send reply replaces only its matching presentation', () => {
  const writes = [send('send-1'), send('send-2')];
  const pending = project(empty, writes);
  const echo = { ...pending.messages[0], id: 'native-91', event: '$event', state: 'sent' };
  const thread = project({ ...empty, messages: [echo] }, writes);
  expect(thread.messages.map(m => m.id)).toEqual(['native-91', 'send-2']);
  expect(thread.messages.map(m => m.presentationId)).toEqual(['send-1', 'send-2']);
  expect(thread.messages[0].event).toBe('$event');
});

test('a successful enqueue remains visible until its echo is in the read answer', () => {
  const keep = mock(() => {});
  const queued = { ...send('send-1'), answered: true, reply: { ok: true, id: 'native-91', room: 'room' }, keep } as Write;
  const pending = project(empty, [queued]);
  expect(pending.messages).toHaveLength(1);
  expect(keep).toHaveBeenCalledTimes(1);
  const echo = { ...pending.messages[0], id: 'native-91' };
  expect(project({ ...empty, messages: [echo] }, [queued]).messages).toEqual([echo]);
  expect(keep).toHaveBeenCalledTimes(1);
});

test('a refused enqueue removes its placeholder and never alters another room', () => {
  const refused = { ...send('send-1'), answered: true } as Write;
  expect(project(empty, [refused]).messages).toEqual([]);
  expect(project(empty, [send('send-1', 'Same text', 'another-room')])).toBe(empty);
});
