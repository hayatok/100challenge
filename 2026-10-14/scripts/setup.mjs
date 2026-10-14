import {spawnSync} from 'node:child_process';
import {existsSync,mkdirSync,copyFileSync,chmodSync} from 'node:fs';
import path from 'node:path';
import os from 'node:os';
const root=path.resolve(import.meta.dirname,'..');
const cache=path.join(root,'.cache');mkdirSync(cache,{recursive:true});
function run(binary,args){const r=spawnSync(binary,args,{stdio:'inherit'});if(r.status!==0)throw Error(`${binary} failed`);}
const configured=process.env.GODOT_BIN||'godot';
const version=spawnSync(configured,['--version'],{encoding:'utf8'});
const base='https://github.com/godotengine/godot/releases/download/4.6.3-stable/';
if(!version.stdout?.startsWith('4.6.3.stable')){
 if(process.env.GODOT_BIN)throw Error('GODOT_BIN must point to Godot 4.6.3.');
 if(process.platform!=='linux')throw Error('Install official Godot 4.6.3 for your system and set GODOT_BIN.');
 const name='Godot_v4.6.3-stable_linux.x86_64';
 if(!existsSync(path.join(cache,name))){run('curl',['-fsSL','--retry','2',base+name+'.zip','-o',path.join(cache,'godot.zip')]);run('unzip',['-oq',path.join(cache,'godot.zip'),'-d',cache]);chmodSync(path.join(cache,name),0o755);}
}
const templates=process.platform==='darwin'?path.join(os.homedir(),'Library/Application Support/Godot/export_templates/4.6.3.stable'):process.platform==='win32'?path.join(process.env.APPDATA||path.join(os.homedir(),'AppData/Roaming'),'Godot/export_templates/4.6.3.stable'):path.join(process.env.XDG_DATA_HOME||path.join(os.homedir(),'.local/share'),'godot/export_templates/4.6.3.stable');
const names=['web_nothreads_debug.zip','web_nothreads_release.zip','version.txt'];
if(!names.every(name=>existsSync(path.join(templates,name)))){
 const archive=path.join(cache,'templates.tpz');
 if(!existsSync(archive))run('curl',['-fsSL','--retry','2',base+'Godot_v4.6.3-stable_export_templates.tpz','-o',archive]);
 run('unzip',['-oq',archive,...names.map(name=>'templates/'+name),'-d',cache]);mkdirSync(templates,{recursive:true});
 for(const name of names)copyFileSync(path.join(cache,'templates',name),path.join(templates,name));
}
console.log('Godot 4.6.3 and single-thread Web export templates ready.');
