import test from 'node:test';
import assert from 'node:assert/strict';
import * as T from 'three';
import { StreetAtmosphere } from '../src/atmosphere.ts';

test('rain reuses a fixed buffer and respects indoor and reduced-motion states',()=>{
 const scene=new T.Scene();const atmosphere=new StreetAtmosphere(scene);
 const view={x:10,y:1.65,z:-12,yaw:0};
 const rain=scene.getObjectByName('Rain around player') as T.LineSegments;
 const buffer=rain.geometry.attributes.position.array;
 for(let i=0;i<500;i++)atmosphere.update(.016,'alley',view,true);
 assert.equal(scene.children.length,2);
 assert.equal(rain.geometry.attributes.position.array,buffer);
 assert.equal(buffer.length,1080);
 assert.ok(Array.from(buffer).every(Number.isFinite));
 const frozen=Array.from(buffer);atmosphere.update(0,'alley',view,true);
 assert.deepEqual(Array.from(buffer),frozen);
 atmosphere.update(.1,'store',view,true);assert.equal(rain.visible,false);
 atmosphere.update(.1,'alley',view,false);assert.equal(rain.visible,false);
});

test('reflection follows roof elevation and returns to street level',()=>{
 const scene=new T.Scene();const atmosphere=new StreetAtmosphere(scene);
 const view={x:24,y:8.65,z:-50,yaw:0};
 const surface=scene.getObjectByName('Wet ground reflections') as T.Mesh;
 atmosphere.update(.1,'roof',view,true);assert.equal(surface.position.y,7.04);
 atmosphere.update(.1,'store',view,true);assert.equal(surface.position.y,.017);
 assert.equal((surface.material as T.ShaderMaterial).uniforms.wetness.value,.1);
});
