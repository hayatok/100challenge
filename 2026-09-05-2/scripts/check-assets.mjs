import {readFileSync,statSync} from 'node:fs';
import {createHash} from 'node:crypto';
import path from 'node:path';
import assert from 'node:assert/strict';
const root=path.resolve(import.meta.dirname,'..');
const manifest=JSON.parse(readFileSync(path.join(root,'game/assets/models/manifest.json')));
const digest=createHash('sha256').update(readFileSync(path.join(root,manifest.source))).digest('hex');
assert.equal(digest,manifest.source_sha256,'GLB exports must match the saved Blender source');
for(const [name,record] of Object.entries(manifest.models)){
 const p=path.join(root,'game/assets/models',name+'.glb');const bytes=readFileSync(p);
 assert.equal(bytes.readUInt32LE(0),0x46546c67);assert.equal(bytes.length,bytes.readUInt32LE(8));assert.equal(bytes.length,record.bytes);
 const data=JSON.parse(bytes.subarray(20,20+bytes.readUInt32LE(12)).toString());
 assert(data.meshes?.length>0);assert((data.buffers||[]).every(b=>!b.uri),'GLB must be self-contained');
 assert((data.images||[]).every(i=>!i.uri),'No external image paths');
 assert(record.triangles>0&&record.triangles<10000);
}
assert(statSync(path.join(root,'game/assets/fonts/NotoSansCJKjp-Medium.otf')).size>1000);
assert.equal(readFileSync(path.join(root,'game/assets/fonts/NotoSansCJKjp-Medium.otf')).toString('ascii',0,4),'OTTO');
assert(statSync(path.join(root,'game/assets/yofukashi.png')).size>1000);
console.log(`Assets verified: ${Object.keys(manifest.models).length} GLBs; saved source hash; Japanese font and opening illustration.`);
