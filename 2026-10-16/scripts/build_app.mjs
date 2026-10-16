import {cp, mkdir, readdir, readFile, writeFile, rename, rm} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {validateDataset} from '../app/src/model.mjs';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const source=path.join(root,'app'),output=path.join(root,'dist'),temporary=path.join(root,'.app-build-tmp');
validateDataset(JSON.parse(await readFile(path.join(source,'data/history.json'),'utf8')));
await rm(temporary,{recursive:true,force:true});
await mkdir(temporary,{recursive:true});
await cp(source,temporary,{recursive:true});
async function inventory(dir,prefix='') {
  const result=[];
  for(const entry of (await readdir(dir,{withFileTypes:true})).sort((a,b)=>a.name.localeCompare(b.name))){
    const relative=path.posix.join(prefix,entry.name),full=path.join(dir,entry.name);
    if(entry.isDirectory())result.push(...await inventory(full,relative));
    else if(entry.isFile()){const bytes=await readFile(full);result.push({path:relative,bytes:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex')});}
    else throw new Error(`Unsupported build input: ${relative}`);
  }
  return result;
}
const files=await inventory(temporary);
await writeFile(path.join(temporary,'build-manifest.json'),JSON.stringify({version:1,files},null,2)+'\n');
await rm(output,{recursive:true,force:true});
await rename(temporary,output);
console.log(`Built ${files.length} local files (${files.reduce((a,f)=>a+f.bytes,0).toLocaleString()} bytes) in dist/`);
