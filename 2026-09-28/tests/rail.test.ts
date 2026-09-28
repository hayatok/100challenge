import test from 'node:test';
import assert from 'node:assert/strict';
import {Game} from '../src/game.ts';
import {RailDirector,STOPS,approachDistance} from '../src/rail.ts';

test('rail holds exploration and pause, arrives at combat stop and resets',()=>{
 const game=new Game({journey:true,practice:true});
 const rail=new RailDirector();rail.update(0,game.state);
 assert.deepEqual(rail.position,STOPS.entrance);
 game.chooseRoute('store');game.update(.4);rail.update(.4,game.state);
 const before={...rail.position};game.pause();rail.update(20,game.state);
 assert.deepEqual(rail.position,before);
 game.resume();game.update(.8);game.update(2);rail.update(2,game.state);
 assert.deepEqual(rail.position,STOPS.alley);
 rail.reset();rail.update(0,null);assert.deepEqual(rail.position,STOPS.entrance);
});
test('approach has readable starting distance and closes to arms length without overshoot',()=>{
 for(const kind of ['office','runner','worker']){
 const distances=[0,.25,.5,.75,1,2].map(p=>approachDistance(p,kind,true));
 assert.equal(distances[0],5.1);
 for(let i=1;i<distances.length;i++)assert.ok(distances[i]<=distances[i-1]);
 assert.ok(distances.at(-1)!>=1.3 && distances.at(-1)!<=1.7);
 }
});

test('camera arrives with combat even when render delta is capped',()=>{
 const game=new Game({journey:true,practice:true});const rail=new RailDirector();
 rail.update(0,game.state);game.chooseRoute('store');game.update(.4);rail.update(.05,game.state);
 game.update(2);rail.update(.05,game.state);
 assert.equal(rail.moving,false);assert.deepEqual(rail.position,STOPS.alley);
});
