import assert from 'node:assert/strict';
import test from 'node:test';
import { STAGE_PHRASES } from '../src/stage-content.ts';
import { STAGE_DEFINITIONS, isStageId, type DistrictArea } from '../src/stages.ts';
import { TypingSession } from '../src/typing.ts';
import type { Phrase } from '../src/content.ts';

const AREA_BY_STAGE: Record<'shopping'|'station',readonly DistrictArea[]>={
  shopping:['market','alley','store','service','court'],
  station:['forecourt','concourse','waiting','maintenance','platform'],
};
const LIMITS={runner:[6,14],office:[12,24],worker:[18,34],rush:[7,14],boss:[14,36],counter:[10,20],lucky:[10,20]} as const;

test('stage metadata has stable route order and two distinct identities',()=>{
  assert.equal(isStageId('shopping'),true);
  assert.equal(isStageId('station'),true);
  assert.equal(isStageId('unknown'),false);
  assert.deepEqual(STAGE_DEFINITIONS.shopping.routes.map(route=>route.id),['service','store']);
  assert.deepEqual(STAGE_DEFINITIONS.station.routes.map(route=>route.id),['maintenance','waiting']);
  for(const id of ['shopping','station'] as const){
    const def=STAGE_DEFINITIONS[id];
    assert.equal(def.requiredPrompts,43);
    assert.ok(def.title&&def.subtitle&&def.bossName&&def.vista.title&&def.vista.detail);
    for(const area of AREA_BY_STAGE[id]) assert.ok(def.areaLabels[area]&&def.captions[area]);
    for(const rest of ['midpoint','beforeBoss'] as const) assert.ok(Object.values(def.rests[rest]).every(Boolean));
  }
});

test('every authored phrase is typeable and stays within its role budget',()=>{
  for(const id of ['shopping','station'] as const){
    const content=STAGE_PHRASES[id];
    const normalText=new Set<string>();
    const normalReadings=new Set<string>();
    const validate=(role:keyof typeof LIMITS,text:string,reading:string)=>{
      assert.ok(text.trim()&&reading.trim(),`${id} ${role} empty`);
      const length=new TypingSession(reading).standardLength;
      const [min,max]=LIMITS[role];
      assert.ok(length>=min&&length<=max,`${id} ${role} ${text}: ${length}, expected ${min}..${max}`);
    };
    for(const area of AREA_BY_STAGE[id]){
      const roles=content.areas[area];
      assert.ok(roles,`${id}/${area}`);
      for(const role of ['runner','office','worker'] as const){
        const pool:readonly Phrase[]=roles[role];
        assert.ok(pool.length>=8,`${id}/${area}/${role} has ${pool.length}`);
        const initialSets=new Set<string>();
        for(const phrase of pool){
          validate(role,phrase.text,phrase.reading);
          assert.equal(normalText.has(phrase.text),false,`${id} duplicate ${phrase.text}`);
          assert.equal(normalReadings.has(phrase.reading),false,`${id} duplicate reading ${phrase.reading}`);
          normalText.add(phrase.text);
          normalReadings.add(phrase.reading);
          initialSets.add(new TypingSession(phrase.reading).keys.slice().sort().join(''));
        }
        assert.ok(initialSets.size>=6,`${id}/${area}/${role} opener variety ${initialSets.size}`);
      }
    }
    assert.ok(content.rush.length>=8);
    assert.ok(content.boss.length>=12);
    assert.ok(content.counters.length>=6);
    assert.equal(content.lucky.length,3);
    for(const phrase of content.rush) validate('rush',phrase.text,phrase.reading);
    for(const phrase of content.boss) validate('boss',phrase.text,phrase.reading);
    for(const phrase of content.counters) validate('counter',phrase.text,phrase.reading);
    for(const set of content.lucky){
      assert.equal(set.length,3);
      for(const phrase of set) validate('lucky',phrase.text,phrase.reading);
    }
  }
});
