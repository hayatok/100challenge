import {spawnSync} from 'node:child_process';
import {existsSync,mkdirSync,copyFileSync,chmodSync} from 'node:fs';
import path from 'node:path';
import os from 'node:os';
const root=path.resolve(import.meta.dirname,'..'),cache=path.join(root,'.cache');
mkdirSync(cache,{recursive:true});
const base='https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/';
function run(cmd,args){const r=spawnSync(cmd,args,{stdio:'inherit'});if(r.status!==0)throw Error(`${cmd} failed`);}
const mac='/Applications/Godot.app/Contents/MacOS/Godot';
const configured=process.env.GODOT_BIN || (existsSync(mac)?mac:'godot');
const v=spawnSync(configured,['--version'],{encoding:'utf8'});
if(!v.stdout?.startsWith('4.7.2.stable')) {
  if(process.env.GODOT_BIN||process.platform!=='linux')throw Error('Install Godot 4.7.2 and set GODOT_BIN.');
  const name='Godot_v4.7.2-stable_linux.x86_64';
  if(!existsSync(path.join(cache,name))){run('curl',['-fsSL','--retry','2',base+name+'.zip','-o',path.join(cache,'godot.zip')]);run('unzip',['-oq',path.join(cache,'godot.zip'),'-d',cache]);chmodSync(path.join(cache,name),0o755);}
}
const data=process.platform==='darwin'?path.join(os.homedir(),'Library/Application Support'):process.platform==='win32'?(process.env.APPDATA||path.join(os.homedir(),'AppData/Roaming')):(process.env.XDG_DATA_HOME||path.join(os.homedir(),'.local/share'));
const engineDataDir=process.platform==='linux'?'godot':'Godot';
const templates=path.join(data,engineDataDir,'export_templates/4.7.2.stable');
const names=['web_nothreads_debug.zip','web_nothreads_release.zip','version.txt'];
if(!names.every(n=>existsSync(path.join(templates,n)))) {
  const archive=path.join(cache,'templates.tpz');
  if(!existsSync(archive))run('curl',['-fsSL','--retry','2',base+'Godot_v4.7.2-stable_export_templates.tpz','-o',archive]);
  run('unzip',['-oq',archive,...names.map(n=>'templates/'+n),'-d',cache]);
  mkdirSync(templates,{recursive:true});for(const n of names)copyFileSync(path.join(cache,'templates',n),path.join(templates,n));
}
console.log('Godot 4.7.2 and Web templates ready.');
