import type { Answer, Result, Sources, Storage } from './app.contract.d.ts';
import { ClipboardItem, write } from '@exact/clipboard';
import { closeNotification, notificationStatus, showNotification } from '@exact/notifications';
import { emojiRows } from './emoji-rows.ts';
import { searchFound, type SearchAnswer } from './search.ts';
import { infoSources } from './info.ts';
import { deleteUntil, editUntil } from './limits.ts';

// app.json’s app.id: change the two together.
export const appId = 'com.ramimaalouf.multiplexer';
// picked photos and files are read from the picker's copies; a photo is made smaller beside them
// before it goes; a file message's file is shared from where the module downloaded it. A voice
// message is recorded from the microphone into app:/tmp/voice.
export const grants = ['fs.read app:/tmp/picked', 'fs.read app:/tmp/camera', 'device.camera purpose.camera', 'fs.read app:/tmp/upload', 'fs.write app:/tmp/upload',
  'fs.read app:/cache/matrix-files', 'device.microphone purpose.microphone', 'fs.write app:/tmp/voice',
  'fs.read app:/cache/matrix-media', 'fs.read app:/tmp/copy', 'fs.write app:/tmp/copy',
  'device.speech-recognition purpose.recognition', 'fs.read app:/data/transcripts.json', 'fs.write app:/data/transcripts.json',
  'net.fetch https://api.klipy.com', 'net.fetch https://static.klipy.com', 'fs.write app:/tmp/gifs', 'fs.read app:/tmp/gifs',
  'device.notifications purpose.notifications', 'fs.read app:/data/reminders', 'fs.write app:/data/reminders'].join('\n');

// GIFs (gif.contract): the phone calls KLIPY itself, as KLIPY requires (D10). Its app key is set at
// build from the Keychain (scripts/setup-klipy-key.sh); it ships in the app, as an app key does.
const KLIPY_KEY: string = import.meta.env.KLIPY_KEY ?? '';
const KLIPY = 'https://api.klipy.com/api/v1';
const GIFS_PER_PAGE = 30;
// the GIF sent is KLIPY's largest under this: a GIF of several seconds can be 6 MB at its medium size.
const GIF_SEND_BYTES = 4_000_000;
type KlipyFile = { url: string; width: number; height: number; size: number };
type KlipyItem = { slug: string; title?: string; type: string; file: Record<string, Partial<Record<'gif' | 'webp' | 'mp4' | 'jpg', KlipyFile>>> };
// voice messages' transcripts, by account (transcribe-members.contract).
const TRANSCRIPTS = 'app:/data/transcripts.json';
type Transcript = { key: string; text: string; problem: string };
const readTranscripts = (storage: Storage): Promise<Record<string, Transcript[]>> => storage.fs.readFile(TRANSCRIPTS).then(
  (bytes) => JSON.parse(new TextDecoder().decode(bytes)) as Record<string, Transcript[]>,
  (e: { code?: string }) => { if (e?.code === 'ENOENT') return {}; throw e; });

// the GIFs the grid shows, by slug, so a tap sends the one it shows.
const shownGifs = new Map<string, KlipyItem>();

// what modules/apple/Matrix.swift answers. a refused sign-in names its problem;
// this module says it to the person.
type SignInAnswer = { ok: boolean; problem: string; detail: string };
// every chat (listed: the list shows it under the filter and the network), the network's pinned
// chats' ids in pin order, and the filter sheet's networks and each list's unread chats.
// oneToOne: a chat with one other person.
type RoomsAnswer = {
  rooms: (Omit<Result<'loadRoomsByRecency'>['rooms'][number], 'initials'> & { oneToOne: boolean })[];
  pinned: string[];
  networks: Result<'loadRoomsByRecency'>['networks'];
  unread: number;
  archiveUnread: number;
  lowPriorityUnread: number;
  reminders: number;
};

// Remind Me: a reminder lives in the account's data (MatrixCore's Reminders.swift), and its
// notification on this iPhone, tagged by the chat. What this iPhone scheduled is kept in a file, so
// a reminder answered or cleared on another device has its notification taken away here.
const REMINDERS = 'app:/data/reminders', SCHEDULED = `${REMINDERS}/scheduled.json`;
export const reminderTag = (roomId: string) => `reminder-${roomId}`;
type ReminderChat = { id: string; name: string; reminder: number; lastMessage: string; lastSender: string; lastIsOwn: boolean; merge: string };
let syncing: Promise<void> = Promise.resolve();
const syncReminders = (rooms: ReminderChat[], storage: Storage) => (syncing = syncing.then(() => syncNow(rooms, storage), () => syncNow(rooms, storage)));
async function syncNow(rooms: ReminderChat[], storage: Storage) {
  // a merged chat's reminder is the merged chat's: its rooms post none of their own.
  const wanted = new Map(rooms.filter((r) => r.reminder > 0 && (r.merge === '' || r.id.startsWith('merge:'))).map((r) => [r.id, r]));
  let scheduled: Record<string, number> = {};
  try { scheduled = JSON.parse(new TextDecoder().decode(await storage.fs.readFile(SCHEDULED))); } catch { /* none yet */ }
  let changed = false;
  for (const id of Object.keys(scheduled)) {
    if (wanted.has(id)) continue;
    await closeNotification({ tag: reminderTag(id) });
    delete scheduled[id];
    changed = true;
  }
  const missing = [...wanted.values()].filter((r) => scheduled[r.id] !== r.reminder);
  // a post asks for the permission while it is not given yet: here only when it is, as the
  // first reminder's press asks for it (app.contract's afterRemind).
  if (missing.length && (await notificationStatus({})).state === 'granted') {
    for (const r of missing) {
      await showNotification(reminderNotice(r));
      scheduled[r.id] = r.reminder;
      changed = true;
    }
  }
  if (!changed) return;
  await storage.fs.mkdir(REMINDERS).catch((e: { code?: string }) => { if (e?.code !== 'EEXIST') throw e; });
  await storage.fs.atomicWriteFile(SCHEDULED, new TextEncoder().encode(JSON.stringify(scheduled)));
}
const reminderNotice = (r: ReminderChat) => ({
  title: `Reply to ${r.name}`,
  body: r.lastMessage === '' ? 'You asked to be reminded.' : `${r.lastIsOwn ? 'You' : r.lastSender}: ${r.lastMessage}`,
  tag: reminderTag(r.id), data: r.id, showTrigger: r.reminder,
});

// a chat with no picture shows the first letters of its first two words, as Messages does.
const initials = (name: string): string =>
  name.split(/\s+/).filter((w) => /^[\p{L}\p{N}]/u.test(w)).slice(0, 2).map((w) => [...w][0].toUpperCase()).join('')
  || [...name.trim()][0] || '';
// a pinned person shows by their first name, as Messages does; a group by its whole name.
const shortName = (name: string, oneToOne: boolean): string =>
  (oneToOne ? name.trim().split(/\s+/)[0] : '') || name;
type MessagesAnswer = {
  atStart: boolean;
  // the first message after this account's read receipt, or "".
  firstUnread: string;
  messages: {
    // event: its event id once the server has it, else "".
    id: string; event: string; sender: string; senderName: string; body: string; time: number; isOwn: boolean; state: string;
    isImage: boolean; image: string; imageWidth: number; imageHeight: number; waitingForKey: boolean;
    isEdited: boolean; senderPicture: string;
    // deleted for everyone (body ""); your own text message, which an edit can change.
    isDeleted: boolean; isEditable: boolean;
    // empty when the message answers none.
    reply: { senderName?: string; body?: string; isOwn?: boolean };
    // empty when the message is no file message.
    file: { name?: string; size?: number; mimetype?: string };
    // -1 when nothing uploads.
    progress: number;
    reactions: { key: string; count: number; isMine: boolean }[];
    isSticker: boolean;
    // empty when the message is no video; duration in milliseconds.
    video: { width?: number; height?: number; duration?: number };
    // a video's poster once it is downloaded, else "".
    poster: string;
    // empty when the message is no voice message or audio file; duration in milliseconds, waveform from 0 to 1.
    audio: { isVoice?: boolean; duration?: number; waveform?: number[]; key?: string };
    // who has read the chat up to it, besides its sender and you; name "" until it is known, time 0 when unknown.
    readers: { name: string; time: number }[];
  }[];
};

const problems: Record<string, (server: string) => string> = {
  'wrong-password': () => 'The user name or password is wrong.',
  'server-not-found': (server) => `No Matrix server answered at ${server}. Check the server name.`,
  'server-not-supported': (server) => `${server} does not support sliding sync, which Multiplexer needs.`,
  'rate-limited': () => 'The server got too many sign-in attempts. Wait a minute, then try again.',
};

// a chat shows the day and time above a message that comes more than an hour after the one
// before it, or on another day.
const GROUP_GAP_MS = 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;
// a sticker fits a box this many rem wide and tall, as Beeper shows one.
const STICKER_SIDE = 9.5;
// a voice message's waveform shows as this many bars.
const VOICE_BARS = 32;
/** A waveform (each part from 0 to 1) as the bars a voice message shows, each its loudest part; a
 * flat line when it has none. Each bar's id is its place. */
const barsOf = (levels: number[]): { id: string; level: number }[] => Array.from({ length: VOICE_BARS }, (_, i) => {
  const from = Math.floor((i * levels.length) / VOICE_BARS);
  const level = levels.length === 0 ? 0
    : Math.max(...levels.slice(from, Math.max(from + 1, Math.floor(((i + 1) * levels.length) / VOICE_BARS))));
  return { id: String(i), level };
});
// a length in whole seconds, at least one for a sound of any length.
const secondsOf = (ms: number): number => (ms > 0 ? Math.max(1, Math.round(ms / 1000)) : 0);

// one to three emoji and nothing else (spaces aside): a flag, a keycap, or a pictograph drawn as
// an emoji (on its own, or asked for with U+FE0F, so "©" stays text) with its skin tone and joined parts.
const EMOJI = /\p{Regional_Indicator}\p{Regional_Indicator}|[#*0-9]\uFE0F?\u20E3|(?:\p{Emoji_Presentation}|\p{Extended_Pictographic}\uFE0F)\p{Emoji_Modifier}?(?:\u200D\p{Extended_Pictographic}\uFE0F?\p{Emoji_Modifier}?)*/gu;
const isBigEmoji = (body: string): boolean => {
  const text = body.replace(/\s+/g, '');
  if (text === '' || text.length > 48) return false;
  const found = text.match(EMOJI) ?? [];
  return found.length >= 1 && found.length <= 3 && found.join('') === text;
};

// a link starts with http:// or https:// or www.; punctuation at its end closes the sentence, and
// a bracket at its end closes one the link did not open.
const LINK = /\b(?:https?:\/\/|www\.)[^\s<>"]+/giu;
const count = (text: string, c: string): number => text.split(c).length - 1;
const linkEnd = (url: string): string => {
  let end = url;
  for (;;) {
    if (/[.,;:!?'"’”]$/u.test(end)) end = end.slice(0, -1);
    else if (end.endsWith(')') && count(end, ')') > count(end, '(')) end = end.slice(0, -1);
    else if (end.endsWith(']') && count(end, ']') > count(end, '[')) end = end.slice(0, -1);
    else return end;
  }
};
/** A message's text as runs: plain text, and links with the page each opens. */
const runsOf = (body: string): { id: string; text: string; href: string }[] => {
  const runs: { id: string; text: string; href: string }[] = [];
  let at = 0;
  for (const found of body.matchAll(LINK)) {
    const start = found.index ?? 0;
    if (start < at) continue;
    const url = linkEnd(found[0]);
    if (url.length < 5) continue;
    if (start > at) runs.push({ id: String(runs.length), text: body.slice(at, start), href: '' });
    runs.push({ id: String(runs.length), text: url, href: /^https?:/iu.test(url) ? url : `https://${url}` });
    at = start + url.length;
  }
  if (at < body.length || runs.length === 0) runs.push({ id: String(runs.length), text: body.slice(at), href: '' });
  return runs;
};

// "Ana", "Ana and Ben", "Ana, Ben and Cleo", "Ana, Ben and 3 others".
const namesText = (names: string[]): string =>
  names.length <= 1 ? (names[0] ?? '')
    : names.length <= 3 ? `${names.slice(0, -1).join(', ')} and ${names[names.length - 1]}`
      : `${names.slice(0, 2).join(', ')} and ${names.length - 2} others`;
/** What shows under the chat's newest message: yours says "Sent" (our server has it; its
 * network's delivery is not known) until someone reads it; then a direct chat says "Seen" (with
 * the time the view writes) and a group "Seen by" who. Under another person's, a group says who
 * else has seen it. */
const statusOf = (m: MessagesAnswer['messages'][number], group: boolean): { status: string; statusTime: number } => {
  const none = { status: '', statusTime: 0 };
  const named = m.readers.map((r) => r.name).filter((n) => n !== '');
  if (m.isOwn) {
    if (m.state !== 'sent') return none;
    if (m.readers.length === 0) return { status: 'Sent', statusTime: 0 };
    if (!group) return { status: 'Seen', statusTime: Math.max(...m.readers.map((r) => r.time)) };
  }
  if (!group || m.readers.length === 0) return none;
  return { status: named.length > 0 ? `Seen by ${namesText(named)}` : 'Seen', statusTime: 0 };
};
const MESSAGE_COUNT = 20;
// a photo in the chat fits a box this many rem wide and tall, as Messages keeps a tall one short.
const PHOTO_MAX_WIDTH = 15;
const PHOTO_MAX_HEIGHT = 18;
// a photo goes as a JPEG of at most this many pixels a side and bytes, with no metadata (no
// location), as Messages and WhatsApp send one; its thumbnail, for other clients' chats, smaller.
const PHOTO_SIDE = 4096;
const PHOTO_BYTES = 4_000_000;
const THUMBNAIL_SIDE = 800;
const THUMBNAIL_BYTES = 120_000;

// a photo or file chosen to send (attach.contract's Chosen): its size in pixels is 0 where it is not known.
type Chosen = { path: string; name: string; type: string; size: number; width: number; height: number };
// each photo gets its own folder, so it keeps its name ("IMG_0001.jpg") for the others.
let uploads = 0;
// each picked photo's preparation, started when it is picked, so Send finds it done.
const preparing = new Map<string, ReturnType<typeof prepare>>();
const prepared = (f: Chosen, photo: boolean, storage: Storage) => {
  const key = `${photo}:${f.size}:${f.path}`;
  if (!preparing.has(key)) preparing.set(key, prepare(f, photo, storage));
  const ready = preparing.get(key)!;
  // a failed one is tried again at the next ask.
  ready.catch(() => preparing.delete(key));
  return ready;
};

/** What the module sends for a picked photo or file. A photo becomes an upright JPEG with its
 * thumbnail; an animated GIF goes as it is, and so does a file. */
async function prepare(f: Chosen, photo: boolean, storage: Storage) {
  // the picker's copy has a name of its own ("1-3.pdf"): the others see the one picked.
  if (!photo) return { path: f.path, name: f.name, mimetype: f.type || 'application/octet-stream', size: f.size, photo: false, width: 0, height: 0 };
  const asIs = { path: f.path, name: f.name, mimetype: f.type, size: f.size, photo: true, width: f.width, height: f.height };
  if (f.type === 'image/gif') return asIs;
  const folder = `app:/tmp/upload/${++uploads}`;
  await storage.fs.mkdir(folder).catch((e: { code?: string }) => { if (e?.code !== 'EEXIST') throw e; });
  const base = f.name.replace(/\.[^.]*$/, '') || 'Photo';
  let full, small;
  try {
    full = await storage.fs.compressImage(f.path, `${folder}/${base}.jpg`, { maxDimension: PHOTO_SIDE, maxBytes: PHOTO_BYTES });
    small = await storage.fs.compressImage(f.path, `${folder}/thumbnail.jpg`, { maxDimension: THUMBNAIL_SIDE, maxBytes: THUMBNAIL_BYTES });
  } catch {
    // a picture this device cannot make smaller goes as it is.
    return asIs;
  }
  return {
    path: full.path, name: `${base}.jpg`, mimetype: full.type, size: full.size, photo: true, width: full.width, height: full.height,
    thumbnail: { path: small.path, mimetype: small.type, size: small.size, width: small.width, height: small.height },
  };
}

// the web has no Matrix SDK: it shows the sign-in screen and refuses to sign in.
const sources: Sources = {
  ...infoSources,
  currentSession: (_args, _store, _storage, native): Result<'currentSession'> => {
    if (!native?.available) return { userId: '' };
    return native.call({ op: 'session' }) as Result<'currentSession'>;
  },
  // matrixcore filters the list (list: inbox, archive or lowPriority; filter: all, unread,
  // unanswered, people or groups; network: one network's chats, or "" for every network); in the
  // inbox under all, the pinned chats are not in it.
  loadRoomsByRecency: async ([userId, filter, network, list], _store, storage, native): Promise<Result<'loadRoomsByRecency'>> => {
    if (userId === '' || !native?.available) {
      return { owner: userId, filter, network, list, rooms: [], pinned: [], networks: [], unread: 0, archiveUnread: 0, lowPriorityUnread: 0, reminders: 0 };
    }
    native.watch('rooms'); // Matrix.swift says when a room's last message or the list changes
    const answer = (await native.later({ op: 'rooms', filter, network, list })) as RoomsAnswer;
    const byId = new Map(answer.rooms.map((r) => [r.id, r]));
    // the reminders' notifications follow the account's reminders; a failure leaves the list as it is.
    syncReminders(answer.rooms, storage).catch((e) => console.log(`reminders: ${e}`));
    return {
      owner: userId, filter, network, list, networks: answer.networks, unread: answer.unread,
      archiveUnread: answer.archiveUnread, lowPriorityUnread: answer.lowPriorityUnread, reminders: answer.reminders,
      rooms: answer.rooms.map(({ oneToOne: _, ...r }) => ({ ...r, initials: initials(r.name) })),
      pinned: answer.pinned.flatMap((id) => {
        const r = byId.get(id);
        return r ? [{
          id, name: r.name, shortName: shortName(r.name, r.oneToOne), avatar: r.avatar, initials: initials(r.name),
          unread: r.unread > 0 || r.markedUnread,
        }] : [];
      }),
    };
  },
  // a pin is kept on the server, so the account's other devices show it too.
  setPinned: async ([roomId, pinned], _store, _storage, native): Promise<Result<'setPinned'>> => {
    await native!.later({ op: pinned ? 'pin' : 'unpin', roomId });
    return { ok: true };
  },
  // a chat's long-press actions: read, unread, mute, unmute, lowPriority, inbox (out of Low
  // Priority), archive, unarchive and delete (from this app only; the chat stays on its network).
  // Merge Chats: kept in the account's data (MatrixCore's Merges.swift); id is the merged chat's.
  mergeChats: async ([name, rooms, defaultRoom], _store, _storage, native): Promise<Result<'mergeChats'>> =>
    (await native!.later({ op: 'merge', name, rooms, defaultRoom })) as { ok: boolean; id: string },
  unmergeChat: async ([id], _store, _storage, native): Promise<Result<'unmergeChat'>> =>
    (await native!.later({ op: 'unmerge', id })) as { ok: boolean; id: string },
  // Remind Me (B7, B20): when is "tomorrow", "monday" or a picked time without a zone, as Send
  // Later's; a time not ahead is refused with problem "past".
  remindChat: async ([roomId, when], _store, _storage, native): Promise<Result<'remindChat'>> =>
    (await native!.later({ op: 'chat', roomId, action: 'remind', when })) as { ok: boolean; at: number; problem: string },
  changeChat: async ([roomId, action], _store, _storage, native): Promise<Result<'changeChat'>> => {
    await native!.later({ op: 'chat', roomId, action });
    return { ok: true };
  },
  // select chats: one of changechat's actions, or pin or unpin, on several chats; the list shows
  // each at once.
  changeChats: async ([roomIds, action], _store, _storage, native): Promise<Result<'changeChats'>> => {
    await native!.later({ op: 'chats', roomIds, action });
    return { ok: true };
  },
  // the search screen's results (search.ts): a kind's messages, the chats opened last (recent,
  // newest first) before any word, or chats by name, messages and links. Nothing while it is closed.
  // With room, the search in that chat (its info page's): its messages and links, or a kind's.
  loadSearch: async ([userId, searching, query, kind, recent, room], _store, _storage, native): Promise<Result<'loadSearch'>> => {
    const none = { owner: userId, room, query, kind, chats: [], messages: [], links: [] };
    // a chat's Bookmarks kind shows its saved messages (loadBookmarks), which no search finds.
    if (userId === '' || !searching || !native?.available || (room !== '' && query === '' && kind === '') || kind === 'bookmarks') return none;
    // a found photo's or sender's picture, once downloaded, and a chat's new file, link or voice
    // message on a kind's page; a chat's new photo or video (the info page's); the recent chats'
    // last messages as they change.
    native.watch('search');
    if (room !== '' && (kind === 'images' || kind === 'videos')) native.watch(`info:${room}`);
    if (room === '' && query === '' && kind === '') native.watch('rooms');
    const answer = (await native.later({ op: 'search', query, kind, recent, room })) as SearchAnswer;
    return { owner: userId, room, query, kind, ...searchFound(answer, query, initials, room !== '') };
  },
  // Send Later (send-later-members.contract): the open chat can have it once it is known not to be
  // end-to-end encrypted (a message that waits on the server cannot be).
  loadSendLater: async ([roomId], _store, _storage, native): Promise<Result<'loadSendLater'>> => {
    if (roomId === '' || !native?.available) return { room: roomId, can: false };
    return (await native.later({ op: 'canSendLater', roomId })) as { room: string; can: boolean };
  },
  // the messages waiting on the server, the soonest first; read again each minute (minute), as
  // they go at their time, and when one is made, moved, sent or cancelled.
  loadScheduled: async ([userId, _minute], _store, _storage, native): Promise<Result<'loadScheduled'>> => {
    if (userId === '' || !native?.available) return { owner: userId, messages: [] };
    native.watch('scheduled');
    const answer = (await native.later({ op: 'scheduled' })) as {
      messages: { id: string; room: string; chatName: string; network: string; avatar: string; body: string; at: number; isReply: boolean }[];
    };
    return { owner: userId, messages: answer.messages.map((m) => ({ ...m, initials: initials(m.chatName) })) };
  },
  // when: "tomorrow", "monday" or a picked time ("2026-11-04T09:30"), which the module reads in
  // the iPhone's zone. problem: "" when it waits, else why not (the module's words).
  sendLater: async ([roomId, text, replyTo, when], _store, _storage, native): Promise<Result<'sendLater'>> =>
    (await native!.later({ op: 'sendLater', roomId, text, replyTo, when })) as { id: string; at: number; problem: string },
  reschedule: async ([id, when], _store, _storage, native): Promise<Result<'reschedule'>> =>
    (await native!.later({ op: 'reschedule', id, when })) as { id: string; at: number; problem: string },
  // action: "send" (now) or "cancel".
  changeScheduled: async ([id, action], _store, _storage, native): Promise<Result<'changeScheduled'>> => {
    const answer = (await native!.later({ op: 'scheduledAction', id, action })) as { ok: boolean; problem?: string };
    return { ok: answer.ok, problem: answer.problem ?? '' };
  },
  // the saved messages, the last saved first, each with its chat; read again when the module says
  // they changed (saved or removed here, or on another device).
  loadBookmarks: async ([userId], _store, _storage, native): Promise<Result<'loadBookmarks'>> => {
    if (userId === '' || !native?.available) return { owner: userId, bookmarks: [] };
    native.watch('bookmarks');
    const answer = (await native.later({ op: 'bookmarks' })) as {
      bookmarks: Omit<Result<'loadBookmarks'>['bookmarks'][number], 'initials'>[];
    };
    return { owner: userId, bookmarks: answer.bookmarks.map((b) => ({ ...b, initials: initials(b.chatName) })) };
  },
  // a message of the open chat (its id there) saved, or a saved one (its event) removed.
  addBookmark: async ([roomId, messageId], _store, _storage, native): Promise<Result<'addBookmark'>> => {
    await native!.later({ op: 'bookmark', roomId, messageId });
    return { ok: true };
  },
  removeBookmark: async ([roomId, eventId], _store, _storage, native): Promise<Result<'removeBookmark'>> => {
    await native!.later({ op: 'removeBookmark', roomId, eventId });
    return { ok: true };
  },
  // a found message's chat pages back to it: its id there, or "" when it is further back.
  showMessage: async ([roomId, eventId], _store, _storage, native): Promise<Result<'showMessage'>> =>
    (await native!.later({ op: 'showMessage', roomId, eventId })) as { id: string },
  // the messages of a day go together in the reader's zone (utcOffset, in minutes); the chat's
  // network sets how long your own can be edited and deleted (limits.ts).
  loadMessages: async ([roomId, isDirect, roomName, utcOffset, network], _store, _storage, native): Promise<Result<'loadMessages'>> => {
    if (roomId === '' || !native?.available) return { room: roomId, atStart: true, group: false, firstUnread: '', messages: [] };
    native.watch(`thread:${roomId}`);
    const answer = (await native.later({ op: 'messages', roomId, limit: MESSAGE_COUNT })) as MessagesAnswer;
    // a bridged one-to-one chat is often not marked direct, but it is named after the other person.
    const group = !isDirect && answer.messages.some((m) => !m.isOwn && m.senderName !== roomName);
    const day = (t: number) => Math.floor((t + utcOffset * 60000) / DAY_MS);
    const messages = answer.messages.map((m, i) => {
      const before = answer.messages[i - 1];
      const after = answer.messages[i + 1];
      const startsGroup = before === undefined || m.time - before.time > GROUP_GAP_MS || day(m.time) !== day(before.time);
      // a run is one sender's messages in a row; its last bubble has the tail and the sender's picture.
      const endsRun = after === undefined || after.sender !== m.sender || after.time - m.time > GROUP_GAP_MS
        || day(after.time) !== day(m.time);
      // a group chat names the sender above the first message of each run.
      const showName = group && !m.isOwn && (startsGroup || before.sender !== m.sender);
      const isVideo = m.video.duration !== undefined;
      const isAudio = m.audio.duration !== undefined;
      // a video and a sticker show their picture where a photo shows its own.
      const [width, height] = isVideo ? [m.video.width ?? 0, m.video.height ?? 0] : [m.imageWidth, m.imageHeight];
      const side = m.isSticker ? STICKER_SIDE : PHOTO_MAX_WIDTH;
      const tall = m.isSticker ? STICKER_SIDE : PHOTO_MAX_HEIGHT;
      const media = m.isImage || m.file.name !== undefined || isVideo || m.isSticker || isAudio;
      const bigEmoji = !media && !m.waitingForKey && isBigEmoji(m.body);
      const status = i === answer.messages.length - 1 ? statusOf(m, group) : { status: '', statusTime: 0 };
      return {
        id: m.id, event: m.event, senderName: m.senderName, senderInitials: initials(m.senderName), senderPicture: m.senderPicture,
        body: m.body, time: m.time, isOwn: m.isOwn, state: m.state, startsGroup, endsRun, showName,
        isImage: m.isImage && !m.isSticker, image: isVideo ? m.poster : m.image, imageWidth: width, imageHeight: height,
        isVideo, seconds: isAudio ? secondsOf(m.audio.duration ?? 0) : Math.round((m.video.duration ?? 0) / 1000),
        isSticker: m.isSticker, bigEmoji, isAudio, bars: isAudio ? barsOf(m.audio.waveform ?? []) : [], audioKey: m.audio.key ?? '',
        balloon: !m.waitingForKey && !m.isDeleted && !bigEmoji && (!media || m.body !== ''), runs: runsOf(m.body), ...status,
        waitingForKey: m.waitingForKey, isEdited: m.isEdited, reactions: m.reactions,
        isDeleted: m.isDeleted, isEditable: m.isEditable,
        editUntil: editUntil(network, m.time), deleteUntil: deleteUntil(network, m.time),
        // a reply shows who wrote what it answers once that message is loaded; until then, or if
        // it cannot load, no quote shows rather than an empty one.
        hasReply: (m.reply.body ?? '') !== '',
        replyName: m.reply.isOwn ? 'You' : (m.reply.senderName ?? ''),
        replyBody: m.reply.body ?? '',
        isFile: m.file.name !== undefined, fileName: m.file.name ?? '', fileSize: m.file.size ?? 0, progress: m.progress,
        photoWidth: width > 0 && height > 0 ? Math.min(side, (tall * width) / height) : side,
      };
    });
    return { room: roomId, atStart: answer.atStart, group, firstUnread: answer.firstUnread, messages };
  },
  // the view asks when the reader has seen the chat's newest message; loading a chat reads nothing.
  markRead: async ([roomId], _store, _storage, native): Promise<Result<'markRead'>> => {
    await native!.later({ op: 'markRead', roomId });
    return { ok: true };
  },
  // a chat's draft from the account's store, so it outlives the app; the composer's photos and
  // files are not kept.
  loadDraft: async ([roomId], _store, _storage, native): Promise<Result<'loadDraft'>> => {
    const none = { room: roomId, text: '', replyTo: '', replyName: '', replyBody: '', attachments: [] };
    if (roomId === '' || !native?.available) return none;
    const answer = (await native.later({ op: 'draft', roomId })) as Omit<typeof none, 'attachments'>;
    return { ...answer, attachments: [] };
  },
  saveDraft: async ([roomId, text, replyTo], _store, _storage, native): Promise<Result<'saveDraft'>> => {
    await native!.later({ op: 'saveDraft', roomId, text, replyTo });
    return { ok: true };
  },
  loadOlderMessages: async ([roomId], _store, _storage, native): Promise<Result<'loadOlderMessages'>> => {
    await native!.later({ op: 'older', roomId });
    return { ok: true };
  },
  // a video message's video, downloaded once into the cache to play.
  loadVideo: async ([roomId, messageId], _store, _storage, native): Promise<Result<'loadVideo'>> => {
    if (messageId === '' || !native?.available) return { message: messageId, path: '' };
    const answer = (await native.later({ op: 'video', roomId, messageId })) as { path: string };
    return { message: messageId, path: answer.path };
  },
  // a voice message's sound, downloaded once into the cache to play.
  loadAudio: async ([roomId, messageId], _store, _storage, native): Promise<Result<'loadAudio'>> => {
    if (roomId === '' || messageId === '' || !native?.available) return { message: messageId, path: '' };
    const answer = (await native.later({ op: 'audio', roomId, messageId })) as { path: string };
    return { message: messageId, path: answer.path };
  },
  // a recording made ready to go as a voice message: Ogg Opus, its length, and its waveform (for
  // the others) and bars (for the draft).
  prepareVoice: async ([recording], _store, _storage, native): Promise<Result<'prepareVoice'>> => {
    const answer = (await native!.later({ op: 'prepareVoice', path: recording })) as
      { path: string; duration: number; size: number; waveform: number[] };
    return { recording, ...answer, seconds: secondsOf(answer.duration), bars: barsOf(answer.waveform) };
  },
  // the voice message shows in the chat at once, as a photo does; a failure shows on it.
  sendVoice: async ([roomId, path, duration, size, waveform, replyTo], _store, _storage, native): Promise<Result<'sendVoice'>> => {
    await native!.later({ op: 'sendVoice', roomId, path, duration, size, waveform, replyTo });
    return { ok: true };
  },
  loadPhoto: async ([roomId, messageId], _store, _storage, native): Promise<Result<'loadPhoto'>> => {
    if (messageId === '' || !native?.available) return { message: messageId, path: '' };
    const answer = (await native.later({ op: 'photo', roomId, messageId })) as { path: string };
    return { message: messageId, path: answer.path };
  },
  signIn: async ([server, user, password], _store, _storage, native): Promise<Result<'signIn'>> => {
    if (!native?.available) return { ok: false, error: 'This build has no Matrix SDK.' };
    const answer = (await native.later({ op: 'signIn', server, user, password })) as SignInAnswer;
    if (answer.ok) return { ok: true, error: '' };
    return { ok: false, error: problems[answer.problem]?.(server) ?? `Multiplexer could not sign in: ${answer.detail}` };
  },
  // a failure to send shows on the message itself (state "failed"), not as a refusal here.
  sendMessage: async ([roomId, text, replyTo], _store, _storage, native): Promise<Result<'sendMessage'>> => {
    await native!.later({ op: 'send', roomId, text, replyTo });
    return { ok: true };
  },
  // each photo or file goes in the chat's send queue in order and shows at once; the caption goes
  // with the last one, the reply with the first. A failure shows on the message, as for text.
  sendMedia: async ([roomId, items, caption, replyTo], _store, storage, native): Promise<Result<'sendMedia'>> => {
    for (const [i, item] of items.entries()) {
      const ready = await prepared(item.file, item.photo, storage);
      await native!.later({ op: 'sendMedia', roomId, ...ready,
        caption: i === items.length - 1 ? caption : '', replyTo: i === 0 ? replyTo : '' });
      preparing.delete(`${item.photo}:${item.file.size}:${item.file.path}`);
    }
    return { ok: true };
  },
  // picked photos are made ready at once: Send then puts them in the chat without a wait.
  stageMedia: async ([items], _store, storage): Promise<Result<'stageMedia'>> => {
    await Promise.all(items.map((item) => prepared(item.file, item.photo, storage)));
    return { ok: true };
  },
  // the largest file the server takes, in bytes; 0 while it is not known.
  // the module asks for the phone's push token and gives it to the server as a pusher; a drive
  // does that only for a test user. Without the permission, nothing.
  registerPush: async ([userId, permission], _store, _storage, native): Promise<Result<'registerPush'>> => {
    if (userId === '' || permission !== 'granted' || !native?.available) return { registered: false };
    return (await native.later({ op: 'registerPush' })) as { registered: boolean };
  },
  loadUploadLimit: async ([userId], _store, _storage, native): Promise<Result<'loadUploadLimit'>> => {
    if (userId === '' || !native?.available) return { bytes: 0 };
    return (await native.later({ op: 'maxUploadSize' })) as { bytes: number };
  },
  // a file message's file, downloaded once into the cache under its own name.
  openFile: async ([roomId, messageId], _store, _storage, native): Promise<Result<'openFile'>> => {
    const answer = (await native!.later({ op: 'file', roomId, messageId })) as { path: string; name: string };
    return { message: messageId, name: answer.name, path: answer.path };
  },
  // adds this account's reaction, or takes it back; the chat shows it when the timeline does.
  react: async ([roomId, messageId, key], _store, _storage, native): Promise<Result<'react'>> => {
    await native!.later({ op: 'react', roomId, messageId, key });
    return { ok: true };
  },
  // a held message's actions. an edit changes your own text message for everyone; a delete
  // deletes a message for everyone; a forward sends a copy to each chosen chat. Each shows in the
  // chats when their timelines do.
  editMessage: async ([roomId, messageId, text], _store, _storage, native): Promise<Result<'editMessage'>> => {
    await native!.later({ op: 'edit', roomId, messageId, text });
    return { ok: true };
  },
  deleteMessage: async ([roomId, messageId], _store, _storage, native): Promise<Result<'deleteMessage'>> => {
    await native!.later({ op: 'deleteMessage', roomId, messageId });
    return { ok: true };
  },
  forwardMessage: async ([roomId, messageId, to], _store, _storage, native): Promise<Result<'forwardMessage'>> => {
    await native!.later({ op: 'forward', roomId, messageId, to });
    return { ok: true };
  },
  // Settings' Encryption: the account's recovery (on, off, key: this iPhone needs the recovery
  // key), and the key entered to read older encrypted messages.
  loadRecovery: async ([userId], _store, _storage, native): Promise<Result<'loadRecovery'>> => {
    if (userId === '' || !native?.available) return { owner: userId, status: '' };
    const answer = (await native.later({ op: 'recovery' })) as { status: string };
    return { owner: userId, status: answer.status };
  },
  recover: async ([key], _store, _storage, native): Promise<Result<'recover'>> =>
    (await native!.later({ op: 'recover', key })) as { ok: boolean; problem: string },
  // voice messages' transcripts, kept in a file on this iPhone, by account and by the sound file's
  // name, newest first, at most 500 (transcribe-members.contract).
  loadTranscripts: async ([userId], _store, storage): Promise<Result<'loadTranscripts'>> =>
    userId === '' ? [] : ((await readTranscripts(storage))[userId] ?? []),
  saveTranscript: async ([userId, key, text, problem], _store, storage): Promise<Result<'saveTranscript'>> => {
    const all = await readTranscripts(storage);
    const mine = [{ key, text, problem }, ...(all[userId] ?? []).filter((t) => t.key !== key)].slice(0, 500);
    all[userId] = mine;
    await storage.fs.writeFile(TRANSCRIPTS, new TextEncoder().encode(JSON.stringify(all)));
    return mine;
  },
  // a held photo's Copy: its original (downloaded once), as a PNG on the clipboard, which takes
  // PNG only; a large photo is made smaller to fit the clipboard's 2 MB.
  copyPhoto: async ([roomId, messageId], _store, storage, native): Promise<Result<'copyPhoto'>> => {
    const photo = (await native!.later({ op: 'photo', roomId, messageId })) as { path: string };
    await storage.fs.mkdir('app:/tmp/copy').catch((e: { code?: string }) => { if (e?.code !== 'EEXIST') throw e; });
    const png = await storage.fs.compressImage(photo.path, 'app:/tmp/copy/photo.png', { maxDimension: 2048, maxBytes: 2_000_000, type: 'image/png' });
    await write([new ClipboardItem({ 'image/png': png.path })]);
    return { ok: true };
  },
  // trending GIFs before any word, else KLIPY's search, in KLIPY's order; nothing while the sheet is
  // closed. KLIPY's answer may hold other kinds (ads, when they are on): only GIFs show.
  loadGifs: async ([open, query]): Promise<Result<'loadGifs'>> => {
    if (!open) return { query, failed: false, items: [] };
    if (KLIPY_KEY === '') return { query, failed: true, items: [] };
    const words = query.trim();
    const url = words === ''
      ? `${KLIPY}/${KLIPY_KEY}/gifs/trending?page=1&per_page=${GIFS_PER_PAGE}`
      : `${KLIPY}/${KLIPY_KEY}/gifs/search?page=1&per_page=${GIFS_PER_PAGE}&q=${encodeURIComponent(words)}`;
    const response = await fetch(url).catch(() => null);
    if (response === null || !response.ok) return { query, failed: true, items: [] };
    const answer = (await response.json()) as { data?: { data?: KlipyItem[] } };
    const items = (answer.data?.data ?? []).filter((g) => g.type === 'gif');
    for (const g of items) shownGifs.set(g.slug, g);
    return {
      query, failed: false,
      items: items.flatMap((g) => {
        const preview = g.file.sm?.webp ?? g.file.sm?.gif ?? g.file.md?.webp;
        return preview ? [{ id: g.slug, title: g.title ?? '', preview: preview.url, width: preview.width, height: preview.height }] : [];
      }),
    };
  },
  // a tapped GIF: KLIPY's largest GIF under GIF_SEND_BYTES, downloaded straight to a file (a large
  // one copied through this module would pass its turn's budget), sent as an animated image through
  // the photos' path, answering replyTo; the bridge sends it to WhatsApp as a GIF. KLIPY is told
  // it was shared.
  sendGif: async ([roomId, slug, replyTo], _store, storage, native): Promise<Result<'sendGif'>> => {
    const g = shownGifs.get(slug);
    const sizes = (['hd', 'md', 'sm', 'xs'] as const).flatMap((s) => (g?.file[s]?.gif ? [g.file[s]!.gif!] : []));
    const file = sizes.find((f) => f.size > 0 && f.size <= GIF_SEND_BYTES) ?? sizes.at(-1);
    if (!g || !file) throw new Error(`no GIF ${slug} in the grid`);
    const name = `${slug}.gif`;
    await storage.fs.mkdir('app:/tmp/gifs').catch((e: { code?: string }) => { if (e?.code !== 'EEXIST') throw e; });
    const path = `app:/tmp/gifs/${name}`;
    const response = await fetch(file.url, { exactBodyTo: path });
    if (!response.ok) throw new Error(`KLIPY answered ${response.status} for ${slug}`);
    await native!.later({ op: 'sendMedia', roomId, path, name, mimetype: 'image/gif', size: file.size, photo: true,
      width: file.width, height: file.height, caption: '', replyTo });
    await fetch(`${KLIPY}/${KLIPY_KEY}/gifs/share/${encodeURIComponent(slug)}`, { method: 'POST' }).catch(() => null);
    return { ok: true };
  },
  // a photo's or file's original, downloaded once into the cache under its own name, to share.
  fetchMedia: async ([roomId, messageId], _store, _storage, native): Promise<Result<'fetchMedia'>> => {
    const answer = (await native!.later({ op: 'media', roomId, messageId })) as { path: string; name: string };
    return { message: messageId, name: answer.name, path: answer.path };
  },
  // the emojis the account reacts with most, for the reaction sheet's "Frequently used".
  loadFrequentEmojis: async ([userId], _store, _storage, native): Promise<Result<'loadFrequentEmojis'>> => {
    if (userId === '' || !native?.available) return { emojis: [] };
    return (await native.later({ op: 'emojis' })) as { emojis: string[] };
  },
  resetFrequentEmojis: async (_args, _store, _storage, native): Promise<Result<'resetFrequentEmojis'>> => {
    await native!.later({ op: 'resetEmojis' });
    return { ok: true };
  },
  // the reaction sheet's grid (emoji-rows.ts), while the sheet can open: empty otherwise.
  loadEmojiRows: async ([query, columns, frequent, wanted]): Promise<Result<'loadEmojiRows'>> =>
    (wanted ? emojiRows(query, columns, frequent) : []),
  retryMessage: async ([roomId, messageId], _store, _storage, native): Promise<Result<'retryMessage'>> => {
    await native!.later({ op: 'retry', roomId, messageId });
    return { ok: true };
  },
  discardMessage: async ([roomId, messageId], _store, _storage, native): Promise<Result<'discardMessage'>> => {
    await native!.later({ op: 'discard', roomId, messageId });
    return { ok: true };
  },
  // Settings' account: its name and picture (the picture once it is downloaded, "" until then).
  loadProfile: async ([userId], _store, _storage, native): Promise<Result<'loadProfile'>> => {
    if (userId === '' || !native?.available) return { userId, name: '', avatar: '', initials: '', version: '' };
    native.watch('profile');
    const p = (await native.later({ op: 'profile' })) as { userId: string; name: string; avatar: string; version: string };
    return { userId: p.userId, name: p.name, avatar: p.avatar, initials: initials(p.name), version: p.version };
  },
  signOut: async (_args, _store, _storage, native): Promise<Result<'signOut'>> => {
    await native!.later({ op: 'signOut' });
    return { ok: true };
  },
};
export const answer: Answer = (source, args, store, storage, native) =>
  sources[source](args, store, storage, native);
