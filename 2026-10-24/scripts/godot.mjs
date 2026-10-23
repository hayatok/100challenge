import {spawnSync,spawn} from 'node:child_process';
import {mkdirSync,readFileSync,writeFileSync,cpSync,readdirSync,rmSync,mkdtempSync,renameSync} from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
const root=path.resolve(import.meta.dirname,'..');
const binary=process.env.GODOT_BIN||'/Applications/Godot.app/Contents/MacOS/Godot';
const info=spawnSync(binary,['--version'],{encoding:'utf8'});
if(info.status!==0||!info.stdout.startsWith('4.7.2.stable.')) throw Error('Godot 4.7.2.stable required; set GODOT_BIN to its executable.');
const mode=process.argv[2];
const modes={import:['--editor','--import','--quit'],test:['--script','res://tests/run.gd'],route:['--script','res://tests/route.gd'],web:['--export-release','Web'],mac:['--export-release','macOS']};
const args=['--path',path.join(root,'game')];
const sha256=data=>createHash('sha256').update(data).digest('hex');
function run(command,argv,options={}){
 const result=spawnSync(command,argv,{encoding:'utf8',maxBuffer:30*1024*1024,...options});
 const output=(result.stdout||'')+(result.stderr||'');
 if(result.status!==0||result.error)throw Error(`${command} failed (${result.status}): ${output}${result.error||''}`);
 return output;
}
function exportLicenses(destination){
 const output=run(binary,['--headless',...args,'--script',path.join(root,'scripts/export_licenses.gd'),'--','--licenses-dir',destination]);
 if(/(?:SCRIPT ERROR|ERROR:)/.test(output))throw Error(output);
 for(const file of ['GODOT_LICENSE.txt','GODOT_COPYRIGHT.txt','NOTO_OFL.txt','NOTICES.txt','index.html']){
  if(!readFileSync(path.join(destination,file),'utf8').trim())throw Error(`Empty license output: ${file}`);
 }
}
function packageMac(){
 const builds=path.join(root,'builds');
 const stage=mkdtempSync(path.join(builds,'.mac-notices-'));
 const archive=path.join(builds,'TENSAI.zip');
 const temporaryArchive=path.join(stage,'TENSAI-signed.zip');
 try{
  // ditto preserves Unicode bundle names and macOS archive metadata.
  run('ditto',['-x','-k',archive,stage]);
  const bundles=readdirSync(stage,{withFileTypes:true}).filter(entry=>entry.isDirectory()&&entry.name.endsWith('.app'));
  if(bundles.length!==1)throw Error('Expected exactly one exported .app bundle');
  const app=path.join(stage,bundles[0].name);
  exportLicenses(path.join(app,'Contents/Resources/licenses'));
  run('codesign',['--force','--deep','--sign','-',app]);
  run('codesign',['--verify','--deep','--strict','--verbose=2',app]);
  run('ditto',['-c','-k','--sequesterRsrc','--keepParent',app,temporaryArchive]);
  // Verify the repackaged bytes, rather than only the pre-archive directory.
  const verification=path.join(stage,'verify');mkdirSync(verification);
  run('ditto',['-x','-k',temporaryArchive,verification]);
  const verifiedApp=path.join(verification,bundles[0].name);
  run('codesign',['--verify','--deep','--strict','--verbose=2',verifiedApp]);
  for(const name of ['GODOT_LICENSE.txt','GODOT_COPYRIGHT.txt','NOTO_OFL.txt','NOTICES.txt']){
   const a=readFileSync(path.join(app,'Contents/Resources/licenses',name));
   const b=readFileSync(path.join(verifiedApp,'Contents/Resources/licenses',name));
   if(!a.equals(b))throw Error(`Packaged notice differs: ${name}`);
  }
  const destination=path.join(builds,bundles[0].name);
  rmSync(destination,{recursive:true,force:true});cpSync(app,destination,{recursive:true});
  renameSync(temporaryArchive,archive);
  writeFileSync(path.join(builds,'README-LICENSES.txt'),`TENSAI licenses\n\nExtract TENSAI.zip. In Finder, select ${bundles[0].name} and choose Show Package Contents.\nRead Contents/Resources/licenses/index.html or the adjacent plain text files.\nThe bundle contains Godot MIT, complete engine component copyright/license texts, and Noto SIL OFL notices.\n\nThis build is ad-hoc signed for local testing; it is not Developer ID signed or notarized.\n`);
 }finally{rmSync(stage,{recursive:true,force:true});}
}
function gameManifest(){
 const files=[];
 function visit(directory){
  for(const entry of readdirSync(directory,{withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name,'en'))){
   // .godot holds imported binary caches; .import files outside it are source import settings.
   if(entry.name==='.godot'||entry.name==='.DS_Store')continue;
   const full=path.join(directory,entry.name);
   if(entry.isDirectory())visit(full);
   else if(entry.isFile())files.push({path:path.relative(root,full).split(path.sep).join('/'),sha256:sha256(readFileSync(full))});
  }
 }
 visit(path.join(root,'game'));files.sort((a,b)=>a.path<b.path?-1:a.path>b.path?1:0);
 return {algorithm:'sha256',excludes:['game/.godot/**','**/.DS_Store'],sha256:sha256(JSON.stringify(files)),files};
}
for(const d of ['dist','builds'])mkdirSync(path.join(root,d),{recursive:true});
if(mode==='play'||mode==='editor'){
 const child=spawn(binary,[...args,...(mode==='editor'?['--editor']:[]),...process.argv.slice(3)],{stdio:'inherit'});
 child.on('exit',code=>process.exit(code??1));
}else{
 if(!modes[mode])throw Error('Unknown mode: '+mode);
 const output=run(binary,['--headless',...args,...modes[mode]]);
 if(/(?:SCRIPT ERROR|ERROR:|FAIL:)/.test(output))throw Error(output);
 if(['test','route'].includes(mode))process.stdout.write(output);
 if(mode==='web')exportLicenses(path.join(root,'dist/licenses'));
 if(mode==='mac')packageMac();
 if(['web','mac'].includes(mode)){
  const file=path.join(root,mode==='web'?'dist/index.pck':'builds/TENSAI.zip');
  const revision=run('git',['rev-parse','HEAD'],{cwd:root}).trim();
  const sourceDirty=run('git',['status','--porcelain','--untracked-files=normal'],{cwd:root}).trim().length>0;
  const sourceManifest=gameManifest();
  const manifestName='source-manifest.json';
  const outputDirectory=path.join(root,mode==='web'?'dist':'builds');
  writeFileSync(path.join(outputDirectory,manifestName),JSON.stringify(sourceManifest,null,2)+'\n');
  writeFileSync(path.join(outputDirectory,'build-info.json'),JSON.stringify({engine:info.stdout.trim(),revision,sourceDirty,sourceManifest:{path:manifestName,sha256:sourceManifest.sha256,scope:'game/ excluding import cache'},mode,sha256:sha256(readFileSync(file)),...(mode==='mac'?{signing:'ad-hoc',signatureVerifiedAfterRepack:true}:{})},null,2)+'\n');
 }
 console.log(mode+': Godot '+info.stdout.trim()+' passed');
}
