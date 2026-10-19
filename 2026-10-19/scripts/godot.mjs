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
 const result=spawnSync(bin,['--headless','--path',project,...modes[mode]],{encoding:'utf8',maxBuffer:30*1024*1024});
 const output=(result.stdout||'')+(result.stderr||'');
 if(result.status!==0||/(?:SCRIPT ERROR|ERROR:|FAIL:)/.test(output)){process.stderr.write(output);process.exit(1);}
 if(mode==='test')process.stdout.write(output);else console.log('Godot '+version+': '+mode+' passed');
 if(mode==='build'){
  const dist=path.join(root,'dist');
  mkdirSync(path.join(dist,'licenses'),{recursive:true});
  for(const [from,to] of [['credits.html','credits.html'],['docs/licenses/GODOT-LICENSE.txt','licenses/GODOT-LICENSE.txt'],['game/assets/fonts/LICENSE.txt','licenses/NOTO-OFL.txt'],['public/echo-witch-cover.svg','echo-witch-cover.svg']])copyFileSync(path.join(root,from),path.join(dist,to));
 }
}
