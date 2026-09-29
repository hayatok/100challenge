import test from 'node:test';
import assert from 'node:assert/strict';
import {Game} from '../src/game.ts';
import {RailDirector,STOPS,STAGE_STOPS,approachDistance} from '../src/rail.ts';
import { STAGE_DEFINITIONS, type DistrictArea } from '../src/stages.ts';

test('rail holds exploration and pause, arrives at combat stop and resets',()=>{
 const game=new Game({journey:true,practice:true});
 const rail=new RailDirector();rail.update(0,game.state);
 assert.deepEqual(rail.position,STOPS.entrance);
 game.chooseRoute('store');game.update(.4);rail.update(.4,game.state);
 const before={...rail.position};game.pause();rail.update(20,game.state);
 assert.deepEqual(rail.position,before);
 game.resume();game.update(.8);game.update(2);rail.update(2,game.state);
 assert.deepEqual(rail.position,STOPS.market);
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
 assert.equal(rail.moving,false);assert.deepEqual(rail.position,STOPS.market);
});

test('stage selection retains its entrance with null state and resets foreign coordinates',()=>{
 const rail=new RailDirector();
 rail.reset('station');rail.update(0,null);
 assert.deepEqual(rail.position,STAGE_STOPS.station.entrance);
 const station=new Game({journey:true,stageId:'station'});
 rail.update(0,station.state);
 station.chooseRoute('waiting');station.update(2);rail.update(.05,station.state);
 assert.deepEqual(rail.position,STAGE_STOPS.station.forecourt);
 rail.update(0,new Game({journey:true,stageId:'shopping'}).state);
 assert.deepEqual(rail.position,STAGE_STOPS.shopping.entrance);
});

test('all four routes reach their authored stops without moving again between waves',()=>{
 for(const stageId of ['shopping','station'] as const) for(const {id:route} of STAGE_DEFINITIONS[stageId].routes){
  const rail=new RailDirector();rail.reset(stageId);
  const state=new Game({journey:true,stageId}).state;
  state.journey!.route=route;
  state.mode='travel';
  state.journey!.travelProgress=1;
  const first:DistrictArea=stageId==='shopping'?'market':'forecourt';
  const second:DistrictArea=stageId==='shopping'?'alley':'concourse';
  const final:DistrictArea=stageId==='shopping'?'court':'platform';
  const vista:DistrictArea=stageId==='shopping'?'roof':'dawn';
  for(const stop of [first,second,route,final] as DistrictArea[]){
   state.journey!.area=stop;
   rail.update(.05,state);
   assert.deepEqual(rail.position,STAGE_STOPS[stageId][stop]);
   state.mode='playing';
   rail.update(5,state);
   assert.equal(rail.moving,false);
   assert.deepEqual(rail.position,STAGE_STOPS[stageId][stop]);
   state.mode='travel';
  }
  state.stage=3;
  rail.update(.05,state);
  assert.deepEqual(rail.position,STAGE_STOPS[stageId].boss);
  state.mode='vista';
  state.journey!.area=vista;
  rail.update(stageId==='shopping'?5:3,state);
  assert.deepEqual(rail.position,STAGE_STOPS[stageId][vista]);
 }
});

test('station rail holds its interpolation throughout pause and resume countdown',()=>{
 const game=new Game({journey:true,stageId:'station'});
 const rail=new RailDirector();rail.reset('station');
 game.chooseRoute('waiting');
 game.update(.5);rail.update(.5,game.state);
 const before={...rail.position};
 game.pause();game.update(100);rail.update(100,game.state);
 assert.deepEqual(rail.position,before);
 game.resume();game.update(.4);rail.update(100,game.state);
 assert.deepEqual(rail.position,before);
 game.update(.4);rail.update(0,game.state);
 assert.deepEqual(rail.position,before);
 game.update(1.5);rail.update(.01,game.state);
 assert.deepEqual(rail.position,STAGE_STOPS.station.forecourt);
});

test('checkpoint state snaps from the second half back to the first stop',()=>{
 for(const stageId of ['shopping','station'] as const){
  const rail=new RailDirector();rail.reset(stageId);
  const state=new Game({journey:true,stageId}).state;
  state.journey!.route=STAGE_DEFINITIONS[stageId].routes[0].id;
  state.mode='travel';state.journey!.travelProgress=1;
  state.journey!.area=stageId==='shopping'?'alley':'concourse';
  rail.update(.01,state);
  assert.deepEqual(rail.position,STAGE_STOPS[stageId][state.journey!.area]);
  state.mode='playing';
  state.journey!.area=stageId==='shopping'?'market':'forecourt';
  rail.update(.01,state);
  assert.deepEqual(rail.position,STAGE_STOPS[stageId][state.journey!.area]);
 }
});
