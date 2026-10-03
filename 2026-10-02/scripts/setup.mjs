// Reproducible official Godot runtime/templates for local development and CI.
import {spawnSync} from 'node:child_process';
import {existsSync,mkdirSync,copyFileSync,chmodSync} from 'node:fs';
import path from 'node:path';
import os from 'node:os';
const root=path.resolve(import.meta.dirname,'..');const cache=path.join(root,'.cache');mkdirSync(cache,{recursive:true});
const base='https://github.com/godotengine/godot/releases/download/4.7.2-stable/';
function run(bin,args){const r=spawnSync(bin,args,{stdio:'inherit'});if(r.status!==0)throw Error(`${bin} failed`);}
if(process.platform==='linux'&&!process.env.GODOT_BIN){
 const name='Godot_v4.7.2-stable_linux.x86_64';
 if(!existsSync(path.join(cache,name))){run('curl',['-fL','--retry','2',base+name+'.zip','-o',path.join(cache,'godot.zip')]);run('unzip',['-o',path.join(cache,'godot.zip'),'-d',cache]);chmodSync(path.join(cache,name),0o755);}
}
let engineData=null;
if(process.env.GODOT_BIN){const probe=spawnSync(process.env.GODOT_BIN,['--headless','--script',path.join(root,'scripts/paths.gd')],{encoding:'utf8'});engineData=probe.stdout?.match(/DATA_HOME=(.+)/)?.[1]?.trim();}
const templates=engineData?path.join(engineData,process.platform==='darwin'?'Godot':'godot','export_templates/4.7.2.stable'):process.platform==='darwin'?path.join(os.homedir(),'Library/Application Support/Godot/export_templates/4.7.2.stable'):path.join(process.env.XDG_DATA_HOME||path.join(os.homedir(),'.local/share'),'godot/export_templates/4.7.2.stable');
const names=['macos.zip','linux_release.x86_64','windows_release_x86_64.exe','web_nothreads_debug.zip','web_nothreads_release.zip','version.txt'];
if(!names.every(n=>existsSync(path.join(templates,n)))){
 const archive=path.join(cache,'templates.tpz');
 if(!existsSync(archive))run('curl',['-fL','--retry','2',base+'Godot_v4.7.2-stable_export_templates.tpz','-o',archive]);
 run('unzip',['-o',archive,...names.map(n=>'templates/'+n),'-d',cache]);mkdirSync(templates,{recursive:true});
 for(const n of names)copyFileSync(path.join(cache,'templates',n),path.join(templates,n));
}
console.log('Godot 4.7.2 Web/macOS templates ready. On macOS, install the official Godot 4.7.2 app separately if missing.');

// Audio regression checks require NumPy; keep any install local to the app.
const systemPython=process.env.PYTHON_BIN||'python3';
const numpy=spawnSync(systemPython,['-c','import numpy; assert numpy.__version__ == "2.3.5"'],{stdio:'ignore'});
if(numpy.status!==0){
 const venv=path.join(cache,'python');
 const python=path.join(venv,process.platform==='win32'?'Scripts/python.exe':'bin/python');
 if(!existsSync(python))run(systemPython,['-m','venv',venv]);
 run(python,['-m','pip','install','--disable-pip-version-check','-r',path.join(root,'requirements.txt')]);
}
