// writes ../emoji.ts, the emoji the reaction sheet offers, from Unicode's emoji-test.txt and
// CLDR's English annotations (annotations.json of cldr-json's cldr-annotations-full):
//
//   curl -o /tmp/emoji/emoji-test.txt https://unicode.org/Public/emoji/16.0/emoji-test.txt
//   curl -o /tmp/emoji/annotations.json https://raw.githubusercontent.com/unicode-org/cldr-json/main/cldr-json/cldr-annotations-full/annotations/en/annotations.json
//   bun tools/emoji-data.ts /tmp/emoji/emoji-test.txt /tmp/emoji/annotations.json
//
// it keeps the fully-qualified emoji in Unicode's order, without skin tones (as Beeper's sheet
// shows them) and without the Component group; each has its name and keywords for search.
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const [testFile, annotationsFile] = process.argv.slice(2);
if (!testFile || !annotationsFile) throw new Error('usage: bun tools/emoji-data.ts <emoji-test.txt> <annotations.json>');

// the sheet's tabs, in Unicode's group order.
const groups: Record<string, string> = {
  'Smileys & Emotion': 'smileys', 'People & Body': 'people', 'Animals & Nature': 'animals', 'Food & Drink': 'food',
  'Travel & Places': 'travel', Activities: 'activities', Objects: 'objects', Symbols: 'symbols', Flags: 'flags',
};
const annotations: Record<string, { default?: string[]; tts?: string[] }> =
  JSON.parse(readFileSync(annotationsFile, 'utf8')).annotations.annotations;
const keywordsOf = (emoji: string): string[] =>
  annotations[emoji]?.default ?? annotations[emoji.replace(/️/g, '')]?.default ?? [];

const version = /^# Version: (\S+)/m.exec(readFileSync(testFile, 'utf8'))?.[1] ?? '?';
const out: [string, string, string[]][] = [];
let group: [string, string, string[]] | undefined;
for (const line of readFileSync(testFile, 'utf8').split('\n')) {
  const g = /^# group: (.+)$/.exec(line);
  if (g) {
    const id = groups[g[1].trim()];
    group = id ? [id, g[1].trim(), []] : undefined;
    if (group) out.push(group);
    continue;
  }
  const m = /^([0-9A-F ]+?)\s*; fully-qualified\s*# (\S+) E\S+ (.+)$/.exec(line);
  if (!m || !group) continue;
  const points = m[1].split(' ').map((h) => parseInt(h, 16));
  if (points.some((p) => p >= 0x1f3fb && p <= 0x1f3ff)) continue;
  const emoji = String.fromCodePoint(...points);
  const name = m[3].trim().toLowerCase();
  const nameWords = new Set(name.split(/[^\p{L}\p{N}]+/u));
  const extra = [...new Set(keywordsOf(emoji).flatMap((k) => k.toLowerCase().split(/[^\p{L}\p{N}]+/u)))]
    .filter((w) => w !== '' && !nameWords.has(w));
  group[2].push(`${emoji}\t${name}\t${extra.join(' ')}`);
}

const total = out.reduce((n, g) => n + g[2].length, 0);
const body = out.map(([id, name, list]) => `  [${JSON.stringify(id)}, ${JSON.stringify(name)}, ${JSON.stringify(list.join('\n'))}],`).join('\n');
writeFileSync(join(import.meta.dir, '..', 'emoji.ts'), `// the emoji the reaction sheet offers (${total}), by Unicode's group, each "emoji<tab>name<tab>keywords"
// on its own line. Written by tools/emoji-data.ts from Unicode's emoji-test.txt (Emoji ${version}) and
// CLDR's English annotations: run it again rather than edit this file.
export const emojiGroups: [id: string, name: string, list: string][] = [
${body}
];
`);
console.log(`emoji.ts: ${total} emoji in ${out.length} groups (Emoji ${version})`);
