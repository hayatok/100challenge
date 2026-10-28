import {spawn, spawnSync} from 'node:child_process';
import {existsSync, mkdirSync, copyFileSync} from 'node:fs';
import path from 'node:path';
const root=path.resolve(import.meta.dirname,'..');
const local='/Applications/Godot.app/Contents/MacOS/Godot';
const bundled=path.join(root,'.cache/Godot_v4.7.2-stable_linux.x86_64');
const binary=process.env.GODOT_BIN || (existsSync(bundled)?bundled:existsSync(local)?local:'godot');
const v=spawnSync(binary,['--version'],{encoding:'utf8'});
if(v.status!==0 || !v.stdout.startsWith('4.7.2.stable')) throw Error('Godot 4.7.2 required. Run npm run setup or set GODOT_BIN.');
const mode=process.argv[2], project=path.join(root,'game');
if(mode==='editor'||mode==='play') {
  const child=spawn(binary,['--path',project,...(mode==='editor'?['--editor']:[])],{stdio:'inherit'});
  child.on('exit',code=>process.exit(code||0));
} else {
  const args={presentation:['--script','res://tests/presentation_v05_test.gd'], tactical:['--script','res://tests/tactical_test.gd'], import:['--editor','--import','--quit'], test:['--script','res://tests/rules_test.gd'], ui:['--script','res://tests/ui_test.gd','--','--qa'], build:['--export-release','Web']};
  if(!args[mode]) throw Error('Unknown Godot mode');
  mkdirSync(path.join(root,'dist'),{recursive:true});
  const suites=mode==='test'?[args.test,args.tactical,args.presentation]:[args[mode]];
  for(const suite of suites) {
    const r=spawnSync(binary,['--headless','--path',project,...suite],{encoding:'utf8',maxBuffer:32*1024*1024,timeout:300000});
    const output=(r.stdout||'')+(r.stderr||'');
    process.stdout.write(output);
    if(r.error || r.status!==0 || /(?:SCRIPT ERROR|ERROR:|FAIL:)/.test(output)) process.exit(1);
  }
  if(mode==='build') {
    copyFileSync(path.join(project,'assets/art/r2/harbor-day.png'),path.join(root,'dist/shiogaeri-cover.png'));
    copyFileSync(path.join(project,'assets/fonts/NOTO-OFL.txt'),path.join(root,'dist/NOTO-OFL.txt'));
    copyFileSync(path.join(root,'THIRD_PARTY_NOTICES.md'),path.join(root,'dist/THIRD_PARTY_NOTICES.md'));
    for(const name of ['GODOT-LICENSE.txt','GODOT-COPYRIGHT.txt']) copyFileSync(path.join(root,name),path.join(root,'dist',name));
  }
}
