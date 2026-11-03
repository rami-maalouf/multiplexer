import { expect, test } from 'bun:test';
import { searchFound, snippetOf, type SearchAnswer } from './search.ts';

const initials = (name: string): string => name.slice(0, 1).toUpperCase();
const hit = (over: Partial<SearchAnswer['messages'][number]>): SearchAnswer['messages'][number] => ({
  room: '!r', chatName: 'Ana', isDirect: true, network: 'whatsapp', avatar: 'app:/chat.jpg', event: '$e', senderName: 'Ana',
  isOwn: false, body: 'See you at the harbour', time: 1, kind: 'text', links: [], picture: '', seconds: 0, isVoice: false,
  fileName: '', fileSize: 0, senderPicture: 'app:/ana.jpg', ...over,
});
const answer = (messages: SearchAnswer['messages']): SearchAnswer => ({ chats: [], messages, links: [] });

test('across chats, a chat with one person names no sender', () => {
  const [m] = searchFound(answer([hit({})]), 'harbour', initials).messages;
  expect(m.sender).toBe('');
  expect(m.avatar).toBe('app:/chat.jpg');
});

test('in one chat, each row names its sender, with their picture', () => {
  const [other, own] = searchFound(answer([hit({}), hit({ event: '$f', isOwn: true, senderName: 'Rami' })]), 'harbour', initials, true).messages;
  expect(other.sender).toBe('Ana');
  expect(other.senderAvatar).toBe('app:/ana.jpg');
  expect(other.senderInitials).toBe('A');
  expect(own.sender).toBe('You');
});

test('a voice message keeps its length and says it is one', () => {
  const [m] = searchFound(answer([hit({ kind: 'audio', body: '', seconds: 3, isVoice: true })]), '', initials, true).messages;
  expect(m.isVoice).toBe(true);
  expect(m.seconds).toBe(3);
  expect(m.snippet.map((r) => r.text).join('')).toBe('Voice message');
});

test('the words searched for are marked where they start a word', () => {
  const runs = snippetOf('See you at the harbour', ['harb']);
  expect(runs.filter((r) => r.hit).map((r) => r.text)).toEqual(['harb']);
});
