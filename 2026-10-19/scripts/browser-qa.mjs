import {uiControls} from './ui-controls.mjs';
import {mkdir,writeFile,readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {existsSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import path from 'node:path';
import assert from 'node:assert/strict';
const {chromium}=await import(process.env.PLAYWRIGHT_MODULE||'playwright');
const root=path.resolve(import.meta.dirname,'..');
const base=process.env.BASE_URL||'http://127.0.0.1:4197/';
const mode=process.env.QA_MODE||'full';
const audioOff=process.env.QA_AUDIO_MODE==='off';
const probeSeconds=Math.max(30,Math.min(600,Number(process.env.QA_PROBE_SECONDS)||185));
const out=path.resolve(process.env.QA_OUT||path.join(root,'docs/verification/browser/campaign-'+mode));
await mkdir(out,{recursive:true});
const buildDir=path.resolve(process.env.QA_BUILD_DIR||path.join(root,'dist'));
const buildSha=createHash('sha256').update(await readFile(path.join(buildDir,'index.pck'))).digest('hex');
const executablePath=process.env.CHROMIUM_BIN||(process.platform==='darwin'&&existsSync('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')?'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome':undefined);
const browser=await chromium.launch({headless:true,executablePath,args:['--enable-unsafe-swiftshader']});
const context=await browser.newContext({viewport:{width:1280,height:720},deviceScaleFactor:1});
const page=await context.newPage();
const {click}=uiControls(page);
if(process.env.QA_GPU_PROBE==='1')await page.addInitScript(()=>{
 const counts={buffers:{created:0,deleted:0},vertex_arrays:{created:0,deleted:0},syncs:{created:0,deleted:0}};
 const prototype=globalThis.WebGL2RenderingContext?.prototype;
 if(!prototype)return;
 for(const [kind,createName,deleteName] of [['buffers','createBuffer','deleteBuffer'],['vertex_arrays','createVertexArray','deleteVertexArray'],['syncs','fenceSync','deleteSync']]){
  const create=prototype[createName],remove=prototype[deleteName];
  const live=new WeakSet();
  prototype[createName]=function(...args){const value=Reflect.apply(create,this,args);if(value){live.add(value);counts[kind].created++;}return value;};
  prototype[deleteName]=function(value,...args){if(value&&live.has(value)){live.delete(value);counts[kind].deleted++;}return Reflect.apply(remove,this,[value,...args]);};
 }
 Object.defineProperty(window,'__echoWitchGpuProbe',{get:()=>JSON.parse(JSON.stringify(counts))});
});
const report={base,mode,build_sha256:buildSha,audio_mode:audioOff?'off':'on',started:new Date().toISOString(),renderer:'Isolated headless Chrome; software WebGL may be used, not a physical GPU benchmark.',checks:{},observations:[],errors:[],external_requests:[],memory:[]};
const errors=report.errors;
page.on('pageerror',e=>errors.push(String(e)));
page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
page.on('request',r=>{if(!r.url().startsWith(base)&&!r.url().startsWith('data:')&&!r.url().startsWith('blob:'))report.external_requests.push(r.url());});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const snap=()=>page.evaluate(()=>window.echoWitchSnapshot??null);
const shot=name=>page.screenshot({path:path.join(out,name+'.png')});
const key=name=>page.keyboard.press(name);
const until=state=>page.waitForFunction(s=>window.echoWitchSnapshot?.state===s,state,{timeout:20000});
const gui=screen=>page.waitForFunction(s=>window.echoWitchSnapshot?.gui?.page===s,screen,{timeout:10000});
let held=[];
async function hold(keys){for(const k of held)if(!keys.includes(k))await page.keyboard.up(k);for(const k of keys)if(!held.includes(k))await page.keyboard.down(k);held=keys;}
async function load(){await page.goto(base);await until('title');await page.locator('#canvas').focus();}
let cdp,pageCdp;
try{cdp=await browser.newBrowserCDPSession();pageCdp=await context.newCDPSession(page);}catch{}
if(pageCdp&&process.env.QA_HEAP_SAMPLING==='1')await pageCdp.send('HeapProfiler.startSampling',{samplingInterval:32768});
async function memory(s,phase="first-run"){
 if(!cdp)return;
 try{const {processInfo}=await cdp.send('SystemInfo.getProcessInfo');const ids=processInfo.filter(p=>p.type==='renderer').map(p=>p.id);if(!ids.length)return;const rows=execFileSync('ps',['-o','pid=,rss=','-p',ids.join(',')],{encoding:'utf8'}).trim().split('\n').map(l=>l.trim().split(/\s+/).map(Number));const heap=pageCdp?await pageCdp.send('Runtime.getHeapUsage'):null;const row={phase,elapsed:s.elapsed,chapter:s.chapter,perf:s.perf,js_heap:heap,snapshot_chars:JSON.stringify(s).length,renderers:rows.map(([pid,rss_kib])=>({pid,rss_kib}))};if(process.env.QA_GPU_PROBE==='1')row.gpu_allocations=await page.evaluate(()=>window.__echoWitchGpuProbe??null);report.memory.push(row);await writeFile(path.join(out,'progress.json'),JSON.stringify({memory:report.memory,last:s},null,2));}catch(e){report.memory_note=String(e);}
}
function assertFreshEcho(s){
 // A browser observes a later physics tick than the input event. New casts may
 // already be queued; the model tests check that the old queue is empty at reset.
 assert.ok(s.chapter_elapsed>=0&&s.chapter_elapsed<0.5,'fresh scene observed promptly');
 assert.equal(s.echo.active,false);
 assert.deepEqual(s.last_echo_attack,{});
 assert.ok(s.history_samples<=Math.ceil(s.chapter_elapsed*60)+2,'history belongs to the new scene');
}
const dist=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y);
function rects(s){return Array.isArray(s.arena?.obstacles)?s.arena.obstacles:[];}
function clear(s,p,r=25){const b=s.arena?.bounds;if(b&&(p.x<b.x+r||p.x>b.x+b.width-r||p.y<b.y+r||p.y>b.y+b.height-r))return false;return !rects(s).some(o=>p.x>o.x-r&&p.x<o.x+o.width+r&&p.y>o.y-r&&p.y<o.y+o.height+r);}
function route(s,target){
 const step=64,b=s.arena?.bounds??{x:-1100,y:-800,width:2200,height:1600};
 const cell=p=>[Math.round((p.x-b.x)/step),Math.round((p.y-b.y)/step)];const pos=([x,y])=>({x:b.x+x*step,y:b.y+y*step});const tag=c=>c.join(',');
 let start=cell(s.player),goal=cell(target);const open=[start],came=new Map(),g=new Map([[tag(start),0]]),closed=new Set();
 let best=start,bestD=Infinity;
 for(let iter=0;open.length&&iter<1600;iter++){
  open.sort((a,z)=>(g.get(tag(z))+Math.hypot(z[0]-goal[0],z[1]-goal[1]))-(g.get(tag(a))+Math.hypot(a[0]-goal[0],a[1]-goal[1])));
  const here=open.pop(),hk=tag(here);if(closed.has(hk))continue;closed.add(hk);const d=Math.hypot(here[0]-goal[0],here[1]-goal[1]);if(d<bestD){best=here;bestD=d;}if(d<1.5)break;
  for(const dx of [-1,0,1])for(const dy of [-1,0,1]){if(!dx&&!dy)continue;const next=[here[0]+dx,here[1]+dy],nk=tag(next);if(closed.has(nk)||!clear(s,pos(next),30))continue;if(dx&&dy&&(!clear(s,pos([here[0]+dx,here[1]]),30)||!clear(s,pos([here[0],here[1]+dy]),30)))continue;const cost=g.get(hk)+Math.hypot(dx,dy);if(cost<(g.get(nk)??Infinity)){g.set(nk,cost);came.set(nk,here);open.push(next);}}
 }
 let current=best;const chain=[current];while(came.has(tag(current))){current=came.get(tag(current));chain.push(current);}chain.reverse();return pos(chain[Math.min(chain.length-1,2)]);
}
function hazardRisk(h,p,s){
 const age=h.age??0,delay=h.delay??0;if(age+0.55<delay)return 0;const center={x:h.x??h.position?.x??0,y:h.y??h.position?.y??0};const shape=h.shape??'circle';let d=dist(p,center);
 if(shape==='line'){const a=h.from??center,b=h.to??center;const dx=b.x-a.x,dy=b.y-a.y,t=Math.max(0,Math.min(1,((p.x-a.x)*dx+(p.y-a.y)*dy)/(dx*dx+dy*dy||1)));d=Math.hypot(p.x-a.x-t*dx,p.y-a.y-t*dy)-(h.width??40)/2;}
 else if(shape==='ring')d=Math.abs(d-(h.radius??100))-(h.width??40)/2;
 else d-=h.radius??60;
 return d<35?1400+(35-d)*8:d<100?(100-d)*2:0;
}
let waypoint=0,goal=null,goalUntil=0;
function steering(s){
 const p=s.player,boss=s.boss?.hp>0?s.boss:null;
 if(!goal||s.elapsed>goalUntil||dist(p,goal)<75){
  goalUntil=s.elapsed+3;
  const chests=(s.chests??[]).filter(c=>!c.opened).sort((a,b)=>dist(p,a)-dist(p,b));
  const xp=(s.pickups??[]).filter(x=>x.kind==='xp'||x.kind==='heal'||x.kind==='magnet'||!x.kind).sort((a,b)=>dist(p,a)-dist(p,b));
  if(s.health<s.maximum_health*.65&&(s.pickups??[]).some(x=>x.kind==='heal'))goal=(s.pickups??[]).filter(x=>x.kind==='heal').sort((a,b)=>dist(p,a)-dist(p,b))[0];
  else if(boss){const theta=Math.atan2(p.y-boss.y,p.x-boss.x)+0.75;goal={x:boss.x+Math.cos(theta)*240,y:boss.y+Math.sin(theta)*240};}
  else if(chests[0]&&dist(p,chests[0])<600)goal=chests[0];
  else if(xp[0]&&dist(p,xp[0])<600)goal=xp[0];
  else{const b=s.arena?.bounds??{x:-1100,y:-800,width:2200,height:1600};const a=waypoint++*Math.PI/4;goal={x:(b.x+b.width/2)+Math.cos(a)*b.width*.29,y:(b.y+b.height/2)+Math.sin(a)*b.height*.29};}
  if(!clear(s,goal,35)){const alternatives=[];for(let a=0;a<8;a++){const origin=boss??{x:0,y:0};alternatives.push({x:origin.x+Math.cos(a*Math.PI/4)*250,y:origin.y+Math.sin(a*Math.PI/4)*250});}goal=alternatives.filter(q=>clear(s,q,35)).sort((a,b)=>dist(p,a)-dist(p,b))[0]??{...p};}
 }
 const nearGoal=route(s,goal);let best=null,bestScore=-Infinity;
 for(let ix=-1;ix<=1;ix++)for(let iy=-1;iy<=1;iy++){
  if(!ix&&!iy)continue;const scale=(s.speed??215)*.36/Math.hypot(ix,iy);const q={x:p.x+ix*scale,y:p.y+iy*scale};if(!clear(s,q,27))continue;
  let score=(dist(p,nearGoal)-dist(q,nearGoal))*2;
  for(const e of s.enemies??[]){if(e.hp<=0||e.phase==='arrival')continue;const radius=e.radius??(e.boss?45:20),d=dist(q,e)-radius;score-=d<50?1800+(50-d)*15:d<145?(145-d)*2:0;if(e.phase==='rush'&&d<250)score-=200;}
  for(const h of s.hazards??[])score-=hazardRisk(h,q,s);
  if(boss){const d=dist(q,boss);score-=Math.abs(d-255)*.16;}
  if(score>bestScore){bestScore=score;best=[ix,iy];}
 }
 if(!best){goal=null;return [];}
 return [...(best[0]?[best[0]>0?'d':'a']:[]),...(best[1]?[best[1]>0?'s':'w']:[])];
}
function choose(s){
 const choices=s.choices??[],equipment=s.equipment??{weapons:[],relics:[]};
 const spec=process.env.QA_SPECIALIZATION||'spec_moon';let i=choices.findIndex(x=>x.id===spec);if(i>=0)return i;
 if(s.choice_phase==='replace')return 0;
 i=choices.findIndex(x=>x.kind==='evolution');if(i>=0)return i;
 if(s.health<s.maximum_health*.6){i=choices.findIndex(x=>x.kind==='heal'||x.id==='heal');if(i>=0)return i;}
 const desired=['moon','wisp','lightning'],pairs={moon:'moonstone',lightning:'storm_ink',wisp:'lantern_oil'};
 const owned=equipment.weapons??[],relics=(equipment.relics??[]).map(x=>x.id);
 for(const id of desired){const weapon=owned.find(x=>x.id===id);if(weapon&&weapon.level>=4&&!relics.includes(pairs[id])&&relics.length<3){i=choices.findIndex(x=>x.id==='relic:'+pairs[id]);if(i>=0)return i;}}
 for(const id of desired){const weapon=owned.find(x=>x.id===id);if(!weapon&&owned.length>=3)continue;i=choices.findIndex(x=>x.id==='weapon:'+id||x.id===id);if(i>=0)return i;}
 for(const id of desired){if(!relics.includes(pairs[id])&&relics.length<3){i=choices.findIndex(x=>x.id==='relic:'+pairs[id]);if(i>=0)return i;}}
 i=choices.findIndex(x=>x.kind==='heal'||x.id==='heal');if(i>=0)return i;
 i=choices.findIndex(x=>x.kind==='weapon'&&owned.some(w=>x.id==='weapon:'+w.id));if(i>=0)return i;
 i=choices.findIndex(x=>x.kind==='relic'&&relics.length<3);return i>=0?i:0;
}
try{
 await load();await shot('title-1280');
 assert.ok(await page.evaluate(()=>Object.isFrozen(window.echoWitchSnapshot)&&Object.getOwnPropertyDescriptor(window,'echoWitchSnapshot').writable===false));report.checks.snapshot_read_only=true;assert.ok(await page.evaluate(()=>!Object.hasOwn(window,'__echoWitchSnapshotPublisherInit')));report.checks.no_public_publisher=true;
 await key('c');await gui('codex');await shot('codex-initial');await key('Escape');await gui('');
 await click('title_settings');await gui('settings');await shot('settings');
 await click('settings_sound');await click('settings_reduced_motion');await click('settings_large_text');await sleep(400);
 let s=await snap();assert.equal(s.settings.sound,false);assert.equal(s.settings.reduced_motion,true);assert.equal(s.settings.large_text,true);report.checks.settings_actual_mouse=true;await shot('settings-large');
 await page.reload();await until('title');s=await snap();assert.equal(s.settings.sound,false);assert.equal(s.settings.reduced_motion,true);assert.equal(s.settings.large_text,true);report.checks.settings_persist_reload=true;
 await click('title_settings');await gui('settings');await click('settings_sound');await click('settings_reduced_motion');await click('settings_large_text');if(audioOff)await click('settings_sound');await key('Escape');await gui('');
 await key('Enter');await until('playing');await hold(['d']);await sleep(2400);await hold([]);s=await snap();
 if(s.state==='upgrade'){await key(String(choose(s)+1));await sleep(250);s=await snap();}
 assert.ok(s.echo.active&&dist(s.player,s.echo)>30,'delayed echo appears at separated position');report.checks.echo_position=true;await shot('echo');
 await key('Escape');await until('paused');const paused=await snap();await sleep(1100);const frozen=await snap();assert.equal(frozen.elapsed,paused.elapsed);assert.deepEqual(frozen.player,paused.player);assert.deepEqual(frozen.echo,paused.echo);assert.equal(frozen.audio.music_paused,!audioOff);if(audioOff)assert.equal(frozen.audio.music_active,false);report.checks.pause_freezes=true;await shot('pause-loadout');if(mode==='full'||mode==='probe'){await memory(frozen,'pause-start');await sleep(30000);const still=await snap();assert.equal(still.elapsed,paused.elapsed);await memory(still,'pause-after-30s');}
 await key('c');await gui('codex');await shot('codex-paused');await key('Escape');await gui('');
 for(const [w,h] of [[1920,1080],[960,540]]){await page.setViewportSize({width:w,height:h});await sleep(350);await shot('paused-'+w);assert.equal((await snap()).elapsed,paused.elapsed);}
 await page.setViewportSize({width:1280,height:720});await key('Escape');await until('playing');
 let lastLog=-30,lastMemory=-30,firstUpgrade=false,rerolled=false,skipped=false;const seenChapters=new Set(),seenBosses=new Set(),seenBattleArt=new Set(),seenFloor=new Set();let lastState='',lastChapter=-1;
 const started=Date.now(),limit=mode==='smoke'?90000:1200000;
 while(Date.now()-started<limit){
  s=await snap();assert.deepEqual(errors,[],'no runtime error');seenChapters.add(s.chapter);
  if(s.state!==lastState||s.chapter!==lastChapter){report.observations.push({state:s.state,elapsed:s.elapsed,chapter:s.chapter,health:s.health,level:s.level});lastState=s.state;lastChapter=s.chapter;}
  if(s.state==='upgrade'||s.state==='treasure'){
   await hold([]);
   if(!firstUpgrade){firstUpgrade=true;await shot('upgrade');const time=s.elapsed;await sleep(800);assert.equal((await snap()).elapsed,time);report.checks.choice_freezes=true;}
   if(!rerolled&&s.state==='upgrade'&&s.choice_phase!=='replace'&&s.rerolls_left>0){const n=s.rerolls_left;await key('r');await sleep(300);s=await snap();assert.equal(s.rerolls_left,n-1);rerolled=true;report.checks.actual_reroll=true;await shot('rerolled');}
   if(mode==='smoke'&&!skipped&&s.state==='upgrade'&&s.skips_left>0){const n=s.skips_left;await key('x');await sleep(300);assert.equal((await snap()).skips_left,n-1);skipped=true;report.checks.actual_skip=true;continue;}
   if(s.state==='treasure'){await shot('treasure-ch'+s.chapter);report.checks.treasure_actual=true;}
   const i=choose(s);report.observations.push({choice:s.choices[i],chapter:s.chapter,elapsed:s.elapsed});await key(String(i+1));await sleep(180);continue;
  }
  if(s.state==='chapter_clear'){
   await hold([]);await shot('chapter-clear-'+s.chapter);const carry=e=>({weapons:e.weapons.map(({rank_cap,...w})=>w),relics:e.relics,weapon_slots:e.weapon_slots,relic_slots:e.relic_slots});const e=carry(s.equipment);const level=s.level;const chapter=s.chapter;await sleep(600);assert.equal((await snap()).elapsed,s.elapsed);await key('Enter');await until('playing');const next=await snap();assert.equal(next.chapter,chapter+1);assert.equal(next.level,level);assert.deepEqual(carry(next.equipment),e);assert.equal(next.equipment.rank_cap,Math.min(5,chapter+4));assertFreshEcho(next);report.checks['chapter_'+chapter+'_carry']=true;goal=null;continue;
  }
  if(['victory','defeat'].includes(s.state))break;
  assert.equal(s.state,'playing');
  if(s.chapter_elapsed>20&&!seenFloor.has(s.chapter)){seenFloor.add(s.chapter);await shot('chapter-'+s.chapter+'-playing');}if(s.chapter_stage==='boss'&&!seenBosses.has(s.chapter)){seenBosses.add(s.chapter);await shot('boss-'+s.chapter);}if(s.boss?.hp>0&&s.boss.hp<s.boss.max_hp*.65&&!seenBattleArt.has(s.chapter)){seenBattleArt.add(s.chapter);await shot('boss-'+s.chapter+'-battle');}
  await hold(steering(s));
  if(s.elapsed-lastLog>=15){lastLog=s.elapsed;const row={elapsed:s.elapsed,chapter:s.chapter,boss:s.boss?.hp??0,health:s.health,level:s.level,kills:s.kills,enemies:s.enemy_count,flanks:s.resonance_hits,fps:s.perf?.fps,music:s.audio.music_starts};console.log(JSON.stringify(row));report.observations.push(row);}
  if(s.elapsed-lastMemory>=30){lastMemory=s.elapsed;await memory(s);}
  if(mode==='smoke'&&firstUpgrade&&s.elapsed>35)break;if(mode==='probe'&&s.elapsed>probeSeconds)break;
  await sleep(250);
 }
 await hold([]);s=await snap();
 if(process.env.QA_HEAP_DIAGNOSTIC==='1'&&pageCdp){
  if(s.state==='playing'){await key('Escape');await until('paused');}
  await memory(await snap(),'diagnostic-before-gc');
  await pageCdp.send('HeapProfiler.collectGarbage');
  await memory(await snap(),'diagnostic-after-gc');
  if(process.env.QA_HEAP_SAMPLING==='1'){
   const sampled=await pageCdp.send('HeapProfiler.stopSampling');
   await writeFile(path.join(out,'heap-allocation.json'),JSON.stringify(sampled));
   report.heap_profile='Private allocation sampling saved for retained-allocation diagnosis.';
  }
  report.heap_diagnostic='Separate forced-GC diagnostic, not part of ordinary full-run memory samples.';
  s=await snap();
 }
 report.final=s;report.wall_seconds=(Date.now()-started)/1000;report.seen_chapters=[...seenChapters];report.seen_bosses=[...seenBosses];await shot('final-'+s.state);
 if(mode==='full'){assert.equal(s.state,'victory','actual keyboard run completes all three bosses');assert.equal(seenChapters.size,3);assert.equal(seenBosses.size,3);report.checks.full_campaign_actual=true;const finishedEquipment=s.equipment;await click('result_loadout');await gui('loadout');assert.deepEqual((await snap()).equipment,finishedEquipment);await shot('victory-loadout');await key('Escape');await gui('');assert.equal((await snap()).state,'victory');report.checks.result_loadout=true;
  const musicStarts=s.audio.music_starts;await key('r');await until('playing');const restart=await snap();assert.equal(restart.chapter,0);assert.equal(restart.level,1);assert.equal(restart.health,restart.maximum_health);assertFreshEcho(restart);
  const again=Date.now();goal=null;while(Date.now()-again<60000){const r=await snap();if(r.state==='upgrade'||r.state==='treasure'){await hold([]);await key(String(choose(r)+1));await sleep(180);continue;}assert.equal(r.state,'playing');await hold(steering(r));if(r.elapsed>35){await memory(r,'second-run');break;}await sleep(250);}await hold([]);report.retry_snapshot=await snap();assert.ok(report.retry_snapshot.elapsed>35);assert.equal(report.retry_snapshot.audio.music_starts,musicStarts+1);report.checks.same_page_second_run=true;await key('Escape');await until('paused');const t=(await snap()).elapsed;await sleep(600);assert.equal((await snap()).elapsed,t);await shot('second-run-paused');
 }
 else assert.ok(firstUpgrade,'smoke reaches an upgrade');
 await key('Escape');s=await snap();if(s.state==='paused')await shot('smoke-final-paused');
 await page.reload();await until('title');s=await snap();assert.ok(s.profile,'profile available');report.profile_after_reload=s.profile;report.checks.profile_reload=true;if(mode==='full'){assert.deepEqual([...s.profile.data.clears].sort(),[0,1,2]);assert.equal(s.profile.data.starters.length,6);assert.ok(s.profile.data.best.victories>=1);report.checks.clear_unlocks_persist=true;}await key('c');await gui('codex');await shot('codex-after-play');await key('Escape');
 await page.setViewportSize({width:390,height:844});await page.reload();await page.getByText('横に広げて遊びます',{exact:true}).waitFor();await shot('portrait-guide');assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);report.checks.portrait_guide=true;
 assert.deepEqual(report.external_requests,[],'all game content local to current site');report.checks.no_external_requests=true;
 assert.deepEqual(errors,[]);report.success=true;
}catch(e){report.success=false;report.failure=String(e.stack||e);try{await hold([]);await shot('failure');report.failure_snapshot=await snap();}catch{}console.error(e);process.exitCode=1;}
finally{report.build_sha256_after=createHash('sha256').update(await readFile(path.join(buildDir,'index.pck'))).digest('hex');if(report.build_sha256_after!==buildSha){report.success=false;report.build_changed=true;process.exitCode=1;}await writeFile(path.join(out,'results.json'),JSON.stringify(report,null,2));await browser.close();console.log('QA report: '+path.join(out,'results.json'));}
