import type { Result } from './app.contract.d.ts';
import { emojiGroups } from './emoji.ts';

type EmojiRow = Result<'loadEmojiRows'>[number];
type Emoji = { emoji: string; name: string; words: string[] };

const wordsOf = (text: string): string[] => text.toLowerCase().split(/[^\p{L}\p{N}]+/u).filter((w) => w !== '');

// each group's emoji with the words a search matches, read from emoji.ts at the first ask.
let catalog: { id: string; name: string; emojis: Emoji[] }[] | undefined;
const groups = () => catalog ??= emojiGroups.map(([id, name, list]) => ({
  id, name,
  emojis: list.split('\n').map((line) => {
    const [emoji, title, keywords] = line.split('\t');
    return { emoji, name: title, words: wordsOf(`${title} ${keywords}`) };
  }),
}));
let named: Map<string, string> | undefined;
// an emoji's name; a recent emoji may come without the emoji variation selector.
const nameOf = (emoji: string): string => {
  named ??= new Map(groups().flatMap((g) => g.emojis.map((e) => [e.emoji.replace(/️/g, ''), e.name] as const)));
  return named.get(emoji.replace(/️/g, '')) ?? emoji;
};

// rows of `columns` emoji, keyed `<group>-<n>`, so the grid knows the group of its first row.
const rowsOf = (group: string, emojis: { emoji: string; name: string }[], columns: number): EmojiRow[] => {
  const rows: EmojiRow[] = [];
  for (let i = 0; i < emojis.length; i += columns) {
    rows.push({ key: `${group}-${i / columns}`, title: '', emojis: emojis.slice(i, i + columns).map(({ emoji, name }) => ({ emoji, name })) });
  }
  return rows;
};

/** The reaction sheet's grid, as Beeper's: "Frequently used" (`frequent`, the account's), then
 * each group under its name. A search shows the emoji whose name or keywords hold every word
 * typed (as the start of a word), those whose name starts with it first. */
export function emojiRows(query: string, columns: number, frequent: string[]): EmojiRow[] {
  const all = groups(), typed = wordsOf(query);
  if (typed.length > 0) {
    const whole = typed.join(' ');
    const rank = (e: Emoji) => (e.name.startsWith(whole) ? 0 : (wordsOf(e.name).some((w) => w.startsWith(typed[0])) ? 1 : 2));
    const found = all.flatMap((g) => g.emojis).filter((e) => typed.every((t) => e.words.some((w) => w.startsWith(t))))
      .map((e, i) => ({ e, i, r: rank(e) })).sort((a, b) => a.r - b.r || a.i - b.i).map(({ e }) => e);
    return rowsOf('found', found, columns);
  }
  const rows: EmojiRow[] = [];
  if (frequent.length > 0) {
    rows.push({ key: 'frequent', title: 'Frequently used', emojis: [] });
    rows.push(...rowsOf('frequent', frequent.map((emoji) => ({ emoji, name: nameOf(emoji) })), columns));
  }
  for (const g of all) {
    rows.push({ key: g.id, title: g.name, emojis: [] });
    rows.push(...rowsOf(g.id, g.emojis, columns));
  }
  return rows;
}
