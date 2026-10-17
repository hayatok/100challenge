import { readFile, readdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import { validateEducation } from '../app/src/education-data.js';
import { mergeHistory } from '../app/src/history-data.js';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const app = path.join(root, 'app');
const html = await readFile(path.join(app, 'index.html'), 'utf8');
for (const match of html.matchAll(/(?:src|href)="(\.\/[^"#]+)"/g)) await readFile(path.resolve(app, match[1]));
for (const file of await readdir(path.join(app, 'src'))) if (/\.(?:m?js)$/.test(file)) execFileSync(process.execPath, ['--check', path.join(app, 'src', file)], { stdio: 'inherit' });
for (const file of await readdir(path.join(root, 'scripts'))) if (/\.mjs$/.test(file)) execFileSync(process.execPath, ['--check', path.join(root, 'scripts', file)], { stdio: 'inherit' });
const archive = JSON.parse(await readFile(path.join(app, 'data/archive.json'), 'utf8'));
if (archive.sources.length !== 259 || archive.series.length !== 557 || archive.counts.observations !== 15728) throw new Error('The full research archive must remain available.');
if (/\bon\w+=|<script[^>]*>[^<\s]/i.test(html)) throw new Error('Use separate scripts with the local CSP.');
for (const source of archive.sources) if (source.url && !/^https?:\/\//.test(source.url)) throw new Error(`Unexpected source URL: ${source.id}`);
console.log('Local HTML, scripts, archive and asset references verified.');

const readJSON=async name=>JSON.parse(await readFile(path.join(app,`data/${name}.json`),'utf8'));
const [lessons,media,expansion]=await Promise.all(['lessons','media','history-expanded'].map(readJSON));
validateEducation(lessons,media,mergeHistory(archive,expansion));
for(const photo of media.items){
  const bytes=await readFile(path.resolve(app,photo.src));
  if(bytes[0]!==255||bytes[1]!==216||bytes.length>1024*1024||!photo.width||!photo.height)throw new Error('Invalid bundled photo');
}
const scripts=await readdir(path.join(app,'src'));
for(const file of ['model.js','renderer.js','era-art.js','routines.js','life-scenes.js'])if(scripts.includes(file))throw new Error('Retired game code must not ship.');
console.log('Eight chapters, licensed photos and educational data references verified; retired game code absent.');
