import { expect, test } from 'bun:test';
import { linkOf, siteOf } from './links.ts';

const run = (text: string, href = '') => ({ text, href });

test('a message that is only a link is a card with the link\'s own site', () => {
  expect(linkOf([run('https://www.apple.com/iphone/', 'https://www.apple.com/iphone/')]))
    .toEqual({ previewUrl: 'https://www.apple.com/iphone/', linkOnly: true, linkSite: 'apple.com' });
  expect(linkOf([run('  '), run('www.example.com/a', 'https://www.example.com/a'), run('\n')]).linkOnly).toBe(true);
});

test('a text with a link keeps its text and previews the first link', () => {
  const found = linkOf([run('See '), run('https://en.wikipedia.org/wiki/Montreal', 'https://en.wikipedia.org/wiki/Montreal'),
    run(' and '), run('https://example.com', 'https://example.com')]);
  expect(found).toEqual({ previewUrl: 'https://en.wikipedia.org/wiki/Montreal', linkOnly: false, linkSite: 'en.wikipedia.org' });
  expect(linkOf([run('https://a.com', 'https://a.com'), run(' '), run('https://b.com', 'https://b.com')]).linkOnly).toBe(false);
});

test('no web link, no preview', () => {
  expect(linkOf([run('hello')])).toEqual({ previewUrl: '', linkOnly: false, linkSite: '' });
  expect(siteOf('mailto:a@b.c')).toBe('');
  expect(siteOf('not a url')).toBe('');
  expect(siteOf('https://WWW.Example.COM/x')).toBe('example.com');
});
