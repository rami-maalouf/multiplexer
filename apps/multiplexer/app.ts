import type { Answer, Result, Sources } from './app.contract.d.ts';

// app.json’s app.id: change the two together.
export const appId = 'com.ramimaalouf.multiplexer';
export const grants = '';

// what modules/apple/Matrix.swift answers a sign-in with. a refusal names its problem;
// this module says it to the person.
type SignInAnswer = { ok: boolean; problem: string; detail: string };
type RoomsAnswer = { rooms: Result<'loadRooms'>['rooms'] };

const problems: Record<string, (server: string) => string> = {
  'wrong-password': () => 'The user name or password is wrong.',
  'server-not-found': (server) => `No Matrix server answered at ${server}. Check the server name.`,
  'server-not-supported': (server) => `${server} does not support sliding sync, which Multiplexer needs.`,
  'rate-limited': () => 'The server got too many sign-in attempts. Wait a minute, then try again.',
};

// the web has no Matrix SDK: it shows the sign-in screen and refuses to sign in.
const sources: Sources = {
  currentSession: (_args, _store, _storage, native): Result<'currentSession'> => {
    if (!native?.available) return { userId: '' };
    return native.call({ op: 'session' }) as Result<'currentSession'>;
  },
  loadRooms: async ([userId], _store, _storage, native): Promise<Result<'loadRooms'>> => {
    if (userId === '' || !native?.available) return { owner: userId, rooms: [] };
    const answer = (await native.later({ op: 'rooms' })) as RoomsAnswer;
    return { owner: userId, rooms: answer.rooms };
  },
  signIn: async ([server, user, password], _store, _storage, native): Promise<Result<'signIn'>> => {
    if (!native?.available) return { ok: false, error: 'This build has no Matrix SDK.' };
    const answer = (await native.later({ op: 'signIn', server, user, password })) as SignInAnswer;
    if (answer.ok) return { ok: true, error: '' };
    return { ok: false, error: problems[answer.problem]?.(server) ?? `Multiplexer could not sign in: ${answer.detail}` };
  },
  signOut: async (_args, _store, _storage, native): Promise<Result<'signOut'>> => {
    await native!.later({ op: 'signOut' });
    return { ok: true };
  },
};
export const answer: Answer = (source, args, store, storage, native) =>
  sources[source](args, store, storage, native);
