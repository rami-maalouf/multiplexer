import { expect, test } from 'bun:test';
import { infoSources } from './info';

test('a profile requests its selected sender independently of the member preview', async () => {
  const requests: unknown[] = [];
  const watches: string[] = [];
  const native = {
    available: true,
    watch: (topic: string) => watches.push(topic),
    later: async (request: unknown) => {
      requests.push(request);
      return { total: 2000, members: [{ id: '@sender:example.org', name: 'Sender Name', picture: 'app:/sender.jpg', isOwn: false }] };
    },
  };
  const result = await infoSources.loadChatMember(['!group:example.org', '@sender:example.org'], {} as never, {} as never, native as never);
  expect(requests).toEqual([{ op: 'chatMembers', roomId: '!group:example.org', userId: '@sender:example.org', limit: 1 }]);
  expect(watches).toEqual(['info:!group:example.org']);
  expect(result.members[0]).toEqual({ id: '@sender:example.org', name: 'Sender Name', picture: 'app:/sender.jpg', initials: 'SN', isOwn: false });
});

test('a closed profile makes no native member request', async () => {
  const native = { available: true, later: () => { throw new Error('unexpected request'); } };
  for (const args of [['', ''], ['!room:example.org', '']] as [string, string][]) {
    const result = await infoSources.loadChatMember(args, {} as never, {} as never, native as never);
    expect(result.members).toEqual([]);
  }
});

test("a bridged member's profile link asks the bridge's identifiers for that person only", async () => {
  const requests: unknown[] = [];
  const native = {
    available: true,
    later: async (request: unknown) => {
      requests.push(request);
      return { identifiers: ['instagram:some.user'] };
    },
  };
  const result = await infoSources.loadMemberLink(['@instagram_1:example.org', 'instagram'], {} as never, {} as never, native as never);
  expect(requests).toEqual([{ op: 'memberIdentifiers', userId: '@instagram_1:example.org' }]);
  expect(result).toEqual({ user: '@instagram_1:example.org', url: 'https://www.instagram.com/some.user/' });
});

test("a Matrix member's page asks nothing, and a failed ask still links what the id says", async () => {
  const refuse = { available: true, later: () => { throw new Error('unexpected request'); } };
  expect(await infoSources.loadMemberLink(['@ana:example.org', 'matrix'], {} as never, {} as never, refuse as never))
    .toEqual({ user: '@ana:example.org', url: '' });
  const failing = { available: true, later: async () => { throw new Error('offline'); } };
  expect(await infoSources.loadMemberLink(['@whatsapp_15551234567:example.org', 'whatsapp'], {} as never, {} as never, failing as never))
    .toEqual({ user: '@whatsapp_15551234567:example.org', url: 'https://wa.me/15551234567' });
});
