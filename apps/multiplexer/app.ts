import type { Answer, Result, Sources } from './app.contract.d.ts';

// app.json’s app.id: change the two together.
export const appId = 'com.ramimaalouf.multiplexer';
export const grants = '';

// what modules/apple/Matrix.swift answers. a refused sign-in names its problem;
// this module says it to the person.
type SignInAnswer = { ok: boolean; problem: string; detail: string };
type RoomsAnswer = { rooms: Result<'loadRooms'>['rooms'] };
type MessagesAnswer = {
  messages: {
    id: string; sender: string; senderName: string; body: string; time: number; isOwn: boolean; state: string;
    isImage: boolean; image: string; imageWidth: number; imageHeight: number;
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
  loadRooms: async ([userId], _store, _storage, native): Promise<Result<'loadRooms'>> => {
    if (userId === '' || !native?.available) return { owner: userId, rooms: [] };
    native.watch('rooms'); // Matrix.swift says when a room's last message or the list changes
    const answer = (await native.later({ op: 'rooms' })) as RoomsAnswer;
    return { owner: userId, rooms: answer.rooms };
  },
  loadMessages: async ([roomId, isDirect], _store, _storage, native): Promise<Result<'loadMessages'>> => {
    if (roomId === '' || !native?.available) return { room: roomId, messages: [] };
    native.watch(`thread:${roomId}`);
    const answer = (await native.later({ op: 'messages', roomId, limit: MESSAGE_COUNT })) as MessagesAnswer;
    const messages = answer.messages.map((m, i) => {
      const before = answer.messages[i - 1];
      const startsGroup = before === undefined || m.time - before.time > GROUP_GAP_MS;
      // a group chat names the sender above the first message of each run.
      const showName = !isDirect && !m.isOwn && (startsGroup || before.sender !== m.sender);
      return {
        id: m.id, senderName: m.senderName, body: m.body, time: m.time, isOwn: m.isOwn, state: m.state, startsGroup, showName,
        isImage: m.isImage, image: m.image, imageWidth: m.imageWidth, imageHeight: m.imageHeight,
        photoWidth: m.imageWidth > 0 && m.imageHeight > 0
          ? Math.min(PHOTO_MAX_WIDTH, (PHOTO_MAX_HEIGHT * m.imageWidth) / m.imageHeight) : PHOTO_MAX_WIDTH,
      };
    });
    return { room: roomId, messages };
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
  sendMessage: async ([roomId, text], _store, _storage, native): Promise<Result<'sendMessage'>> => {
    await native!.later({ op: 'send', roomId, text });
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
