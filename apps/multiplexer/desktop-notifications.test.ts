import { expect, test } from 'bun:test';
import { DesktopNotifications, DesktopNotificationDelivery, type DesktopNotificationRoom, type DesktopNotificationSnapshot } from './desktop-notifications.ts';

const now = 1_800_000_000_000;
const room = (changes: Partial<DesktopNotificationRoom> = {}): DesktopNotificationRoom => ({
  id: '!a:example.org', name: 'Alex', isDirect: true, lastMessage: 'old message',
  lastSender: 'Alex', lastIsOwn: false, lastTime: now - 1000, unread: 4,
  listed: true, muted: false, mentions: 0, merge: '', open: '!a:example.org', mergeRooms: [], ...changes,
});
const snapshot = (rooms: DesktopNotificationRoom[], changes: Partial<DesktopNotificationSnapshot> = {}): DesktopNotificationSnapshot => ({
  userId: '@me:example.org', rooms, openRoom: '', foreground: true, visible: true,
  notificationsEnabled: true, permissionGranted: true, now, ...changes,
});
const incoming = (changes: Partial<DesktopNotificationRoom> = {}) => room({ lastTime: now + 100, lastMessage: 'hello', ...changes });
const baseline = (rooms = [room()]) => {
  const policy = new DesktopNotifications();
  expect(policy.update(snapshot(rooms))).toEqual([]);
  return policy;
};

test('startup establishes a silent baseline, even with unread mentions', () => {
  const policy = baseline([incoming({ mentions: 2, muted: true })]);
  expect(policy.update(snapshot([incoming({ mentions: 2, muted: true })]))).toEqual([]);
});

test('an empty startup followed by history stays silent; a newly observed live room notifies', () => {
  const policy = baseline([]);
  expect(policy.update(snapshot([room()]))).toEqual([]);
  expect(policy.update(snapshot([room(), incoming({ id: '!new', open: '!new' })]))).toEqual([
    { title: 'Alex', body: 'hello', tag: 'chat:@me:example.org:!new', data: '!new' },
  ]);
});

test('new incoming direct and group previews produce click-ready options regardless of filters', () => {
  const policy = baseline([room(), room({ id: '!group', open: '!group' })]);
  expect(policy.update(snapshot([
    incoming({ listed: false }),
    incoming({ id: '!group', open: '!group', name: 'Team', isDirect: false, lastSender: 'Sam' }),
  ]))).toEqual([
    { title: 'Alex', body: 'hello', tag: 'chat:@me:example.org:!a:example.org', data: '!a:example.org' },
    { title: 'Team', body: 'Sam: hello', tag: 'chat:@me:example.org:!group', data: '!group' },
  ]);
});

test('repeated snapshots, unread counts, read receipts and preview edits do not repeat a message', () => {
  const policy = baseline();
  expect(policy.update(snapshot([incoming()]))).toHaveLength(1);
  expect(policy.update(snapshot([incoming()]))).toEqual([]);
  expect(policy.update(snapshot([incoming({ unread: 0, mentions: 1 })]))).toEqual([]);
  expect(policy.update(snapshot([incoming({ lastMessage: 'edited', lastSender: 'new name', unread: 9 })]))).toEqual([]);
  expect(policy.update(snapshot([incoming({ lastTime: now + 200 })]))).toHaveLength(1);
});

test('outgoing messages advance the baseline and cannot replay as incoming', () => {
  const policy = baseline();
  expect(policy.update(snapshot([incoming({ lastIsOwn: true })]))).toEqual([]);
  expect(policy.update(snapshot([incoming()]))).toEqual([]);
  expect(policy.update(snapshot([incoming({ lastTime: now + 200 })]))).toHaveLength(1);
});

for (const suppression of [
  { openRoom: '!a:example.org' },
  { notificationsEnabled: false },
  { permissionGranted: false },
]) {
  test(`suppression consumes the message without replay: ${JSON.stringify(suppression)}`, () => {
    const policy = baseline();
    expect(policy.update(snapshot([incoming()], suppression))).toEqual([]);
    expect(policy.update(snapshot([incoming()]))).toEqual([]);
    expect(policy.update(snapshot([incoming({ lastTime: now + 200 })]))).toHaveLength(1);
  });
}

test('the selected room notifies when the app is backgrounded or its window is hidden', () => {
  for (const state of [{ foreground: false }, { visible: false }]) {
    const policy = baseline();
    expect(policy.update(snapshot([incoming()], { openRoom: '!a:example.org', ...state }))).toHaveLength(1);
  }
});

test('a muted room requires a new mention increase, not an existing unread mention', () => {
  const policy = baseline([room({ muted: true, mentions: 2 })]);
  expect(policy.update(snapshot([incoming({ muted: true, mentions: 2 })]))).toEqual([]);
  expect(policy.update(snapshot([incoming({ muted: true, mentions: 3, lastTime: now + 200 })]))).toHaveLength(1);
  expect(policy.update(snapshot([incoming({ muted: true, mentions: 3, lastTime: now + 300 })]))).toEqual([]);
  expect(policy.update(snapshot([incoming({ lastTime: now + 300 })]))).toEqual([]);
});

test('mention reset allows a later new mention, while initial historical mentions stay silent', () => {
  const policy = baseline([room({ muted: true, mentions: 3 })]);
  expect(policy.update(snapshot([room({ muted: true, mentions: 0 })]))).toEqual([]);
  expect(policy.update(snapshot([incoming({ muted: true, mentions: 1 })]))).toHaveLength(1);
});

test('merged children stay silent and merged rows route to a real room', () => {
  const child = room({ merge: 'pair', listed: false });
  const merged = room({ id: 'merge:pair', name: 'Both networks', merge: 'pair', mergeRooms: [{ id: child.id, network: 'matrix' }] });
  const policy = baseline([child, merged]);
  const updated = [incoming({ ...child, lastTime: now + 100 }), incoming({ ...merged, lastTime: now + 100 })];
  expect(policy.update(snapshot(updated))).toEqual([
    { title: 'Both networks', body: 'old message', tag: 'chat:@me:example.org:merge:pair', data: child.id },
  ]);
  expect(policy.update(snapshot([incoming({ lastTime: now + 100 })]))).toEqual([]);
});

test('selecting any member of a merge suppresses its row while foregrounded', () => {
  const merged = room({ id: 'merge:pair', merge: 'pair', open: '!b', mergeRooms: [{ id: '!a', network: 'matrix' }, { id: '!b', network: 'signal' }] });
  for (const openRoom of ['!a', '!b', 'merge:pair']) {
    const child = room({ id: '!a', open: '!a', merge: 'pair' });
    const policy = baseline([child, merged]);
    const changed = [{ ...child, lastTime: now + 100 }, { ...merged, lastTime: now + 100 }];
    expect(policy.update(snapshot(changed, { openRoom }))).toEqual([]);
    expect(policy.update(snapshot(changed))).toEqual([]);
  }
});

test('merged membership suppresses children even when their merge field is empty', () => {
  const child = room();
  const merged = room({ id: 'merge:pair', merge: 'pair', mergeRooms: [{ id: child.id, network: 'matrix' }] });
  const policy = baseline([child, merged]);
  const notices = policy.update(snapshot([
    { ...child, lastTime: now + 100 }, { ...merged, lastTime: now + 100 },
  ]));
  expect(notices).toHaveLength(1);
  expect(notices[0]?.tag).toBe('chat:@me:example.org:merge:pair');
});

test('an account switch and signout reset all baselines without startup notifications', () => {
  const policy = baseline();
  expect(policy.update(snapshot([incoming()]))).toHaveLength(1);
  expect(policy.update(snapshot([incoming()], { userId: '@other:example.org' }))).toEqual([]);
  expect(policy.update(snapshot([incoming({ lastTime: now + 200 })], { userId: '@other:example.org' }))[0]?.tag)
    .toBe('chat:@other:example.org:!a:example.org');
  expect(policy.update(snapshot([incoming()], { userId: '' }))).toEqual([]);
  expect(policy.update(snapshot([incoming()]))).toEqual([]);
  expect(policy.update(snapshot([incoming({ lastTime: now + 200 })]))).toHaveLength(1);
});

test('disappearing or regressing rooms cannot replay an already observed timestamp', () => {
  const policy = baseline();
  expect(policy.update(snapshot([incoming()]))).toHaveLength(1);
  expect(policy.update(snapshot([]))).toEqual([]);
  expect(policy.update(snapshot([room()]))).toEqual([]);
  expect(policy.update(snapshot([incoming()]))).toEqual([]);
});

test('timestamp collisions are deliberately suppressed without an event id', () => {
  const policy = baseline();
  expect(policy.update(snapshot([incoming()]))).toHaveLength(1);
  expect(policy.update(snapshot([incoming({ lastMessage: 'another message in the same millisecond' })]))).toEqual([]);
});

test('a newly observed message already read on another device stays silent', () => {
  const policy = baseline();
  expect(policy.update(snapshot([incoming({ unread: 0, mentions: 0 })]))).toEqual([]);
});


test('merged notification eligibility respects the originating room mute and read state', () => {
  const child = room({ merge: 'pair', muted: true });
  const other = room({ id: '!b', open: '!b', merge: 'pair' });
  const merged = room({ id: 'merge:pair', merge: 'pair', muted: false,
    mergeRooms: [{ id: child.id, network: 'matrix' }, { id: other.id, network: 'signal' }] });
  const policy = baseline([child, other, merged]);
  expect(policy.update(snapshot([{ ...child, lastTime: now + 100 }, other, { ...merged, lastTime: now + 100 }]))).toEqual([]);
  expect(policy.update(snapshot([{ ...child, lastTime: now + 200, mentions: 1 }, other,
    { ...merged, lastTime: now + 200, mentions: 1 }]))).toHaveLength(1);
  expect(policy.update(snapshot([{ ...child, lastTime: now + 300, muted: false, unread: 0, mentions: 0 }, other,
    { ...merged, lastTime: now + 300 }]))).toEqual([]);
});

test('an ordinary refresh cannot abandon an in-flight batch', async () => {
  const delivery = new DesktopNotificationDelivery();
  const generation = delivery.configure('@me', true, true);
  const notices = baseline([]).update(snapshot([incoming(), incoming({ id: '!b', open: '!b' })]));
  const shown: string[] = [];
  const delivered = await delivery.send(notices, generation, async (notice) => {
    shown.push(notice.data);
    await Promise.resolve();
    delivery.configure('@me', true, true);
  });
  expect(delivered).toBe(2);
  expect(shown).toEqual(['!a:example.org', '!b']);
});

for (const change of [['@other', true, true], ['@me', false, true], ['@me', true, false]] as const) {
  test(`account or permission changes cancel pending deliveries: ${JSON.stringify(change)}`, async () => {
    const delivery = new DesktopNotificationDelivery();
    const generation = delivery.configure('@me', true, true);
    const notices = baseline([]).update(snapshot([incoming(), incoming({ id: '!b', open: '!b' })]));
    expect(await delivery.send(notices, generation, async () => {
      delivery.configure(...change);
    })).toBe(1);
  });
}
