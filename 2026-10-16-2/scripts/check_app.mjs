import {readFile,stat} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
for(const file of ['src/app.mjs','src/model.mjs','src/art.mjs']){
  const result=spawnSync(process.execPath,['--check',path.join(root,'app',file)],{encoding:'utf8'});
  if(result.status!==0)throw new Error(result.stderr);
}
const html=await readFile(path.join(root,'app/index.html'),'utf8');
for(const match of html.matchAll(/(?:src|href)="(\.\/[^"?#]+)"/g))await stat(path.join(root,'app',match[1]));
if(/(?:src|href)=["']https?:\/\//.test(html))throw new Error('Remote runtime dependency');
for(const file of ['index.html','src/app.mjs','src/style.css']){
  const content=await readFile(path.join(root,'app',file),'utf8');
  if(/(?:CDN|localhost|adoption|prototype|台帳|正本|APIキー)/.test(content))throw new Error(`Internal wording in UI: ${file}`);
}
console.log('Game syntax, local assets and reader-facing interface: passed');
