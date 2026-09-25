import { mkdir, readFile, rm, writeFile, copyFile } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = new URL('./', import.meta.url);
execFileSync(process.execPath, ['build.mjs'], {
  cwd: fileURLToPath(new URL('gpt6-celestial/', root)), stdio: 'inherit',
});
const html = await readFile(new URL('gpt6-celestial/index.html', root), 'utf8');
if (!html.includes('CUT 02') || !html.includes('window.CelestialFilm')) {
  throw new Error('Expected the self-contained CUT 02 film');
}
// Explicit publication list: source, verification notes and earlier cuts stay out of Pages.
const dist = new URL('dist/', root);
await rm(dist, { recursive: true, force: true });
await mkdir(dist, { recursive: true });
await writeFile(new URL('index.html', dist), html);
await copyFile(new URL('celestial-cover.svg', root), new URL('celestial-cover.svg', dist));
console.log('Published files prepared: index.html, celestial-cover.svg');
