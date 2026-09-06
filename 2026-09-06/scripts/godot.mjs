import {spawnSync,spawn} from 'node:child_process';
import {existsSync,mkdirSync,copyFileSync} from 'node:fs';
import path from 'node:path';
const root=path.resolve(import.meta.dirname,'..');
const version='4.7.2';
const bundled=process.platform==='darwin'?'/Applications/Godot.app/Contents/MacOS/Godot':path.join(root,'.cache/Godot_v4.7.2-stable_linux.x86_64');
const executable=process.env.GODOT_BIN||(existsSync(bundled)?bundled:'godot');
const info=spawnSync(executable,['--version'],{encoding:'utf8'});
if(info.status!==0||!info.stdout.startsWith(version+'.stable'))throw new Error(`Godot ${version}.stable required. Run npm run setup or set GODOT_BIN.`);
const command=process.argv[2];
const project=path.join(root,'game');
mkdirSync(path.join(root,'dist'),{recursive:true});mkdirSync(path.join(root,'builds/macos'),{recursive:true});
const modes={import:['--editor','--import','--quit'],test:['--script','res://tests/run.gd'],ui:['--script','res://tests/ui.gd'],flow:['--script','res://tests/shopping_flow.gd'],campaign:['--script','res://tests/campaign.gd'],city:['--script','res://tests/city.gd'],stories:['--script','res://tests/stories.gd'],circulation:['--script','res://tests/circulation.gd'],balance:['--script','res://tests/balance.gd'],build:['--export-release','Web'],debug:['--export-debug','Web'],mac:['--export-release','macOS']};
if(command==='editor'){
 const child=spawn(executable,['--path',project,'--editor'],{stdio:'ignore',detached:true});child.unref();
}else{
 if(!modes[command])throw Error('Unknown command');
 const args=['--headless','--path',project,...modes[command],...(process.argv.length>3?['--',...process.argv.slice(3)]:[])];
 let result;let invalidOutput=false;
 if(command==='balance'){
  let tail='';
  const status=await new Promise((resolve,reject)=>{
   const child=spawn(executable,args,{stdio:['ignore','pipe','pipe']});
   const receive=(chunk)=>{process.stdout.write(chunk);tail=(tail+chunk.toString()).slice(-65536);invalidOutput ||= /(?:SCRIPT ERROR|ERROR:)/.test(tail);};
   child.stdout.on('data',receive);child.stderr.on('data',receive);child.on('error',reject);child.on('close',resolve);
  });
  result={status,stdout:tail,stderr:''};
 }else result=spawnSync(executable,args,{encoding:'utf8',maxBuffer:20*1024*1024});
 const output=(result.stdout||'')+(result.stderr||'');
 if(result.status!==0||invalidOutput||/(?:SCRIPT ERROR|ERROR:)/.test(output)){if(command!=='balance')process.stderr.write(output);process.exit(1);}
 if(['build','debug'].includes(command))copyFileSync(path.join(root,'art/cover.png'),path.join(root,'dist/machiakari-cover.png'));
 if(['test','balance','ui','circulation','stories','city','campaign','flow'].includes(command)){if(command!=='balance')process.stdout.write(output);}
 else console.log(`Godot ${version}: ${command} passed`);

}
