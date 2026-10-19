import {spawnSync} from 'node:child_process';
import {existsSync,mkdirSync,copyFileSync,readFileSync,chmodSync} from 'node:fs';
import {createHash} from 'node:crypto';
import os from 'node:os';
import path from 'node:path';
import {root,version,engineBinary} from './engine.mjs';
const cache=path.join(root,'.cache');
mkdirSync(cache,{recursive:true});
const base='https://github.com/godotengine/godot/releases/download/'+version+'-stable/';
function run(bin,args){const result=spawnSync(bin,args,{stdio:'inherit'});if(result.status!==0)throw new Error(bin+' failed');}
function download(name){
 const target=path.join(cache,name);
 if(!existsSync(target))run('curl',['-fL','--retry','2',base+name,'-o',target]);
 const sums=path.join(cache,'SHA512-SUMS.txt');
 if(!existsSync(sums))run('curl',['-fL','--retry','2',base+'SHA512-SUMS.txt','-o',sums]);
 const line=readFileSync(sums,'utf8').split(/\r?\n/).find(x=>x.trim().endsWith(name));
 const expected=line?.trim().split(/\s+/)[0];
 const actual=createHash('sha512').update(readFileSync(target)).digest('hex');
 if(!expected||expected!==actual)throw new Error('Official checksum mismatch for '+name);
 return target;
}
try{engineBinary();}catch(error){
 if(process.env.GODOT_BIN||process.platform!=='linux'||process.arch!=='x64')throw error;
 const name='Godot_v'+version+'-stable_linux.x86_64';
 run('unzip',['-oq',download(name+'.zip'),'-d',cache]);
 chmodSync(path.join(cache,name),0o755);
 engineBinary();
}
const userData=process.platform==='darwin'?path.join(os.homedir(),'Library/Application Support'):process.platform==='win32'?(process.env.APPDATA||path.join(os.homedir(),'AppData/Roaming')):(process.env.XDG_DATA_HOME||path.join(os.homedir(),'.local/share'));
const templates=path.join(userData,process.platform==='linux'?'godot':'Godot','export_templates/'+version+'.stable');
const names=['web_nothreads_debug.zip','web_nothreads_release.zip','version.txt'];
if(!names.every(name=>existsSync(path.join(templates,name)))){
 const archive=download('Godot_v'+version+'-stable_export_templates.tpz');
 run('unzip',['-oq',archive,...names.map(name=>'templates/'+name),'-d',cache]);
 mkdirSync(templates,{recursive:true});
 for(const name of names)copyFileSync(path.join(cache,'templates',name),path.join(templates,name));
}
console.log('Godot '+version+' and single-thread Web templates are ready.');
