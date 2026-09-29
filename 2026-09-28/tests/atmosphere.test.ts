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

test('station rain and wet reflection remain on the exposed forecourt',()=>{
 const scene=new T.Scene();const atmosphere=new StreetAtmosphere(scene);
 const surface=scene.getObjectByName('Wet ground reflections') as T.Mesh;
 const rain=scene.getObjectByName('Rain around player') as T.LineSegments;
 const stationView={x:100,y:1.65,z:10,yaw:0};
 atmosphere.update(.1,'forecourt',stationView,true);
 assert.equal(surface.visible,true);
 assert.equal(surface.position.x,100);
 assert.equal(surface.position.z,12);
 assert.equal(rain.visible,true);
 for(const area of ['concourse','waiting','maintenance','platform','dawn'] as const){
  atmosphere.update(.1,area,stationView,true);
  assert.equal(surface.visible,false,area);
  assert.equal(rain.visible,false,area);
 }
 atmosphere.update(.1,'forecourt',stationView,false);
 assert.equal(rain.visible,false);
 atmosphere.update(.1,'alley',{x:0,y:1.65,z:0,yaw:0},true);
 assert.equal(surface.visible,true);
 assert.equal(surface.position.x,12);
 assert.equal(surface.scale.x,1);
 assert.equal(rain.visible,true);
});
