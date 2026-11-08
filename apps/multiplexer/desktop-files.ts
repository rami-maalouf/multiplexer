import type { FileSystem } from './app.contract.d.ts';

const mime: Record<string, string> = {
  jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', gif: 'image/gif', webp: 'image/webp',
  heic: 'image/heic', pdf: 'application/pdf', txt: 'text/plain', md: 'text/markdown',
  mp4: 'video/mp4', mov: 'video/quicktime', mp3: 'audio/mpeg', zip: 'application/zip',
};

export async function stageDroppedFiles(paths: readonly string[], fs: Pick<FileSystem, 'stat' | 'mkdir' | 'copyFile'>, limit: number, batch: string) {
  const items = [];
  const rejected: string[] = [];
  const folder = `app:/tmp/upload/drop-${batch}`;
  await fs.mkdir(folder);
  for (const [index, path] of paths.entries()) {
    const name = path.split('/').at(-1) || 'Attachment';
    try {
      const stat = await fs.stat(path);
      if (!stat.isFile || (limit > 0 && stat.size > limit)) { rejected.push(name); continue; }
      const type = mime[name.split('.').at(-1)?.toLowerCase() ?? ''] ?? 'application/octet-stream';
      const staged = `${folder}/${index}-${encodeURIComponent(name)}`;
      await fs.copyFile(path, staged);
      items.push({ file: { path: staged, name, type, size: stat.size, width: 0, height: 0 }, photo: type.startsWith('image/') });
    } catch { rejected.push(name); }
  }
  return { items, problem: rejected.length ? `Could not attach: ${rejected.join(', ')}. Choose files within the server's size limit.` : '' };
}
