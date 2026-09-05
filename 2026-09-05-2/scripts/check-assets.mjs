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
const v2=JSON.parse(readFileSync(path.join(root,'game/assets/models/v2/manifest.json')));
assert.equal(createHash('sha256').update(readFileSync(path.join(root,v2.source))).digest('hex'),v2.source_sha256,'V2 exports must match the reviewed Blender source');
for(const [name,record] of Object.entries(v2.models)){
 const bytes=readFileSync(path.join(root,'game/assets/models/v2',name+'.glb'));
 assert.equal(bytes.readUInt32LE(0),0x46546c67);assert.equal(bytes.length,bytes.readUInt32LE(8));assert.equal(bytes.length,record.bytes);
 const data=JSON.parse(bytes.subarray(20,20+bytes.readUInt32LE(12)).toString());
 assert(data.meshes?.length>0);assert((data.buffers||[]).every(b=>!b.uri));
 if(name==='kohaku')for(const part of ['body','head','leg_L','leg_R','arm_L','arm_R'])assert(data.nodes.some(n=>n.name===part+'_export'),`Missing articulation: ${part}`);
 assert(record.triangles>0&&record.triangles<2000000,'Asset complexity sanity limit, not the old prototype polygon budget');
}
assert(statSync(path.join(root,'game/assets/textures/wet-asphalt.png')).size>1000);
assert(readFileSync(path.join(root,'game/assets/textures/wet-asphalt.png.import'),'utf8').includes('mipmaps/generate=true'),'Shader-loaded 3D textures must have mipmaps to prevent ground shimmer');
console.log('V2 assets verified: detailed character articulation, enemy, street, pavement and reviewed source hash.');
