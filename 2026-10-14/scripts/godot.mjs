import {spawn,spawnSync} from 'node:child_process';
import {existsSync,mkdirSync,copyFileSync} from 'node:fs';
import path from 'node:path';
const root=path.resolve(import.meta.dirname,'..');
const bundled=path.join(root,'.cache/Godot_v4.6.3-stable_linux.x86_64');
const binary=process.env.GODOT_BIN||(existsSync(bundled)?bundled:'godot');
const version=spawnSync(binary,['--version'],{encoding:'utf8'});
if(version.status!==0||!version.stdout.startsWith('4.6.3.stable'))throw Error('Godot 4.6.3 is required. Run npm run setup or set GODOT_BIN.');
const mode=process.argv[2];
const project=path.join(root,'game');
if(mode==='editor'||mode==='play'){
 const child=spawn(binary,['--path',project,...(mode==='editor'?['--editor']:[])],{stdio:'inherit'});
 child.on('exit',code=>process.exit(code||0));
}else{
 const modes={import:['--editor','--import','--quit'],test:['--script','res://tests/run.gd'],build:['--export-release','Web']};
 if(!modes[mode])throw Error('Unknown Godot command');
 mkdirSync(path.join(root,'dist'),{recursive:true});
 const result=spawnSync(binary,['--headless','--path',project,...modes[mode]],{encoding:'utf8',maxBuffer:30*1024*1024});
 const output=(result.stdout||'')+(result.stderr||'');
 if(result.status!==0||/(?:SCRIPT ERROR|ERROR:|FAIL:)/.test(output)){process.stderr.write(output);process.exit(1);}
 if(mode==='test')process.stdout.write(output);else console.log(`Godot 4.6.3: ${mode} passed`);
	if(mode==='build'){
	 const dist=path.join(root,'dist');
	 mkdirSync(path.join(dist,'licenses'),{recursive:true});
	 copyFileSync(path.join(root,'public/zenryoku-taikin-cover.png'),path.join(dist,'zenryoku-taikin-cover.png'));
	 for(const [from,to] of [['docs/licenses/GODOT-LICENSE.txt','licenses/GODOT-LICENSE.txt'],['game/assets/fonts/LICENSE.txt','licenses/NOTO-OFL.txt'],['credits.html','credits.html'],['THIRD_PARTY_NOTICES.md','THIRD_PARTY_NOTICES.md']])copyFileSync(path.join(root,from),path.join(dist,to));
	}
}
