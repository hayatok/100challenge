import assert from 'node:assert/strict';
import test from 'node:test';
import { Game, type EnemyView, type GameResults } from '../src/game.ts';
import { STAGE_DEFINITIONS, type JourneyRoute, type StageId } from '../src/stages.ts';

function finishLeader(game:Game, sequences?:string[]): void {
  const leader=game.state.enemies.find(enemy=>!enemy.support);
  assert.ok(leader);
  if(sequences) sequences.push(leader.phrase);
  const id=leader.id;
  let guard=0;
  while(game.state.enemies.some(enemy=>enemy.id===id) && guard++<150){
    const target:EnemyView=game.state.enemies.find(enemy=>enemy.id===id)!;
    assert.equal(game.type(target.guide[0]),true);
  }
  assert.ok(guard<150);
}
function advance(game:Game, sequences?:string[]):void {
  const s=game.state;
  if(s.mode==='travel') game.update(5);
  else if(s.mode==='rest') assert.equal(game.continueRest(),true);
  else if(s.mode==='playing') finishLeader(game,sequences);
  else throw new Error(`Unexpected mode ${s.mode}`);
}
function reach(game:Game,stage:number):void {
  let guard=0;
  while(game.state.stage<stage && guard++<150) advance(game);
  assert.ok(guard<150);
}
function run(stageId:StageId,route:JourneyRoute,seed:number,practice=true) {
  const game=new Game({stageId,journey:true,practice,seed});
  assert.equal(game.chooseRoute(route),true);
  const phrases:string[]=[];
  const normalPhrases:string[]=[];
  let normal=0,rush=0,boss=0,lucky=0,bonusPrompts=0;
  let guard=0;
  while(game.state.mode!=='vista' && guard++<180){
    const s=game.state;
    assert.ok(s.enemies.length<=3,`${stageId}/${route}/${seed} exceeded three enemies`);
    if(s.mode==='playing') {
      const leader=s.enemies.find(enemy=>!enemy.support)!;
      assert.ok(leader);
      if(leader.lucky) lucky++;
      else if(leader.rush) rush++;
      else if(leader.kind==='boss') boss++;
      else { normal++; normalPhrases.push(leader.phrase); }
      if(!leader.lucky) {
        const keys=s.enemies.flatMap(enemy=>enemy.keys);
        assert.equal(keys.length,new Set(keys).size,`${stageId}/${route}/${seed}`);
      }
    }
    advance(game,phrases);
    const events=game.drainEvents();
    bonusPrompts+=events.filter(event=>event.type==='luckyStep'||event.type==='luckyEnd'&&event.success).length;
  }
  assert.ok(guard<180,`${stageId}/${route}/${seed}`);
  return {game,phrases,normal,normalPhrases,rush,boss,lucky,bonusPrompts};
}

// Two stages share an internal four-section clock, but each route owns its own phrase sequence.
test('all stages, routes, and seeds resolve exactly 43 required prompts',()=>{
  for(const stageId of ['shopping','station'] as const){
    for(const {id:route} of STAGE_DEFINITIONS[stageId].routes){
      const requiredKeys:number[]=[];
      for(let seed=0;seed<32;seed++){
        const {game,normal,normalPhrases,rush,boss,lucky,bonusPrompts}=run(stageId,route,seed);
        assert.equal(normal,34);
        assert.equal(new Set(normalPhrases).size,34);
        assert.equal(rush,4);
        assert.equal(boss,5);
        assert.equal(lucky,1); // encounter has three steps on one enemy id
        assert.equal(bonusPrompts,3);
        assert.equal(normal+rush+boss+bonusPrompts,46);
        assert.equal(game.state.journey?.completedPrompts,43);
        assert.equal(game.state.journey?.totalPrompts,43);
        assert.equal(game.state.chainKills,8);
        assert.equal(game.state.rushes,1);
        assert.equal(game.state.enemies.length,0);
        assert.equal(game.state.results,null);
        assert.equal(game.state.journey?.area,stageId==='shopping'?'roof':'dawn');
        assert.equal(game.continueVista(),true);
        assert.equal(game.continueVista(),false);
        const result=game.state.results as GameResults|null;
        assert.ok(result);
        assert.equal(result.stageId,stageId);
        requiredKeys.push(result.correct);
      }
      requiredKeys.sort((a,b)=>a-b);
      assert.ok(requiredKeys[0]>=560,`${stageId}/${route} minimum keys ${requiredKeys[0]}`);
      assert.ok(requiredKeys.at(-1)!<=900,`${stageId}/${route} maximum keys ${requiredKeys.at(-1)}`);
      assert.ok((requiredKeys[15]+requiredKeys[16])/2>=650,`${stageId}/${route} median keys`);
    }
  }
});

test('route belongs to its stage, restart preserves settings, and phrase order is seeded',()=>{
  assert.throws(()=>new Game({stageId:'unknown' as StageId}),/stageId/);
  assert.throws(()=>new Game({seed:-1}),/seed/);
  for(const stageId of ['shopping','station'] as const){
    const [first,second]=STAGE_DEFINITIONS[stageId].routes.map(route=>route.id);
    const game=new Game({stageId,journey:true,seed:12,practice:true,difficulty:'fierce'});
    assert.equal(game.chooseRoute(stageId==='shopping'?'waiting':'store'),false);
    assert.equal(game.chooseRoute(first),true);
    assert.equal(game.chooseRoute(second),false);
    const restarted=game.restart();
    assert.equal(restarted.stageId,stageId);
    assert.equal(restarted.seed,12);
    assert.equal(restarted.difficulty,'fierce');
    assert.equal(restarted.practice,true);
    assert.equal(restarted.state.journey?.route,null);
    const a=run(stageId,first,12).phrases;
    const b=run(stageId,first,12).phrases;
    const c=run(stageId,first,13).phrases;
    assert.deepEqual(a,b);
    assert.notDeepEqual(a,c);
  }
  assert.notDeepEqual(run('shopping','store',12).phrases,run('station','waiting',12).phrases);
});

test('timed rules remain feasible on every route and difficulty with a clean typing sequence',()=>{
  for(const stageId of ['shopping','station'] as const)
    for(const {id:route} of STAGE_DEFINITIONS[stageId].routes)
      for(const difficulty of ['relaxed','normal','fierce'] as const)
        for(const seed of [0,1,12,0xffffffff]){
          const game=new Game({stageId,journey:true,practice:false,difficulty,seed});
          game.chooseRoute(route);
          let guard=0;
          while(game.state.mode!=='vista'&&guard++<12000){
            const mode=game.state.mode;
            if(mode==='travel')game.update(.05);
            else if(mode==='rest')game.continueRest();
            else if(mode==='playing')finishLeader(game);
            else throw new Error(`${stageId}/${route}/${difficulty}/${seed} stopped at ${mode}`);
          }
          assert.ok(guard<12000);
          assert.equal(game.state.health,3);
          assert.equal(game.state.journey?.completedPrompts,43);
        }
});

test('midpoint and boss rest freeze battle, survive pause, and continue only once',()=>{
  for(const stageId of ['shopping','station'] as const){
    const game=new Game({stageId,journey:true,seed:2,practice:true});
    game.chooseRoute(STAGE_DEFINITIONS[stageId].routes[0].id);
    for(const [stage,kind] of [[2,'midpoint'],[3,'beforeBoss']] as const){
      reach(game,stage);
      assert.equal(game.state.mode,'travel');
      game.update(stage===2?4:2);
      assert.equal(game.state.mode,'rest');
      assert.equal(game.state.journey?.rest,kind);
      assert.equal(game.state.enemies.length,0);
      const snapshot=game.state;
      game.update(100);
      assert.equal(game.state.score,snapshot.score);
      assert.equal(game.state.journey?.completedPrompts,snapshot.journey?.completedPrompts);
      assert.equal(game.type('a'),false);
      game.pause();game.update(100);game.resume();game.update(.8);
      assert.equal(game.state.mode,'rest');
      assert.equal(game.continueRest(),true);
      assert.equal(game.continueRest(),false);
      assert.equal(game.state.journey?.rest,null);
    }
    let guard=0;
    while(game.state.mode!=='vista' && guard++<30) advance(game);
    assert.ok(guard<30);
    game.update(100);
    assert.equal(game.state.mode,'vista');
    game.continueVista();
    const baseline=run(stageId,STAGE_DEFINITIONS[stageId].routes[0].id,2).game;
    baseline.continueVista();
    assert.ok(game.state.results!.clearTime <= baseline.state.results!.clearTime);
  }
});

test('stage zero changes area after six prompts and retry restores its initial area and progress',()=>{
  for(const stageId of ['shopping','station'] as const){
    const game=new Game({stageId,journey:true,seed:1});
    game.chooseRoute(STAGE_DEFINITIONS[stageId].routes[0].id);
    game.update(2);
    const first=stageId==='shopping'?'market':'forecourt';
    const second=stageId==='shopping'?'alley':'concourse';
    assert.equal(game.state.journey?.area,first);
    let guard=0;
    while(game.state.journey!.completedPrompts<6 && guard++<15) advance(game);
    assert.ok(guard<15);
    assert.equal(game.state.journey?.area,second);
    game.update(3);
    assert.equal(game.state.mode,'playing');
    const mode=()=>game.state.mode;
    while(mode()!=='defeat' && guard++<30){
      const leader=game.state.enemies.find(e=>!e.support);
      if(mode()==='travel') game.update(5);
      else if(leader) game.update(leader.remaining+.01);
    }
    assert.equal(game.state.mode,'defeat');
    game.retryCheckpoint();
    assert.equal(game.state.stageId,stageId);
    assert.equal(game.state.journey?.area,first);
    assert.equal(game.state.journey?.wave,0);
    assert.equal(game.state.journey?.completedPrompts,0);
    assert.equal(game.state.health,3);
    assert.equal(game.state.combo,0);
    assert.equal(game.state.effectsLevel,0);
  }
});

test('FEVER central word controls supports and checkpoint rollback prevents bonus duplication',()=>{
  const game=new Game({stageId:'station',journey:true,seed:2});
  game.chooseRoute('waiting');reach(game,2);game.update(4);
  assert.equal(game.continueRest(),true);
  const group=game.state.enemies;
  assert.equal(group.length,3);
  assert.equal(group.filter(enemy=>enemy.support).length,2);
  assert.ok(group.filter(enemy=>enemy.support).every(enemy=>enemy.keys.length===0&&enemy.guide===''));
  const firstRushPhrase=group.find(enemy=>!enemy.support)!.phrase;
  const checkpointScore=game.state.score;
  finishLeader(game);
  assert.equal(game.state.journey?.completedPrompts,25);
  assert.equal(game.state.chainKills,2);
  let guard=0;
  while(game.state.mode!=='defeat' && guard++<20){
    if(game.state.mode==='travel')game.update(1);
    else game.update(game.state.enemies.find(enemy=>!enemy.support)!.remaining+.01);
  }
  assert.equal(game.state.mode,'defeat');
  game.retryCheckpoint();
  assert.equal(game.state.stage,2);
  assert.equal(game.state.mode,'rest');
  assert.equal(game.state.journey?.rest,'midpoint');
  assert.equal(game.state.journey?.travelProgress,1);
  assert.equal(game.state.enemies.length,0);
  assert.equal(game.state.journey?.completedPrompts,24);
  assert.equal(game.state.score,checkpointScore);
  assert.equal(game.state.chainKills,0);
  assert.equal(game.state.rushes,0);
  assert.equal(game.state.luckyEncounters,1);
  assert.equal(game.state.luckyBonus,500);
  assert.equal(game.continueRest(),true);
  assert.equal(game.continueRest(),false);
  assert.equal(game.state.rushes,1);
  assert.equal(game.state.enemies.length,3);
  assert.equal(game.state.enemies.find(enemy=>!enemy.support)!.phrase,firstRushPhrase);
});

test('journey Lucky misses and timeout do not alter required progress or combat stats',()=>{
  for(const stageId of ['shopping','station'] as const){
    const game=new Game({stageId,journey:true,seed:2});
    game.chooseRoute(STAGE_DEFINITIONS[stageId].routes[0].id);
    let guard=0;
    while(!game.state.luckyActive&&guard++<80) advance(game);
    assert.ok(guard<80);
    const before=game.state;
    const wrong=['x','q','z'].find(key=>!before.enemies[0].keys.includes(key))!;
    assert.equal(game.type(wrong),false);
    assert.equal(game.state.score,before.score);
    assert.equal(game.state.combo,before.combo);
    assert.equal(game.state.health,before.health);
    assert.equal(game.state.journey?.completedPrompts,24);
    game.update(before.luckyRemaining+.01);
    assert.equal(game.state.luckyActive,false);
    assert.equal(game.state.luckyEncounters,1);
    assert.equal(game.state.luckyClears,0);
    assert.equal(game.state.luckyBonus,0);
    assert.equal(game.state.journey?.completedPrompts,24);
    assert.equal(game.state.score,before.score);
    assert.equal(game.state.health,before.health);
    game.update(4);
    assert.equal(game.state.mode,'rest');
  }
});

test('ordinary odd seeds skip Lucky while even seeds and practice receive one chance',()=>{
  for(const stageId of ['shopping','station'] as const){
    for(const [seed,practice,expected] of [[1,false,0],[2,false,1],[1,true,1]] as const){
      const game=new Game({stageId,journey:true,seed,practice});
      game.chooseRoute(STAGE_DEFINITIONS[stageId].routes[0].id);
      reach(game,2);
      assert.equal(game.state.luckyEncounters,expected);
      assert.equal(game.state.journey?.completedPrompts,24);
    }
  }
});

test('normal attacks resolve prompts, boss misses do not, and state snapshots are read-only copies',()=>{
  const game=new Game({journey:true,seed:1});
  game.chooseRoute('store');game.update(2);
  const first=game.state;
  first.journey!.completedPrompts=99;
  assert.equal(game.state.journey?.completedPrompts,0);
  const leader=game.state.enemies[0];
  game.update(leader.remaining+.01);
  assert.equal(game.state.journey?.completedPrompts,1);
  assert.equal(game.state.health,2);
});

test('route and boss checkpoint retries restore stage-local progress and rewards',()=>{
  for(const stageId of ['shopping','station'] as const){
    const route=STAGE_DEFINITIONS[stageId].routes[1].id;
    const game=new Game({stageId,journey:true,seed:2});
    game.chooseRoute(route);
    reach(game,1);
    const atRoute=game.state;
    assert.equal(atRoute.journey?.completedPrompts,12);
    assert.equal(atRoute.journey?.area,route);
    game.update(3.8);
    const firstRoutePhrases=game.state.enemies.map(enemy=>enemy.phrase);
    let guard=0;
    while(game.state.mode!=='defeat'&&guard++<30){
      if(game.state.mode==='travel')game.update(5);
      else game.update(Math.max(...game.state.enemies.filter(e=>!e.support).map(e=>e.remaining))+.01);
    }
    assert.ok(guard<30);
    game.retryCheckpoint();
    assert.equal(game.state.stage,1);
    assert.equal(game.state.journey?.area,route);
    assert.equal(game.state.journey?.wave,0);
    assert.equal(game.state.journey?.completedPrompts,12);
    assert.equal(game.state.score,atRoute.score);
    assert.equal(game.state.health,3);
    assert.equal(game.state.combo,0);
    assert.equal(game.state.attempts,2);
    assert.deepEqual(game.state.enemies.map(enemy=>enemy.phrase),firstRoutePhrases);

    reach(game,3);
    const atBoss=game.state;
    assert.equal(atBoss.journey?.completedPrompts,38);
    assert.equal(atBoss.luckyBonus,500);
    game.update(2);
    assert.equal(game.state.mode,'rest');
    game.continueRest();
    const firstBossPhrase=game.state.enemies[0].phrase;
    guard=0;
    const bossMode=()=>game.state.mode;
    while(bossMode()!=='defeat'&&guard++<15){
      if(bossMode()==='travel')game.update(1);
      else game.update(game.state.enemies[0].remaining+.01);
    }
    assert.ok(guard<15);
    game.retryCheckpoint();
    assert.equal(game.state.stage,3);
    assert.equal(game.state.mode,'rest');
    assert.equal(game.state.journey?.rest,'beforeBoss');
    assert.equal(game.state.journey?.travelProgress,1);
    assert.equal(game.state.enemies.length,0);
    assert.equal(game.state.bossPhase,0);
    assert.equal(game.state.journey?.completedPrompts,38);
    assert.equal(game.state.score,atBoss.score);
    assert.equal(game.state.luckyEncounters,1);
    assert.equal(game.state.luckyBonus,500);
    assert.equal(game.state.attempts,3);
    assert.equal(game.state.health,3);
    assert.equal(game.continueRest(),true);
    assert.equal(game.continueRest(),false);
    assert.equal(game.state.enemies[0].phrase,firstBossPhrase);
    guard=0;
    const finalMode=()=>game.state.mode;
    while(finalMode()!=='vista'&&guard++<20) advance(game);
    assert.ok(guard<20);
    assert.equal(game.state.journey?.completedPrompts,43);
    assert.equal(game.state.luckyEncounters,1);
    assert.equal(game.state.luckyClears,1);
    assert.equal(game.state.luckyBonus,500);
    assert.equal(game.state.rushes,1);
    assert.ok(game.state.chainKills<=8);
  }
});
