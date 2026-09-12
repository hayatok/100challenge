import {spawnSync,spawn} from 'node:child_process';
import {existsSync,mkdirSync} from 'node:fs';
import path from 'node:path';
const root=path.resolve(import.meta.dirname,'..');
const bundled=process.platform==='darwin'?'/Applications/Godot.app/Contents/MacOS/Godot':path.join(root,'.cache/Godot_v4.7.2-stable_linux.x86_64');
const executable=process.env.GODOT_BIN||(existsSync(bundled)?bundled:'godot');
const info=spawnSync(executable,['--version'],{encoding:'utf8'});
if(info.status!==0||!info.stdout.startsWith('4.7.2.stable'))throw Error('Godot 4.7.2 required. Run npm run setup.');
const command=process.argv[2],project=path.join(root,'game');
mkdirSync(path.join(root,'dist'),{recursive:true});
if(['editor','play'].includes(command)){
 const child=spawn(executable,['--path',project,...(command==='editor'?['--editor']:[])],{stdio:'ignore',detached:true});child.unref();
}else{
 const modes={import:['--editor','--import','--quit'],test:['--fixed-fps','60','--script','res://tests/run.gd'],playtest:['--fixed-fps','60','--script','res://tests/playthrough.gd'],build:['--export-release','Web']};
 if(!modes[command])throw Error('Unknown command');
 const result=spawnSync(executable,['--headless','--path',project,...modes[command]],{encoding:'utf8',maxBuffer:20*1024*1024});
 const output=(result.stdout||'')+(result.stderr||'');
 if(result.status!==0||/(?:SCRIPT ERROR|ERROR:)/.test(output)){process.stderr.write(output);process.exit(1);}
 console.log(['test','playtest'].includes(command)?output:`Godot 4.7.2: ${command} passed`);
}
