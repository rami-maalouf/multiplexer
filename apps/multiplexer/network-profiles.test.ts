import { expect, test } from 'bun:test';
import { memberProfileUrl, unescapeLocalPart } from './network-profiles';

test("an Instagram member's username from their bridge opens their profile", () => {
  expect(memberProfileUrl('instagram', '@instagram_123456789012345:example.org', ['instagram:some.user_1']))
    .toBe('https://www.instagram.com/some.user_1/');
});

test('an Instagram member without identifiers has no profile link: the id is not a username', () => {
  expect(memberProfileUrl('instagram', '@instagram_123456789012345:example.org', [])).toBe('');
});

test("a WhatsApp member's phone number opens a chat with them in WhatsApp", () => {
  expect(memberProfileUrl('whatsapp', '@whatsapp_15551234567:example.org', [])).toBe('https://wa.me/15551234567');
  expect(memberProfileUrl('whatsapp', '@whatsapp_lid-123456789012345:example.org', ['tel:+15551234567']))
    .toBe('https://wa.me/15551234567');
});

test('a WhatsApp member known only by a private id has no link', () => {
  expect(memberProfileUrl('whatsapp', '@whatsapp_lid-123456789012345:example.org', [])).toBe('');
});

test("a LinkedIn member's escaped id opens their profile", () => {
  expect(unescapeLocalPart('_a_co_a_a_bxyz-9_q')).toBe('ACoAABxyz-9Q');
  expect(memberProfileUrl('linkedin', '@linkedin__a_co_a_a_bxyz-9_q:example.org', []))
    .toBe('https://www.linkedin.com/in/ACoAABxyz-9Q/');
  expect(memberProfileUrl('linkedin', '@linkedin_12345678:example.org', ['linkedin:ACoAABxyz']))
    .toBe('https://www.linkedin.com/in/ACoAABxyz/');
});

test('a malformed escape or an identifier of another network gives no link', () => {
  expect(unescapeLocalPart('_A')).toBeUndefined();
  expect(unescapeLocalPart('=zz')).toBeUndefined();
  expect(memberProfileUrl('linkedin', '@linkedin_12345678:example.org', [])).toBe('');
  expect(memberProfileUrl('instagram', '@instagram_1:example.org', ['linkedin:ACoAABxyz'])).toBe('');
});

test('an identifier that could leave the profile path is refused', () => {
  expect(memberProfileUrl('instagram', '@instagram_1:example.org', ['instagram:../accounts/edit'])).toBe('');
  expect(memberProfileUrl('instagram', '@instagram_1:example.org', ['instagram:a?b'])).toBe('');
});

test('a Matrix member, or no member, has no network link', () => {
  expect(memberProfileUrl('matrix', '@ana:example.org', ['instagram:ana'])).toBe('');
  expect(memberProfileUrl('instagram', '', ['instagram:ana'])).toBe('');
});
