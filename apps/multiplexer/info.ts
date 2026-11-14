import type { Result, Sources } from './app.contract.d.ts';
import { memberProfileUrl } from './network-profiles';

// a chat's info page (info.contract): what modules/apple/Info.swift answers. MatrixCore says when
// any of it changes, on the topic info:<room>.
type InfoSources = Pick<Sources, 'loadChatInfo' | 'loadChatMember' | 'loadMemberLink' | 'loadChatMembers' | 'loadChatMedia' | 'renameChat' | 'setChatPicture'
  | 'setCustomName' | 'inviteMember' | 'loadExpiry' | 'setExpiry'>;

const initials = (name: string): string =>
  name.split(/\s+/).filter((w) => /^[\p{L}\p{N}]/u.test(w)).slice(0, 2).map((w) => [...w][0].toUpperCase()).join('')
  || [...name.trim()][0] || '';

// each picture gets its own file, so a second one is not the first one cached.
let pictures = 0;

export const infoSources: InfoSources = {
  // the chat's message expiry, when its network takes timers (MatrixCore MessageExpiry.swift).
  loadExpiry: async ([roomId], _store, _storage, native): Promise<Result<'loadExpiry'>> => {
    if (roomId === '' || !native?.available) return { room: roomId, offered: false, timer: 0, choices: [] };
    native.watch(`info:${roomId}`);
    const answer = (await native.later({ op: 'expiry', roomId })) as { offered: boolean; timer: number; choices: number[] };
    return { room: roomId, ...answer };
  },
  setExpiry: async ([roomId, timer], _store, _storage, native): Promise<Result<'setExpiry'>> => {
    await native!.later({ op: 'setExpiry', roomId, timer });
    return { ok: true };
  },
  loadChatInfo: async ([roomId], _store, _storage, native): Promise<Result<'loadChatInfo'>> => {
    const none = {
      id: roomId, name: '', roomName: '', customName: '', topic: '', picture: '', initials: '', network: 'matrix',
      isOneToOne: false, memberCount: 0, canRename: false, canChangePicture: false, canInvite: false,
    };
    if (roomId === '' || !native?.available) return none;
    native.watch(`info:${roomId}`);
    native.watch('rooms'); // a name only you see changes the list's name too
    const answer = (await native.later({ op: 'chatInfo', roomId })) as Omit<typeof none, 'initials'>;
    return { ...answer, initials: initials(answer.name) };
  },
  // the first `limit` members by name; the page asks for all of them at "See All".
  loadChatMembers: async ([roomId, limit], _store, _storage, native): Promise<Result<'loadChatMembers'>> => {
    if (roomId === '' || !native?.available) return { room: roomId, total: 0, members: [] };
    native.watch(`info:${roomId}`);
    const answer = (await native.later({ op: 'chatMembers', roomId, limit })) as
      { total: number; members: { id: string; name: string; isOwn: boolean; picture: string }[] };
    return { room: roomId, total: answer.total, members: answer.members.map((m) => ({ ...m, initials: initials(m.name) })) };
  },
  // select before the native preview limit, downloading only this person's picture.
  loadChatMember: async ([roomId, userId], _store, _storage, native): Promise<Result<'loadChatMember'>> => {
    if (roomId === '' || userId === '' || !native?.available) return { room: roomId, total: 0, members: [] };
    native.watch(`info:${roomId}`);
    const answer = (await native.later({ op: 'chatMembers', roomId, userId, limit: 1 })) as
      { total: number; members: { id: string; name: string; isOwn: boolean; picture: string }[] };
    return { room: roomId, total: answer.total, members: answer.members.map((m) => ({ ...m, initials: initials(m.name) })) };
  },
  // the member's profile on the chat's network (network-profiles.ts): the bridge's identifiers,
  // asked only for a bridged chat's member, else what their Matrix id says.
  loadMemberLink: async ([userId, network], _store, _storage, native): Promise<Result<'loadMemberLink'>> => {
    if (userId === '' || network === 'matrix' || !native?.available) return { user: userId, url: '' };
    const answer = (await native.later({ op: 'memberIdentifiers', userId }).catch(() => ({ identifiers: [] }))) as
      { identifiers: string[] };
    return { user: userId, url: memberProfileUrl(network, userId, answer.identifiers) };
  },
  // the newest photos and videos, newest first; duration in milliseconds.
  loadChatMedia: async ([roomId, limit], _store, _storage, native): Promise<Result<'loadChatMedia'>> => {
    if (roomId === '' || !native?.available) return { room: roomId, items: [] };
    native.watch(`info:${roomId}`);
    const answer = (await native.later({ op: 'chatMedia', roomId, limit })) as {
      media: { id: string; isVideo: boolean; time: number; senderName: string; isOwn: boolean; caption: string;
        width: number; height: number; image: string; duration: number }[];
    };
    return {
      room: roomId,
      items: answer.media.map(({ duration, width: _w, height: _h, ...m }) => ({ ...m, seconds: Math.round(duration / 1000) })),
    };
  },
  // a new name and picture reach everyone in the chat, and its network through the bridge.
  renameChat: async ([roomId, name], _store, _storage, native): Promise<Result<'renameChat'>> => {
    await native!.later({ op: 'rename', roomId, name: name.trim() });
    return { ok: true };
  },
  // the picked photo, made a small upright JPEG first, as a photo message is.
  setChatPicture: async ([roomId, file], _store, storage, native): Promise<Result<'setChatPicture'>> => {
    await storage.fs.mkdir('app:/tmp/upload/picture').catch((e: { code?: string }) => { if (e?.code !== 'EEXIST') throw e; });
    const small = await storage.fs.compressImage(file.path, `app:/tmp/upload/picture/${++pictures}.jpg`,
      { maxDimension: 1024, maxBytes: 400_000 });
    await native!.later({ op: 'setPicture', roomId, path: small.path, mimetype: small.type, width: small.width, height: small.height });
    return { ok: true };
  },
  // "" goes back to the chat's own name.
  setCustomName: async ([roomId, name], _store, _storage, native): Promise<Result<'setCustomName'>> => {
    await native!.later({ op: 'customName', roomId, name: name.trim() });
    return { ok: true };
  },
  inviteMember: async ([roomId, userId], _store, _storage, native): Promise<Result<'inviteMember'>> => {
    await native!.later({ op: 'invite', roomId, userId: userId.trim() });
    return { ok: true };
  },
};
