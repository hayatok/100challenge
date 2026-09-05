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
const modes={import:['--editor','--import','--quit'],test:['--script','res://tests/run.gd'],build:['--export-release','Web'],debug:['--export-debug','Web'],mac:['--export-release','macOS']};
if(command==='editor'){
 const child=spawn(executable,['--path',project,'--editor'],{stdio:'ignore',detached:true});child.unref();
}else{
 if(!modes[command])throw Error('Unknown command');
 const result=spawnSync(executable,['--headless','--path',project,...modes[command]],{encoding:'utf8',maxBuffer:20*1024*1024});
 const output=(result.stdout||'')+(result.stderr||'');
 if(result.status!==0||/(?:SCRIPT ERROR|ERROR:)/.test(output)){process.stderr.write(output);process.exit(1);}
 if(['test','benchmark'].includes(command))process.stdout.write(output);
 else console.log(`Godot ${version}: ${command} passed`);
 if(['build','debug'].includes(command))copyFileSync(path.join(project,'assets/images/key-art.png'),path.join(root,'dist/loop-eater-cover.png'));
}
