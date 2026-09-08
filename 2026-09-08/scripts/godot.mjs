import {spawnSync,spawn} from 'node:child_process';
import {existsSync,mkdirSync,copyFileSync} from 'node:fs';
import path from 'node:path';
const root=path.resolve(import.meta.dirname,'..');
const bundled=process.platform==='darwin'?'/Applications/Godot.app/Contents/MacOS/Godot':path.join(root,'.cache/Godot_v4.7.2-stable_linux.x86_64');
const executable=process.env.GODOT_BIN||(existsSync(bundled)?bundled:'godot');
const info=spawnSync(executable,['--version'],{encoding:'utf8'});
if(info.status!==0||!info.stdout.startsWith('4.7.2.stable'))throw Error('Godot 4.7.2 required. Run npm run setup.');
const command=process.argv[2];const project=path.join(root,'game');
for(const p of ['dist'])mkdirSync(path.join(root,p),{recursive:true});
const modes={import:['--editor','--import','--quit'],test:['--fixed-fps','120','--script','res://tests/run.gd'],ui:['--fixed-fps','120','--script','res://tests/ui.gd'],build:['--export-release','Web'],debug:['--export-debug','Web']};
if(command==='editor'||command==='play'){
 const child=spawn(executable,['--path',project,...(command==='editor'?['--editor']:[])],{stdio:'ignore',detached:true});child.unref();
}else{
 if(!modes[command])throw Error('Unknown command');
 const result=spawnSync(executable,['--headless','--path',project,...modes[command]],{encoding:'utf8',maxBuffer:20*1024*1024});
 const output=(result.stdout||'')+(result.stderr||'');
 if(result.status!==0||/(?:SCRIPT ERROR|ERROR:)/.test(output)){process.stderr.write(output);process.exit(1);}
 console.log(['test','ui'].includes(command)?output:`Godot 4.7.2: ${command} passed`);
 if(['build','debug'].includes(command))copyFileSync(path.join(root,'cover.svg'),path.join(root,'dist/rescue-cover.svg'));
}
