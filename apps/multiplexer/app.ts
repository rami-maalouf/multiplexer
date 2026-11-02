import type { Answer, Result, Sources, Storage } from './app.contract.d.ts';

// app.json’s app.id: change the two together.
export const appId = 'com.ramimaalouf.multiplexer';
// picked photos and files are read from the picker's copies; a photo is made smaller beside them
// before it goes; a file message's file is shared from where the module downloaded it.
export const grants = ['fs.read app:/tmp/picked', 'fs.read app:/tmp/upload', 'fs.write app:/tmp/upload',
  'fs.read app:/cache/matrix-files'].join('\n');

// what modules/apple/Matrix.swift answers. a refused sign-in names its problem;
// this module says it to the person.
type SignInAnswer = { ok: boolean; problem: string; detail: string };
// every chat (listed: the list shows it under the filter and the network), the network's pinned
// chats' ids in pin order, and the filter sheet's networks and unread chats.
// markedUnread: marked unread by hand. oneToOne: a chat with one other person.
type RoomsAnswer = {
  rooms: (Omit<Result<'loadRoomsByRecency'>['rooms'][number], 'initials'> & { markedUnread: boolean; oneToOne: boolean })[];
  pinned: string[];
  networks: Result<'loadRoomsByRecency'>['networks'];
  unread: number;
};

// a chat with no picture shows the first letters of its first two words, as Messages does.
const initials = (name: string): string =>
  name.split(/\s+/).filter((w) => /^[\p{L}\p{N}]/u.test(w)).slice(0, 2).map((w) => [...w][0].toUpperCase()).join('')
  || [...name.trim()][0] || '';
// a pinned person shows by their first name, as Messages does; a group by its whole name.
const shortName = (name: string, oneToOne: boolean): string =>
  (oneToOne ? name.trim().split(/\s+/)[0] : '') || name;
type MessagesAnswer = {
  atStart: boolean;
  messages: {
    id: string; sender: string; senderName: string; body: string; time: number; isOwn: boolean; state: string;
    isImage: boolean; image: string; imageWidth: number; imageHeight: number; waitingForKey: boolean;
    isEdited: boolean; senderPicture: string;
    // empty when the message answers none.
    reply: { senderName?: string; body?: string; isOwn?: boolean };
    // empty when the message is no file message.
    file: { name?: string; size?: number; mimetype?: string };
    // -1 when nothing uploads.
    progress: number;
    reactions: { key: string; count: number; isMine: boolean }[];
  }[];
};

const problems: Record<string, (server: string) => string> = {
  'wrong-password': () => 'The user name or password is wrong.',
  'server-not-found': (server) => `No Matrix server answered at ${server}. Check the server name.`,
  'server-not-supported': (server) => `${server} does not support sliding sync, which Multiplexer needs.`,
  'rate-limited': () => 'The server got too many sign-in attempts. Wait a minute, then try again.',
};

// a chat shows the time above a message that comes more than an hour after the one before it.
const GROUP_GAP_MS = 60 * 60 * 1000;
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

type Picked = { path: string; name: string; type: string; size: number; width: number | null; height: number | null };
// each photo gets its own folder, so it keeps its name ("IMG_0001.jpg") for the others.
let uploads = 0;
// each picked photo's preparation, started when it is picked, so Send finds it done.
const preparing = new Map<string, ReturnType<typeof prepare>>();
const prepared = (f: Picked, photo: boolean, storage: Storage) => {
  const key = `${photo}:${f.size}:${f.path}`;
  if (!preparing.has(key)) preparing.set(key, prepare(f, photo, storage));
  const ready = preparing.get(key)!;
  // a failed one is tried again at the next ask.
  ready.catch(() => preparing.delete(key));
  return ready;
};

/** What the module sends for a picked photo or file. A photo becomes an upright JPEG with its
 * thumbnail; an animated GIF goes as it is, and so does a file. */
async function prepare(f: Picked, photo: boolean, storage: Storage) {
  // the picker's copy has a name of its own ("1-3.pdf"): the others see the one picked.
  if (!photo) return { path: f.path, name: f.name, mimetype: f.type || 'application/octet-stream', size: f.size, photo: false, width: 0, height: 0 };
  const asIs = { path: f.path, name: f.name, mimetype: f.type, size: f.size, photo: true, width: f.width ?? 0, height: f.height ?? 0 };
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
  currentSession: (_args, _store, _storage, native): Result<'currentSession'> => {
    if (!native?.available) return { userId: '' };
    return native.call({ op: 'session' }) as Result<'currentSession'>;
  },
  // matrixcore filters the list (filter: all, unread, unanswered, people or groups; network: one
  // network's chats, or "" for every network); with all, the pinned chats are not in it.
  loadRoomsByRecency: async ([userId, filter, network], _store, _storage, native): Promise<Result<'loadRoomsByRecency'>> => {
    if (userId === '' || !native?.available) return { owner: userId, filter, network, rooms: [], pinned: [], networks: [], unread: 0 };
    native.watch('rooms'); // Matrix.swift says when a room's last message or the list changes
    const answer = (await native.later({ op: 'rooms', filter, network })) as RoomsAnswer;
    const byId = new Map(answer.rooms.map((r) => [r.id, r]));
    return {
      owner: userId, filter, network, networks: answer.networks, unread: answer.unread,
      rooms: answer.rooms.map(({ markedUnread: _, oneToOne: __, ...r }) => ({ ...r, initials: initials(r.name) })),
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
  loadMessages: async ([roomId, isDirect, roomName], _store, _storage, native): Promise<Result<'loadMessages'>> => {
    if (roomId === '' || !native?.available) return { room: roomId, atStart: true, group: false, messages: [] };
    native.watch(`thread:${roomId}`);
    const answer = (await native.later({ op: 'messages', roomId, limit: MESSAGE_COUNT })) as MessagesAnswer;
    // a bridged one-to-one chat is often not marked direct, but it is named after the other person.
    const group = !isDirect && answer.messages.some((m) => !m.isOwn && m.senderName !== roomName);
    const messages = answer.messages.map((m, i) => {
      const before = answer.messages[i - 1];
      const after = answer.messages[i + 1];
      const startsGroup = before === undefined || m.time - before.time > GROUP_GAP_MS;
      // a run is one sender's messages in a row; its last bubble has the tail and the sender's picture.
      const endsRun = after === undefined || after.sender !== m.sender || after.time - m.time > GROUP_GAP_MS;
      // a group chat names the sender above the first message of each run.
      const showName = group && !m.isOwn && (startsGroup || before.sender !== m.sender);
      return {
        id: m.id, senderName: m.senderName, senderInitials: initials(m.senderName), senderPicture: m.senderPicture,
        body: m.body, time: m.time, isOwn: m.isOwn, state: m.state, startsGroup, endsRun, showName,
        isImage: m.isImage, image: m.image, imageWidth: m.imageWidth, imageHeight: m.imageHeight,
        waitingForKey: m.waitingForKey, isEdited: m.isEdited, reactions: m.reactions,
        // a reply shows who wrote what it answers once that message is loaded; until then, or if
        // it cannot load, no quote shows rather than an empty one.
        hasReply: (m.reply.body ?? '') !== '',
        replyName: m.reply.isOwn ? 'You' : (m.reply.senderName ?? ''),
        replyBody: m.reply.body ?? '',
        isFile: m.file.name !== undefined, fileName: m.file.name ?? '', fileSize: m.file.size ?? 0, progress: m.progress,
        photoWidth: m.imageWidth > 0 && m.imageHeight > 0
          ? Math.min(PHOTO_MAX_WIDTH, (PHOTO_MAX_HEIGHT * m.imageWidth) / m.imageHeight) : PHOTO_MAX_WIDTH,
      };
    });
    return { room: roomId, atStart: answer.atStart, group, messages };
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
  retryMessage: async ([roomId, messageId], _store, _storage, native): Promise<Result<'retryMessage'>> => {
    await native!.later({ op: 'retry', roomId, messageId });
    return { ok: true };
  },
  discardMessage: async ([roomId, messageId], _store, _storage, native): Promise<Result<'discardMessage'>> => {
    await native!.later({ op: 'discard', roomId, messageId });
    return { ok: true };
  },
  signOut: async (_args, _store, _storage, native): Promise<Result<'signOut'>> => {
    await native!.later({ op: 'signOut' });
    return { ok: true };
  },
};
export const answer: Answer = (source, args, store, storage, native) =>
  sources[source](args, store, storage, native);
