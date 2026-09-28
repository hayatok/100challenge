import test from 'node:test';
import assert from 'node:assert/strict';
import * as T from 'three';
import {StorefrontProps} from '../src/storefront.ts';
import {installSurface} from '../src/surface-materials.ts';

test('shop displays react once each, pause with dt zero, settle and reset without allocating new props',()=>{
 const p=new StorefrontProps();const children=[...p.root.children];const start=children.map(x=>x.position.clone());
 assert.equal(p.strike(new T.Vector3(0,1,-40)),null);
 assert.ok(p.strike(new T.Vector3(-1,1,-2)));assert.ok(p.strike(new T.Vector3(1,1,-2)));assert.equal(p.strike(new T.Vector3(0,1,-2)),null);
 p.update(0);children.forEach((x,i)=>assert.ok(x.position.equals(start[i])));
 for(let i=0;i<300;i++)p.update(.05);
 assert.ok(children.every(x=>Number.isFinite(x.position.y)&&x.position.y>=0));
 const settled=children.map(x=>x.position.clone());for(let i=0;i<60;i++)p.update(.05);
 children.forEach((x,i)=>assert.ok(x.position.distanceTo(settled[i])<.001));
 p.reset();assert.deepEqual(p.root.children,children);children.forEach((x,i)=>assert.ok(x.position.equals(start[i])));assert.ok(p.strike(new T.Vector3(0,1,-2),true));p.dispose();
});
test('partial material failure retains fallback and disposes temporary loaded maps',async()=>{
 const original=new T.Texture();const material=new T.MeshStandardMaterial({map:original});let disposed=0,owned=0;
 const result=await installSurface(material,'test',new T.Vector2(2,3),t=>{owned++;return t;},async url=>{if(url.includes('normal'))throw Error('404');const t=new T.Texture();t.addEventListener('dispose',()=>disposed++);return t;});
 assert.equal(result,false);assert.equal(material.map,original);assert.equal(disposed,2);assert.equal(owned,0);
});
test('loaded surface uses sRGB only for albedo and preserves common UV scale',async()=>{
 const material=new T.MeshStandardMaterial();assert.equal(await installSurface(material,'test',new T.Vector2(2,3),t=>t,async()=>new T.Texture()),true);
 assert.equal(material.map!.colorSpace,T.SRGBColorSpace);assert.equal(material.normalMap!.colorSpace,T.NoColorSpace);assert.equal(material.roughnessMap!.colorSpace,T.NoColorSpace);assert.deepEqual(material.map!.repeat.toArray(),[2,3]);
});
