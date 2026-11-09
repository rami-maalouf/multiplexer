import { expect, test } from 'bun:test';
import { stageDroppedFiles } from './desktop-files.ts';

const fixture = () => {
  const copied: [string, string][] = [];
  const created: string[] = [];
  const fs = {
    stat: async (path: string) => ({ size: path.includes('large') ? 200 : 10,
      isFile: !path.endsWith('folder'), isDirectory: path.endsWith('folder'), modifiedMs: 0 }),
    mkdir: async (path: string) => { created.push(path); },
    copyFile: async (from: string, to: string) => {
      if (from.includes('unreadable')) throw new Error('permission denied');
      copied.push([from, to]);
    },
  };
  return { fs, copied, created };
};
test('dropped file handles are staged locally with original names and image kinds', async () => {
  const { fs, copied, created } = fixture();
  const result = await stageDroppedFiles(['doc:/1/report 25%.pdf', 'doc:/2/photo.png'], fs, 0, 'batch');
  expect(result.problem).toBe('');
  expect(result.items.map(item => [item.file.name, item.file.type, item.photo])).toEqual([
    ['report 25%.pdf', 'application/pdf', false], ['photo.png', 'image/png', true],
  ]);
  expect(created).toEqual(['app:/tmp/upload/drop-batch']);
  expect(copied.map(pair => pair[0])).toEqual(['doc:/1/report 25%.pdf', 'doc:/2/photo.png']);
  expect(result.items.every(item => item.file.path.startsWith('app:/tmp/upload/drop-batch/'))).toBe(true);
});
test('a folder, oversized or unreadable file does not discard other valid attachments', async () => {
  const { fs, copied } = fixture();
  const result = await stageDroppedFiles(['doc:/1/folder', 'doc:/2/large.zip', 'doc:/3/unreadable.txt', 'doc:/4/ok.txt'], fs, 100, 'mixed');
  expect(result.items.map(item => item.file.name)).toEqual(['ok.txt']);
  expect(result.problem).toContain('folder');
  expect(result.problem).toContain('large.zip');
  expect(result.problem).toContain('unreadable.txt');
  expect(copied).toHaveLength(1);
});
