import type { Answer, Result, Sources } from './app.contract.d.ts';

// app.json’s app.id: change the two together.
export const appId = 'com.ramimaalouf.multiplexer';
export const grants = '';

// what modules/apple/Matrix.swift answers. a refused sign-in names its problem;
// this module says it to the person.
type SignInAnswer = { ok: boolean; problem: string; detail: string };
// every chat (listed: the list shows it under the filter), and the pinned chats' ids in pin order.
// markedUnread: marked unread by hand. oneToOne: a chat with one other person.
type RoomsAnswer = {
  rooms: (Omit<Result<'loadRoomsByRecency'>['rooms'][number], 'initials'> & { markedUnread: boolean; oneToOne: boolean })[];
  pinned: string[];
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

// the web has no Matrix SDK: it shows the sign-in screen and refuses to sign in.
const sources: Sources = {
  currentSession: (_args, _store, _storage, native): Result<'currentSession'> => {
    if (!native?.available) return { userId: '' };
    return native.call({ op: 'session' }) as Result<'currentSession'>;
  },
  // matrixcore filters the list (filter: all, unread, unanswered, people or groups); with all, the
  // pinned chats are not in it.
  loadRoomsByRecency: async ([userId, filter], _store, _storage, native): Promise<Result<'loadRoomsByRecency'>> => {
    if (userId === '' || !native?.available) return { owner: userId, filter, rooms: [], pinned: [] };
    native.watch('rooms'); // Matrix.swift says when a room's last message or the list changes
    const answer = (await native.later({ op: 'rooms', filter })) as RoomsAnswer;
    const byId = new Map(answer.rooms.map((r) => [r.id, r]));
    return {
      owner: userId, filter,
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
