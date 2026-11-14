import { expect, mock, test } from 'bun:test';
import type { Answer } from './app.contract.d.ts';

mock.module('@exact/clipboard', () => ({ ClipboardItem: class {}, write: async () => {} }));
mock.module('@exact/notifications', () => ({
  clearAppBadge: async () => {}, closeNotification: async () => {}, notificationStatus: async () => ({}),
  setAppBadge: async () => {}, showNotification: async () => {},
}));
const { answer } = await import('./app.ts');
const room = '!room:example.org', owner = '@test1:example.org';
const resolveTarget = (tag: string, userId: string, available = true) => {
  const native = { available, call: () => ({ userId }) } as unknown as Parameters<Answer>[4];
  return answer('resolveNotification', [tag, room], {} as Parameters<Answer>[2], {} as Parameters<Answer>[3], native);
};

test('a tap resolves against the current account without needing the inbox', () => {
  expect(resolveTarget(`chat:${owner}:${room}`, owner)).toEqual({ owner, room });
});

test('old account and signed-out banners cannot open a chat', () => {
  expect(resolveTarget(`chat:${owner}:${room}`, '@test2:example.org')).toEqual({ owner: '@test2:example.org', room: '' });
  expect(resolveTarget(`chat:${owner}:${room}`, '')).toEqual({ owner: '', room: '' });
  expect(resolveTarget(`chat:${owner}:${room}`, owner, false)).toEqual({ owner: '', room: '' });
});

test('existing local reminder destinations keep working', () => {
  expect(resolveTarget(`reminder-${room}`, owner)).toEqual({ owner, room });
});
