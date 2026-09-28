import test from 'node:test';
import assert from 'node:assert/strict';
import { readSave, writeSave, defaultPreferences, recordResult, resultKey, RESULT_RULES_VERSION, type SavedResult } from '../src/storage.ts';
Object.defineProperty(globalThis,'matchMedia',{value:()=>({matches:false}),configurable:true});
let content:string|null=null;
Object.defineProperty(globalThis,'localStorage',{value:{getItem:()=>content,setItem:(_key:string,value:string)=>{content=value;}},configurable:true});
test('broken storage falls back without preventing a new game',()=>{content='{broken';assert.deepEqual(readSave().preferences,defaultPreferences());assert.deepEqual(readSave().results,[]);});
test('saved controls reject invalid difficulty and constrain volume',()=>{content=JSON.stringify({preferences:{difficulty:'impossible',music:9,effects:-2,motion:'false',practice:true}});const p=readSave().preferences;assert.equal(p.difficulty,'normal');assert.equal(p.music,1);assert.equal(p.effects,0);assert.equal(p.motion,true);assert.equal(p.practice,true);});
test('storage quota denial is reported as a recoverable failure',()=>{Object.defineProperty(globalThis,'localStorage',{value:{getItem:()=>null,setItem:()=>{throw new Error('quota');}},configurable:true});assert.equal(writeSave(defaultPreferences(),[]),false);});

function installStorage() {
  content = null;
  Object.defineProperty(globalThis,'localStorage',{value:{getItem:()=>content,setItem:(_key:string,value:string)=>{content=value;}},configurable:true});
}
const result = (score:number, overrides:Partial<SavedResult> = {}): SavedResult => ({
  score,combo:10,accuracy:0.95,seconds:120,cleared:true,difficulty:'normal',
  practice:false,retries:0,date:new Date(2026,8,28,0,0,score).toISOString(),
  rulesVersion:RESULT_RULES_VERSION,...overrides,
});

test('legacy alpha results are retained as version 2 and never compared with new rules',()=>{
  installStorage();
  const old = result(500,{rulesVersion:2});
  const {rulesVersion: _version,...legacy} = old;
  void _version;
  content = JSON.stringify({version:1,results:[legacy]});
  const save = readSave();
  assert.equal(save.results[0].rulesVersion,2);
  assert.equal(save.personalBests[resultKey(old)]?.score,500);
  assert.equal(save.personalBests[resultKey(result(500))],undefined);
});

test('v0.4 results without a rule field stay in version 3 after the v0.5 upgrade',()=>{
  installStorage();
  const prior = result(600,{rulesVersion:3});
  const {rulesVersion: _version,...withoutRules} = prior;
  void _version;
  content = JSON.stringify({version:2,results:[withoutRules]});
  const saved = readSave();
  assert.equal(RESULT_RULES_VERSION,4);
  assert.equal(saved.results[0].rulesVersion,3);
  assert.equal(saved.personalBests[resultKey(prior)]?.score,600);
  assert.equal(saved.personalBests[resultKey(result(0))],undefined);
});

test('optional v0.5 metrics round trip and invalid replay seeds or counts are omitted',()=>{
  installStorage();
  assert.equal(recordResult(readSave(),result(100,{seed:0,rushes:0,chainKills:0})).results[0].seed,0);
  const fresh = result(700,{seed:0xffffffff,rushes:2,chainKills:1});
  assert.equal(writeSave(defaultPreferences(),[fresh]),true);
  assert.deepEqual(readSave().results[0],fresh);
  const legacy = result(500,{rulesVersion:3});
  content = JSON.stringify({version:2,results:[
    {...fresh,seed:-1,rushes:Infinity,chainKills:1.5},
    {...fresh,seed:0x100000000,rushes:-1,chainKills:10001},
    {...fresh,seed:NaN,rushes:NaN,chainKills:NaN},
    legacy,
  ]});
  const restored = readSave();
  for (const row of restored.results.slice(0,3)) {
    assert.equal(row.seed,undefined);
    assert.equal(row.rushes,undefined);
    assert.equal(row.chainKills,undefined);
  }
  assert.equal(restored.results[3].rulesVersion,3);
  assert.equal(restored.personalBests[resultKey(legacy)]?.score,500);
  assert.equal(restored.personalBests[resultKey(fresh)]?.score,700);
});

test('malformed result fields are discarded and forged best keys are recomputed',()=>{
  installStorage();
  const valid = result(700,{practice:true,difficulty:'fierce'});
  content = JSON.stringify({version:2,results:[
    {...valid,accuracy:Infinity},{...valid,seconds:-1},{...valid,difficulty:'unknown'},
    {...valid,retries:1.2},{...valid,date:'not-a-date'},valid,
  ],personalBests:{'3:normal:standard':valid}});
  const save = readSave();
  assert.equal(save.results.length,1);
  assert.equal(save.personalBests['3:normal:standard'],undefined);
  assert.equal(save.personalBests[resultKey(valid)].score,700);
});

test('personal best survives last-ten history trimming and separates difficulty and practice',()=>{
  installStorage();
  let save = readSave();
  save = recordResult(save,result(1000));
  for (let i=0;i<12;i++) save = recordResult(save,result(100+i,{date:new Date(2026,8,28,1,0,i).toISOString()}));
  save = recordResult(save,result(2000,{practice:true}));
  save = recordResult(save,result(3000,{difficulty:'fierce'}));
  assert.equal(save.results.length,10);
  assert.ok(save.results.every(r => r.score !== 1000));
  assert.equal(writeSave(save.preferences,save.results,save.personalBests),true);
  const restored = readSave();
  assert.equal(restored.personalBests[resultKey(result(0))].score,1000);
  assert.equal(restored.personalBests[resultKey(result(0,{practice:true}))].score,2000);
  assert.equal(restored.personalBests[resultKey(result(0,{difficulty:'fierce'}))].score,3000);
});

test('defeat does not overwrite a cleared best and tie breaks use accuracy then time',()=>{
  installStorage();
  let save = readSave();
  save = recordResult(save,result(500));
  save = recordResult(save,result(900,{cleared:false}));
  save = recordResult(save,result(500,{accuracy:0.97}));
  save = recordResult(save,result(500,{accuracy:0.97,seconds:100}));
  assert.equal(save.personalBests[resultKey(result(0))].seconds,100);
});
