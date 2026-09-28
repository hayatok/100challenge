import test from 'node:test';
import assert from 'node:assert/strict';
import {CelebrationState} from '../src/spectacle.ts';
import {OverdriveLights} from '../src/overdrive.ts';

test('rush success wins the same-batch kill celebration and failure never earns a completion',()=>{
 const s=new CelebrationState();s.event({id:1,type:'rushStart'});s.update(2);
 for(let i=1;i<=4;i++)s.event({id:1,type:'kill',combo:i,effectsLevel:1});
 assert.equal(s.rushHits,4);s.event({id:1,type:'rushEnd',success:true});assert.equal(s.current?.title,'全員退勤');
 s.event({id:1,type:'kill',combo:6,effectsLevel:2});assert.equal(s.current?.title,'全員退勤');
 s.reset();s.event({id:1,type:'rushStart'});s.event({id:1,type:'rushEnd',success:false});assert.equal(s.current?.title,'残業終了');
});
test('jackpot survives nearby kills, pauses its lifetime, and reset clears all presentation state',()=>{
 const s=new CelebrationState();s.event({id:1,type:'luckyEnd',success:true,scoreDelta:500});const reward=s.current;
 s.event({id:1,type:'kill',combo:15,effectsLevel:4});assert.equal(s.current,reward);s.update(0);assert.equal(s.current?.remaining,2.1);
 s.update(3);assert.equal(s.current,null);s.event({id:1,type:'luckyEnd',success:false});assert.equal(s.current,null);
 s.event({id:1,type:'rushStart'});s.reset();assert.equal(s.rushHits,0);assert.equal(s.rushing,false);assert.equal(s.current,null);
});
test('street celebration reuses fixtures through tier changes and returns dark at reset',()=>{
 const lights=new OverdriveLights();const children=[...lights.root.children];
 for(let i=0;i<500;i++)lights.update(i/60,i%5,5-i*.1,i%2===0,i%7===0,i%3);
 assert.deepEqual(lights.root.children,children);assert.equal(children.length,8);
 lights.reset();assert.equal(lights.root.visible,false);lights.update(0,0,5,true,false,0);assert.equal(lights.root.visible,false);
 lights.update(0,4,-25,false,false,0);assert.equal(lights.root.visible,true);assert.equal(lights.root.position.z,-25);
});
