import { expect, test } from 'bun:test';
import { formatPhone, memberLinks, unescapeLocalPart } from './network-profiles';

const ig = '@instagram_123456789012345:example.org';

test("an Instagram member's username gives their profile, an Instagram chat and their handle", () => {
  expect(memberLinks('instagram', ig, ['instagram:some.user_1'])).toEqual({
    profile: 'https://www.instagram.com/some.user_1/',
    chat: 'https://ig.me/m/some.user_1',
    handle: '@some.user_1',
    phone: '',
  });
});

test('an Instagram member without a username has no links: the id is not a username', () => {
  expect(memberLinks('instagram', ig, [])).toEqual({ profile: '', chat: '', handle: '', phone: '' });
  // a stored name with a space is no Instagram username.
  expect(memberLinks('instagram', ig, ['instagram:Instagram User']).profile).toBe('');
});

test("a WhatsApp member's number shows, and opens a chat in WhatsApp (it has no profile pages)", () => {
  expect(memberLinks('whatsapp', '@whatsapp_15551234567:example.org', [])).toEqual({
    profile: '', chat: 'https://wa.me/15551234567', handle: '', phone: '+1 (555) 123-4567',
  });
  expect(memberLinks('whatsapp', '@whatsapp_lid-123456789012345:example.org', ['tel:+4915112345678'])).toEqual({
    profile: '', chat: 'https://wa.me/4915112345678', handle: '', phone: '+4915112345678',
  });
});

test('a WhatsApp member known only by a private id has no number and no link yet', () => {
  expect(memberLinks('whatsapp', '@whatsapp_lid-123456789012345:example.org', [])).toEqual({
    profile: '', chat: '', handle: '', phone: '',
  });
});

test("a LinkedIn member's id gives their profile, and a number their bridge knows shows", () => {
  expect(unescapeLocalPart('_a_co_a_a_bxyz-9_q')).toBe('ACoAABxyz-9Q');
  expect(memberLinks('linkedin', '@linkedin__a_co_a_a_bxyz-9_q:example.org', []).profile)
    .toBe('https://www.linkedin.com/in/ACoAABxyz-9Q/');
  expect(memberLinks('linkedin', '@linkedin_12345678:example.org', ['linkedin:ACoAABxyz', 'tel:+15551234567'])).toEqual({
    profile: 'https://www.linkedin.com/in/ACoAABxyz/', chat: '', handle: '', phone: '+1 (555) 123-4567',
  });
});

test('a malformed escape or an identifier of another network gives no link', () => {
  expect(unescapeLocalPart('_A')).toBeUndefined();
  expect(unescapeLocalPart('=zz')).toBeUndefined();
  expect(memberLinks('linkedin', '@linkedin_12345678:example.org', []).profile).toBe('');
  expect(memberLinks('instagram', '@instagram_1:example.org', ['linkedin:ACoAABxyz']).profile).toBe('');
});

test('an identifier that could leave the profile path is refused', () => {
  expect(memberLinks('instagram', '@instagram_1:example.org', ['instagram:../accounts/edit']).chat).toBe('');
  expect(memberLinks('instagram', '@instagram_1:example.org', ['instagram:a?b']).profile).toBe('');
  expect(memberLinks('whatsapp', '@whatsapp_lid-1:example.org', ['tel:+1555;call']).chat).toBe('');
});

test('a Matrix member, or no member, has no network links', () => {
  expect(memberLinks('matrix', '@ana:example.org', ['instagram:ana']).profile).toBe('');
  expect(memberLinks('instagram', '', ['instagram:ana']).profile).toBe('');
});

test('phone numbers read as people write them', () => {
  expect(formatPhone('15551234567')).toBe('+1 (555) 123-4567');
  expect(formatPhone('447700900123')).toBe('+447700900123');
});
