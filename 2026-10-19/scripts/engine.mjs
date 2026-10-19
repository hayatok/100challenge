import {spawnSync} from 'node:child_process';
import {existsSync} from 'node:fs';
import path from 'node:path';
export const root=path.resolve(import.meta.dirname,'..');
export const version='4.7.2';
export function engineBinary(){
 const candidates=process.env.GODOT_BIN?[process.env.GODOT_BIN]:[path.join(root,'.cache/Godot_v4.7.2-stable_linux.x86_64'),...(process.platform==='darwin'?['/Applications/Godot.app/Contents/MacOS/Godot']:[]),'godot'];
 for(const bin of candidates){
  if(bin.includes(path.sep)&&!existsSync(bin))continue;
  const check=spawnSync(bin,['--version'],{encoding:'utf8'});
  if(check.status===0&&check.stdout.startsWith(version+'.stable'))return bin;
 }
 throw new Error('Godot '+version+' is required. Run npm run setup or set GODOT_BIN.');
}
