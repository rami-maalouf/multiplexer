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

/** A phone number as people read it: `+1 (555) 123-4567` for North America, else `+<digits>`. */
export const formatPhone = (digits: string): string => {
  const nanp = /^1(\d{3})(\d{3})(\d{4})$/u.exec(digits);
  return nanp ? `+1 (${nanp[1]}) ${nanp[2]}-${nanp[3]}` : `+${digits}`;
};

/** What a member's page offers for them on their own network: every field '' when unknown. */
export type MemberLinks = {
  /** Their profile page on the network (Instagram, LinkedIn); WhatsApp has none. */
  profile: string;
  /** A chat with them in the network's own app: Instagram's ig.me, WhatsApp's wa.me. */
  chat: string;
  /** Their username as the network shows it: `@name`. */
  handle: string;
  /** Their phone number, formatted. */
  phone: string;
};

const none: MemberLinks = { profile: '', chat: '', handle: '', phone: '' };

/** The phone number's digits from a `tel:+<digits>` identifier, or ''. */
const telDigits = (identifier: string): string => {
  if (!identifier.toLowerCase().startsWith('tel:')) return '';
  const digits = identifier.slice(4).replace(/^\+/u, '');
  return /^\d{6,15}$/u.test(digits) ? digits : '';
};

/** One identifier's value for its kind (`instagram:<name>` -> `<name>`), or '' when not that kind or unsafe. */
const valueOf = (identifiers: string[], kind: string): string => {
  for (const identifier of identifiers) {
    const colon = identifier.indexOf(':');
    if (colon < 1 || identifier.slice(0, colon).toLowerCase() !== kind) continue;
    const value = identifier.slice(colon + 1);
    if (safe(value)) return value;
  }
  return '';
};

/**
 * What the member's page links to on the chat's network: nothing for a Matrix chat, for no
 * member, or for a person whose bridge says too little.
 */
export const memberLinks = (network: string, userId: string, identifiers: string[]): MemberLinks => {
  if (network === 'matrix' || network === '' || userId === '') return none;
  const local = localPart(userId);
  const digits = identifiers.map(telDigits).find((d) => d !== '')
    ?? (network === 'whatsapp' ? /^whatsapp_(\d{6,15})$/u.exec(local)?.[1] ?? '' : '');
  const phone = digits === '' ? '' : formatPhone(digits);
  if (network === 'instagram') {
    const name = valueOf(identifiers, 'instagram');
    if (name === '') return { ...none, phone };
    return { profile: `https://www.instagram.com/${name}/`, chat: `https://ig.me/m/${name}`, handle: `@${name}`, phone };
  }
  if (network === 'whatsapp') {
    return { ...none, chat: digits === '' ? '' : `https://wa.me/${digits}`, phone };
  }
  if (network === 'telegram') {
    const name = valueOf(identifiers, 'telegram');
    return name === '' ? { ...none, phone } : { profile: `https://t.me/${name}`, chat: `https://t.me/${name}`, handle: `@${name}`, phone };
  }
  if (network === 'linkedin') {
    let id = valueOf(identifiers, 'linkedin');
    if (id === '' && local.startsWith('linkedin_')) {
      const unescaped = unescapeLocalPart(local.slice('linkedin_'.length));
      // a member's id: "ACoAA…", which LinkedIn's /in/ takes as it takes a vanity name.
      if (unescaped !== undefined && /^ACoAA[\w-]+$/u.test(unescaped)) id = unescaped;
    }
    return { ...none, profile: id === '' ? '' : `https://www.linkedin.com/in/${id}/`, phone };
  }
  return { ...none, phone };
};
