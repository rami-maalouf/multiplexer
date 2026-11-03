// the search screen's data (search.contract): what modules/apple/Matrix.swift's search answers, as
// the screen's shapes, with the words searched for marked in each message's text.
import type { Result } from './app.contract.d.ts';

type Found = Result<'loadSearch'>;
// a chat, as the module's rooms answer it.
type Chat = {
  id: string; name: string; isDirect: boolean; lastMessage: string; lastSender: string; lastIsOwn: boolean; lastTime: number;
  unread: number; network: string; markedUnread: boolean; muted: boolean; mentions: number; avatar: string;
};
// a found message, with its chat's name, picture and network. kind: text, image, video, audio,
// file or other; links: the links in its text; seconds: a video's length.
type Hit = {
  room: string; chatName: string; isDirect: boolean; network: string; avatar: string; event: string; senderName: string;
  isOwn: boolean; body: string; time: number; kind: string; links: string[]; picture: string; seconds: number;
  fileName: string; fileSize: number;
};
export type SearchAnswer = { chats: Chat[]; messages: Hit[]; links: Hit[] };

// a text without case or accents, to find the words in it. ASCII goes the fast way: the data
// module has 100 ms a turn, and a Unicode fold of each character of 60 messages took 270 ms.
const fold = (text: string): string => text.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase();
const foldChar = (c: string): string => (c.charCodeAt(0) < 128 ? c.toLowerCase() : fold(c));
const isWordChar = (c: string | undefined): boolean => {
  if (c === undefined) return false;
  const n = c.charCodeAt(0);
  if (n < 128) return (n >= 48 && n <= 57) || (n >= 65 && n <= 90) || (n >= 97 && n <= 122);
  return /[\p{L}\p{N}]/u.test(c);
};
// the words the index knows a query by: its runs of letters and digits.
const wordsOf = (query: string): string[] => fold(query).split(/[^\p{L}\p{N}]+/u).filter((w) => w !== '');
// a message's text that has its first word found further in than CUT characters is cut to begin
// LEAD characters before it, so the word shows in the row's two lines; it keeps at most LONGEST.
const CUT = 56;
const LEAD = 28;
const LONGEST = 220;

/** A message's text as one paragraph, cut to begin a little before the first word found, as runs:
 * each place where a word searched for begins a word of the text is marked. */
export const snippetOf = (body: string, words: string[]): { id: string; text: string; hit: boolean }[] => {
  const chars = [...body.replace(/\s+/gu, ' ').trim().slice(0, 2000)];
  if (words.length === 0) return [{ id: '0', text: chars.slice(0, LONGEST).join(''), hit: false }];
  const longest = Math.max(...words.map((w) => w.length));
  const hit: boolean[] = new Array(chars.length).fill(false);
  for (let i = 0; i < chars.length; i++) {
    if (!isWordChar(chars[i]) || isWordChar(chars[i - 1])) continue;
    // the text from this word's start, folded as far as the longest word needs.
    let got = '';
    const ends: number[] = [];
    for (let j = i; j < chars.length && got.length < longest; j++) {
      got += foldChar(chars[j]);
      ends.push(got.length);
    }
    for (const w of words) {
      if (!got.startsWith(w)) continue;
      const count = ends.findIndex((e) => e >= w.length) + 1;
      for (let k = i; k < i + count; k++) hit[k] = true;
    }
  }
  const first = hit.indexOf(true);
  let start = 0;
  if (first > CUT) {
    // the cut starts at a word.
    start = first - LEAD;
    while (start < first && isWordChar(chars[start - 1])) start++;
  }
  const runs: { id: string; text: string; hit: boolean }[] = [];
  if (start > 0) runs.push({ id: '0', text: '…', hit: false });
  for (let i = start; i < Math.min(chars.length, start + LONGEST); i++) {
    const last = runs[runs.length - 1];
    if (last !== undefined && last.hit === hit[i]) last.text += chars[i];
    else runs.push({ id: String(runs.length), text: chars[i], hit: hit[i] });
  }
  return runs;
};

// what a found photo, video, voice note or file is called when it has no caption.
const kindText = (h: Hit): string =>
  h.kind === 'image' ? 'Photo' : h.kind === 'video' ? 'Video' : h.kind === 'audio' ? 'Voice message' : h.kind === 'file' ? h.fileName : 'Message';

/** The module's answer for `query` as the screen's shapes. A chat with one person names no sender. */
export const searchFound = (answer: SearchAnswer, query: string, initials: (name: string) => string): Omit<Found, 'owner' | 'query' | 'kind'> => {
  const words = wordsOf(query);
  const chat = (c: Chat): Found['chats'][number] => ({
    id: c.id, name: c.name, avatar: c.avatar, initials: initials(c.name), network: c.network, lastTime: c.lastTime,
    unread: c.unread, muted: c.muted, mentions: c.mentions, markedUnread: c.markedUnread,
    loud: (c.unread > 0 || c.markedUnread) && !c.muted,
    // the inbox's preview: yours says so, a group names who wrote it.
    preview: c.lastMessage === '' ? '' : c.lastIsOwn ? `You: ${c.lastMessage}`
      : c.isDirect || c.lastSender === c.name ? c.lastMessage : `${c.lastSender}: ${c.lastMessage}`,
  });
  const message = (h: Hit): Found['messages'][number] => ({
    id: `${h.room}/${h.event}`, room: h.room, event: h.event, chatName: h.chatName, avatar: h.avatar, initials: initials(h.chatName),
    network: h.network, time: h.time, kind: h.kind, picture: h.picture, seconds: h.seconds, fileName: h.fileName, fileSize: h.fileSize,
    sender: h.isOwn ? 'You' : h.isDirect || h.senderName === h.chatName ? '' : h.senderName,
    snippet: h.body !== '' ? snippetOf(h.body, words) : [{ id: '0', text: kindText(h), hit: false }],
    // the link with a word searched for, else its first.
    link: h.links.find((l) => words.some((w) => fold(l).includes(w))) ?? h.links[0] ?? '',
  });
  return { chats: answer.chats.map(chat), messages: answer.messages.map(message), links: answer.links.map(message) };
};
