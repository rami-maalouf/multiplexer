// a member's profile on their own network (info.contract's MemberPage), as Beeper links it: the
// network's web address for them, which iOS hands to the network's app when it is installed.
//
// the bridge's identifiers come first (MatrixCore Profile.swift: `instagram:<username>`,
// `linkedin:<id>`, `tel:+<number>`). without them, the person's Matrix id still says who they are
// on two networks: a WhatsApp bridge names a person by phone number (`@whatsapp_<digits>`,
// though newer ones by a private id, `@whatsapp_lid-<digits>`), and the LinkedIn bridge by member
// id (`@linkedin_<escaped id>`). an Instagram id is a Meta account number, which no address takes.

/** A user id's local part: `@ana:example.org` -> `ana`. */
const localPart = (userId: string): string => (userId.startsWith('@') ? userId.slice(1) : userId).split(':')[0] ?? '';

/**
 * A bridge's escaped local part read back (mautrix's `DecodeUserLocalpart`): `_x` is `X`, `__` is
 * `_`, `=xx` a byte in hex. undefined when it is not a valid escape.
 */
export const unescapeLocalPart = (escaped: string): string | undefined => {
  let out = '';
  for (let i = 0; i < escaped.length; i++) {
    const c = escaped[i]!;
    if (c === '_') {
      const next = escaped[i + 1];
      if (next === undefined) return undefined;
      if (next === '_') out += '_';
      else if (/[a-z]/u.test(next)) out += next.toUpperCase();
      else return undefined;
      i++;
    } else if (c === '=') {
      const hex = escaped.slice(i + 1, i + 3);
      if (!/^[0-9a-f]{2}$/u.test(hex)) return undefined;
      out += String.fromCharCode(parseInt(hex, 16));
      i += 2;
    } else {
      out += c;
    }
  }
  return out;
};

const safe = (part: string): boolean => part !== '' && /^[\p{L}\p{N}._-]+$/u.test(part);

/** The web address of one identifier on the member's network, or '' for none. */
const fromIdentifier = (network: string, identifier: string): string => {
  const colon = identifier.indexOf(':');
  if (colon < 1) return '';
  const kind = identifier.slice(0, colon).toLowerCase();
  const value = identifier.slice(colon + 1);
  if (kind === 'instagram' && network === 'instagram' && safe(value)) return `https://www.instagram.com/${value}/`;
  if (kind === 'linkedin' && network === 'linkedin' && safe(value)) return `https://www.linkedin.com/in/${value}/`;
  if (kind === 'telegram' && network === 'telegram' && safe(value)) return `https://t.me/${value}`;
  if (kind === 'tel' && network === 'whatsapp') {
    const digits = value.replace(/^\+/u, '');
    if (/^\d{6,15}$/u.test(digits)) return `https://wa.me/${digits}`;
  }
  return '';
};

/** The member's own network's address from their Matrix id, or '' for none (see the top). */
const fromUserId = (network: string, userId: string): string => {
  const local = localPart(userId);
  if (network === 'whatsapp') {
    const phone = /^whatsapp_(\d{6,15})$/u.exec(local)?.[1];
    return phone === undefined ? '' : `https://wa.me/${phone}`;
  }
  if (network === 'linkedin' && local.startsWith('linkedin_')) {
    const id = unescapeLocalPart(local.slice('linkedin_'.length));
    // a member's id: "ACoAA…", which LinkedIn's /in/ takes as it takes a vanity name.
    return id !== undefined && /^ACoAA[\w-]+$/u.test(id) ? `https://www.linkedin.com/in/${id}/` : '';
  }
  return '';
};

/**
 * The member's profile on the chat's network, or '' for none: a Matrix chat, your own page, a
 * network without profile pages, or a person whose bridge says too little.
 */
export const memberProfileUrl = (network: string, userId: string, identifiers: string[]): string => {
  if (network === 'matrix' || network === '' || userId === '') return '';
  for (const identifier of identifiers) {
    const url = fromIdentifier(network, identifier);
    if (url !== '') return url;
  }
  return fromUserId(network, userId);
};
