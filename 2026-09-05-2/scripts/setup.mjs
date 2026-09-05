// Reproducible official Godot runtime/templates for local development and CI.
import {spawnSync} from 'node:child_process';
import {existsSync,mkdirSync,copyFileSync,chmodSync} from 'node:fs';
import path from 'node:path';
import os from 'node:os';
const root=path.resolve(import.meta.dirname,'..');const cache=path.join(root,'.cache');mkdirSync(cache,{recursive:true});
const base='https://github.com/godotengine/godot/releases/download/4.7.2-stable/';
function run(bin,args){const r=spawnSync(bin,args,{stdio:'inherit'});if(r.status!==0)throw Error(`${bin} failed`);}
if(process.platform==='linux'){
 const name='Godot_v4.7.2-stable_linux.x86_64';
 if(!existsSync(path.join(cache,name))){run('curl',['-fL','--retry','2',base+name+'.zip','-o',path.join(cache,'godot.zip')]);run('unzip',['-o',path.join(cache,'godot.zip'),'-d',cache]);chmodSync(path.join(cache,name),0o755);}
}
const templates=process.platform==='darwin'?path.join(os.homedir(),'Library/Application Support/Godot/export_templates/4.7.2.stable'):path.join(process.env.XDG_DATA_HOME||path.join(os.homedir(),'.local/share'),'godot/export_templates/4.7.2.stable');
const names=['macos.zip','web_nothreads_debug.zip','web_nothreads_release.zip','version.txt'];
if(!names.every(n=>existsSync(path.join(templates,n)))){
 const archive=path.join(cache,'templates.tpz');
 if(!existsSync(archive))run('curl',['-fL','--retry','2',base+'Godot_v4.7.2-stable_export_templates.tpz','-o',archive]);
 run('unzip',['-o',archive,...names.map(n=>'templates/'+n),'-d',cache]);mkdirSync(templates,{recursive:true});
 for(const n of names)copyFileSync(path.join(cache,'templates',n),path.join(templates,n));
}
console.log('Godot 4.7.2 Web/macOS templates ready. On macOS, install the official Godot 4.7.2 app separately if missing.');
