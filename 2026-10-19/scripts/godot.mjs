import {spawn,spawnSync} from 'node:child_process';
import {mkdirSync,copyFileSync} from 'node:fs';
import path from 'node:path';
import {root,engineBinary,version} from './engine.mjs';
const bin=engineBinary();
const mode=process.argv[2];
const project=path.join(root,'game');
if(mode==='editor'||mode==='play'){
 const child=spawn(bin,['--path',project,...(mode==='editor'?['--editor']:[])],{stdio:'inherit'});
 child.on('error',error=>{console.error(error);process.exitCode=1;});
 child.on('exit',code=>process.exit(code??1));
}else{
 const modes={import:['--editor','--import','--quit'],test:['--script','res://tests/run.gd'],build:['--export-release','Web']};
 if(!modes[mode])throw new Error('Unknown Godot mode: '+mode);
 mkdirSync(path.join(root,'dist'),{recursive:true});
 const tasks=mode==='test'?['run','profile_run','ui_run','audio_run','asset_run','renderer_geometry_run', 'renderer_cache_run'].map(name=>['--script','res://tests/'+name+'.gd']):[modes[mode]];
 for(const task of tasks){
  const result=spawnSync(bin,['--headless','--path',project,...task],{encoding:'utf8',maxBuffer:30*1024*1024});
  const output=(result.stdout||'')+(result.stderr||'');
  if(result.status!==0||/(?:SCRIPT ERROR|ERROR:|FAIL:)/.test(output)){process.stderr.write(output);process.exit(1);}
  if(mode==='test')process.stdout.write(output);
 }
 if(mode==='test'){
  const result=spawnSync(process.execPath,[path.join(project,'tests/snapshot_bridge.mjs')],{encoding:'utf8'});
  if(result.status!==0){process.stderr.write((result.stdout||'')+(result.stderr||''));process.exit(1);}
  process.stdout.write(result.stdout||'');
 }
 if(mode!=='test')console.log('Godot '+version+': '+mode+' passed');
 if(mode==='build'){
  const dist=path.join(root,'dist');
  mkdirSync(path.join(dist,'licenses'),{recursive:true});
  for(const [from,to] of [['credits.html','credits.html'],['docs/licenses/GODOT-LICENSE.txt','licenses/GODOT-LICENSE.txt'],['game/assets/fonts/LICENSE.txt','licenses/NOTO-OFL.txt'],['game/assets/fonts/ZEN-OFL.txt','licenses/ZEN-OFL.txt'],['public/echo-witch-cover.png','echo-witch-cover.png']])copyFileSync(path.join(root,from),path.join(dist,to));
 }
}
