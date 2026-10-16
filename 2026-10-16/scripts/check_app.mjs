import {readFile,stat} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {validateDataset} from '../app/src/model.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const app=path.join(root,'app');
const history=await readFile(path.join(app,'data/history.json'));
validateDataset(JSON.parse(history));
const eventData=JSON.parse(history).events;
const editorial=JSON.parse(await readFile(path.join(app,'data/editorial.json'),'utf8'));
if(editorial.version!==1||eventData.some(e=>typeof editorial.events?.[e.id]?.summary!=='string'||typeof editorial.events[e.id].locator!=='string'))throw new Error('Event explanations incomplete');
const provenance=JSON.parse(await readFile(path.join(app,'data/provenance.json'),'utf8'));
if(createHash('sha256').update(history).digest('hex')!==provenance.derived_history_sha256)throw new Error('Data provenance hash mismatch');
for(const name of ['app.mjs','model.mjs','charts.mjs']){
  const result=spawnSync(process.execPath,['--check',path.join(app,'src',name)],{encoding:'utf8'});
  if(result.status!==0)throw new Error(result.stderr);
}
const html=await readFile(path.join(app,'index.html'),'utf8');
for(const match of html.matchAll(/(?:src|href)="(\.\/[^"?#]+)"/g))await stat(path.join(app,match[1]));
for(const image of ['teacher-desk.png','rural-day.png','city-home.png']){
  const bytes=await readFile(path.join(app,'assets/art',image));
  if(bytes.toString('hex',0,8)!=='89504e470d0a1a0a')throw new Error(`Invalid PNG ${image}`);
}
const d3=await readFile(path.join(app,'vendor/d3.min.js'),'utf8');
if(!d3.includes('v7.9.0'))throw new Error('Unexpected D3 version');
await stat(path.join(app,'vendor/D3-LICENSE.txt'));
for(const file of ['index.html','src/app.mjs','src/charts.mjs','src/style.css']){
  const content=await readFile(path.join(app,file),'utf8');
  if(/(?:src|href)=["']https?:\/\//.test(content))throw new Error(`Remote dependency in ${file}`);
}
console.log('Data, provenance, syntax, local assets and D3 license/version: passed');
