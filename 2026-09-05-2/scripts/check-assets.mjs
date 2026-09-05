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

const v3=JSON.parse(readFileSync(path.join(root,'game/assets/models/v3/manifest.json')));
assert.equal(createHash('sha256').update(readFileSync(path.join(root,v3.source))).digest('hex'),v3.source_sha256,'V3 exports must match the saved character source');
const characterBytes=readFileSync(path.join(root,'game/assets/models/v3/kohaku.glb'));
assert.equal(characterBytes.readUInt32LE(0),0x46546c67);
assert.equal(characterBytes.length,characterBytes.readUInt32LE(8));
assert.equal(characterBytes.length,v3.models.kohaku.bytes);
const character=JSON.parse(characterBytes.subarray(20,20+characterBytes.readUInt32LE(12)).toString());
assert(character.images?.length>=2,'Painted face and hair must be embedded in the character');
assert(character.images.every(i=>!i.uri),'Character textures must not depend on external paths');
for(const part of ['body','head','leg_L','leg_R','arm_L','arm_R'])assert(character.nodes.some(n=>n.name===part+'_export'));
for(const mesh of character.meshes)for(const primitive of mesh.primitives){
 const material=character.materials[primitive.material];
 if(material.pbrMetallicRoughness?.baseColorTexture)assert(primitive.attributes.TEXCOORD_0!==undefined,'Painted surfaces require UVs');
 if(['hair','hair_mid','face_painted'].includes(material.name)){
  const accessor=character.accessors[primitive.attributes.TEXCOORD_0];
  assert(accessor&&accessor.componentType===5126&&accessor.type==='VEC2');
  const view=character.bufferViews[accessor.bufferView];
  const binaryStart=28+characterBytes.readUInt32LE(12);
  const start=binaryStart+(view.byteOffset||0)+(accessor.byteOffset||0);
  let minU=Infinity,maxU=-Infinity,minV=Infinity,maxV=-Infinity;
  for(let i=0;i<accessor.count;i++){
   const at=start+i*(view.byteStride||8);const u=characterBytes.readFloatLE(at),v=characterBytes.readFloatLE(at+4);
   minU=Math.min(minU,u);maxU=Math.max(maxU,u);minV=Math.min(minV,v);maxV=Math.max(maxV,v);
  }
  assert(maxU-minU>.5&&maxV-minV>.5,`${material.name} must retain nonconstant painted UVs after mesh joining`);
 }
}
console.log('V3 character verified: source hash, embedded face/hair textures, UVs and articulation. Visual quality requires separate review.');
