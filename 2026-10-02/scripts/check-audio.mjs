import {spawnSync} from 'node:child_process';
import {existsSync} from 'node:fs';
import path from 'node:path';
const root=path.resolve(import.meta.dirname,'..');
const local=path.join(root,'.cache/python',process.platform==='win32'?'Scripts/python.exe':'bin/python');
const python=process.env.PYTHON_BIN||(existsSync(local)?local:'python3');
for(const script of ['generate_audio.py','generate_urban_audio.py']){
 const run=spawnSync(python,[path.join(root,'scripts',script),'--check'],{stdio:'inherit'});
 if(run.status!==0)process.exit(run.status||1);
}
