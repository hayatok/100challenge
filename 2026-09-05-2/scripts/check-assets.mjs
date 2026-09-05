import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
const root=path.resolve(import.meta.dirname,'..');
const manifest=JSON.parse(fs.readFileSync(path.join(root,'art/manifest.json')));
const required=['amedori.png','kohaku-walk.png','echoes.png','boss-kit.png','effects.png','key-art.png'];
if(manifest.assets.length!==required.length)throw Error('Unexpected asset count');
for(const file of required){
 const entry=manifest.assets.find(a=>a.file===file);
 if(!entry||entry.provider!=='image_gen')throw Error(`Missing ImageGen provenance: ${file}`);
 const bytes=fs.readFileSync(path.join(root,'game/assets/images',file));
 if(bytes.subarray(0,8).toString('hex')!=='89504e470d0a1a0a')throw Error(`Invalid PNG ${file}`);
 if(bytes.readUInt32BE(16)!==entry.width||bytes.readUInt32BE(20)!==entry.height)throw Error(`Dimensions changed ${file}`);
 if(crypto.createHash('sha256').update(bytes).digest('hex')!==entry.sha256)throw Error(`Source image changed ${file}`);
}
function inspect(dir){for(const entry of fs.readdirSync(dir,{withFileTypes:true})){
 if(entry.name==='.godot')continue;
 const name=path.join(dir,entry.name);
 if(entry.isDirectory())inspect(name);
 else if(/\.(blend|glb|gltf|fbx|obj)$/.test(name))throw Error(`3D asset in 2D project: ${name}`);
 else if(/\.(gd|tscn)$/.test(name)&&/\b(Node3D|Camera3D|MeshInstance3D|CharacterBody3D)\b/.test(fs.readFileSync(name,'utf8')))throw Error(`3D node in ${name}`);
}}
inspect(path.join(root,'game'));
console.log('6 ImageGen assets: PNG dimensions, source hashes and 2D-only project passed');
