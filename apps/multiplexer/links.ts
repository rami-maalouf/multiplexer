// a link preview's link (R11): the first web link of a text message, whether the message is only
// that link, and the site it goes to, read from the link itself (never from the page), so a card
// cannot say another site than the one a tap opens.

type Run = { text: string; href: string };

export type MessageLink = { previewUrl: string; linkOnly: boolean; linkSite: string };

export const noLink: MessageLink = { previewUrl: '', linkOnly: false, linkSite: '' };

/** The site of a web link: its host without "www.", or "" for a link that is not http(s). */
export const siteOf = (href: string): string => {
  try {
    const url = new URL(href);
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return '';
    return url.hostname.replace(/^www\./iu, '');
  } catch {
    return '';
  }
};

/** A text's runs (app.ts's runsOf): its first web link, and whether nothing but spaces is around it. */
export const linkOf = (runs: Run[]): MessageLink => {
  const links = runs.filter((r) => r.href !== '' && siteOf(r.href) !== '');
  const first = links[0];
  if (first === undefined) return noLink;
  const linkOnly = links.length === 1 && runs.every((r) => r.href !== '' || r.text.trim() === '');
  return { previewUrl: first.href, linkOnly, linkSite: siteOf(first.href) };
};
