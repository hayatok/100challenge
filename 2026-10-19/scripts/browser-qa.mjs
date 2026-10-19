import {mkdir,writeFile} from 'node:fs/promises';
import {existsSync} from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const {chromium}=await import(process.env.PLAYWRIGHT_MODULE||'playwright');
const root=path.resolve(import.meta.dirname,'..');
const base=process.env.BASE_URL||'http://127.0.0.1:4197/';
const out=path.resolve(process.env.QA_OUT||path.join(root,'docs/verification/browser/final'));
await mkdir(out,{recursive:true});
const chrome=process.env.CHROMIUM_BIN||(process.platform==='darwin'&&existsSync('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')?'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome':undefined);
const browser=await chromium.launch({headless:true,executablePath:chrome,args:['--enable-unsafe-swiftshader']});
const context=await browser.newContext({viewport:{width:1280,height:720},deviceScaleFactor:1});
const page=await context.newPage();
const report={base,renderer:'Headless Chromium; software WebGL may be used. This is not a physical-GPU benchmark.',actions:[],observations:[],errors:[],checks:{}};
page.on('pageerror',e=>report.errors.push(String(e)));
page.on('console',m=>{if(m.type()==='error')report.errors.push(m.text());});
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const snap=()=>page.evaluate(()=>window.echoWitchSnapshot??null);
const shot=name=>page.screenshot({path:path.join(out,name+'.png')});
async function key(name){await page.keyboard.press(name);report.actions.push({action:'key',key:name,wall:new Date().toISOString()});}
async function load(){await page.goto(base);await page.waitForFunction(()=>window.echoWitchSnapshot?.state==='title',undefined,{timeout:60000});}
async function until(state,timeout=10000){await page.waitForFunction(s=>window.echoWitchSnapshot?.state===s,state,{timeout});return snap();}
let held=[];
async function hold(keys){
 for(const key of held)if(!keys.includes(key))await page.keyboard.up(key);
 for(const key of keys)if(!held.includes(key))await page.keyboard.down(key);
 held=keys;
}
function choiceIndex(s){
 const priority=['moon_unlock','lightning_fork','moon_double','moon_range','power','lightning_haste','moon_haste','stride','heal','lightning_reach'];
 if(s.health<s.maximum_health*.55)priority.unshift('heal');
 for(const id of priority){const i=s.choices.findIndex(x=>x.id===id);if(i>=0)return i;}
 return 0;
}
try{
 await load();await shot('title-1280');
 await key('Enter');await until('playing');
 await hold(['d']);await sleep(2400);await hold([]);
 let s=await snap();
 if(s.state==='upgrade'){await key(String(choiceIndex(s)+1));await until('playing');s=await snap();}
 report.checks.echo_appears=s.echo.active&&Math.hypot(s.player.x-s.echo.x,s.player.y-s.echo.y)>40;
 assert.ok(report.checks.echo_appears,'moving must reveal the delayed echo');
 await shot('echo-position');
 await key('Escape');await until('paused');
 const paused=await snap();await sleep(1300);const still=await snap();
 assert.equal(still.elapsed,paused.elapsed,'pause must freeze simulation time');
 assert.deepEqual(still.player,paused.player,'pause must freeze player');
 assert.equal(still.pending_echo_attacks,paused.pending_echo_attacks,'pause must freeze echo schedule');
 report.checks.pause_freezes_time_position_echo=true;await shot('paused');
 await key('Enter');await until('playing');
 let firstUpgrade=false,midShot=false,lateShot=false,lastLog=-15,maxEnemies=0;
 const started=Date.now();
 while(Date.now()-started<310000){
  s=await snap();if(!s){await sleep(100);continue;}
  maxEnemies=Math.max(maxEnemies,s.enemy_count);
  if(s.state==='upgrade'){
   await hold([]);
   const before=s.elapsed;
   if(!firstUpgrade){await shot('upgrade');await sleep(1000);assert.equal((await snap()).elapsed,before);report.checks.upgrade_freezes_time=true;firstUpgrade=true;}
   const index=choiceIndex(s);report.observations.push({elapsed:s.elapsed,upgrade:s.choices[index]});
   await key(String(index+1));await sleep(160);continue;
  }
  if(s.state==='victory'||s.state==='defeat')break;
  assert.equal(s.state,'playing','unexpected state during normal play');
  // Follow a broad square with keyboard input. Nearby enemies cause a perpendicular detour.
  const leg=Math.floor(s.elapsed/4)%4;
  let move=[[1,0],[0,1],[-1,0],[0,-1]][leg];
  let near=null,distance=150;
  for(const e of s.enemies){const d=Math.hypot(e.x-s.player.x,e.y-s.player.y);if(d<distance){distance=d;near=e;}}
  if(near&&distance<105){const dx=s.player.x-near.x,dy=s.player.y-near.y;move=[Math.sign(dx),Math.sign(dy)];}
  await hold([...(move[0]>0?['d']:move[0]<0?['a']:[]),...(move[1]>0?['s']:move[1]<0?['w']:[])]);
  if(s.elapsed-lastLog>=15){lastLog=s.elapsed;const item={elapsed:s.elapsed,health:s.health,level:s.level,kills:s.kills,enemies:s.enemy_count,echo_shots:s.echo_shots};report.observations.push(item);console.log(JSON.stringify(item));}
  if(!midShot&&s.elapsed>65){await shot('playing-middle');midShot=true;}
  if(!lateShot&&s.elapsed>155){await shot('playing-late');lateShot=true;}
  await sleep(250);
 }
 await hold([]);s=await snap();report.final=s;report.max_enemies=maxEnemies;report.normal_run_wall_seconds=(Date.now()-started)/1000;
 await shot(s.state==='victory'?'victory':'defeat');
 assert.equal(s.state,'victory','normal-speed keyboard run must survive 180 seconds');
 assert.ok(s.elapsed>=180&&s.elapsed<180.1);
 assert.ok(s.echo_shots>10&&s.level>=2);
 report.checks.normal_speed_three_minutes=true;
 await key('Enter');await until('playing');
 s=await snap();assert.ok(s.elapsed<1&&s.level===1&&s.kills===0&&s.echo_shots===0);report.checks.retry_resets_run=true;
 // A real foreground-tab switch is used, not a synthetic blur event.
 const other=await context.newPage();await other.goto('about:blank');await other.bringToFront();await sleep(600);
 const focusObservable=await page.evaluate(()=>document.visibilityState==='hidden'||!document.hasFocus());
 await page.bringToFront();await sleep(300);
 s=await snap();report.focus_return=s.state;report.focus_observable=focusObservable;
 if(s.state==='paused'){await sleep(700);assert.equal((await snap()).elapsed,s.elapsed);report.checks.focus_loss_requires_resume=true;}else{report.checks.focus_loss_requires_resume=focusObservable?false:null;report.focus_note='Automation kept the document visible and focused. Verify real tab switching separately.';}
 await shot('focus-return');await other.close();
 for(const [width,height] of [[1920,1080],[960,540],[390,844]]){
  await page.setViewportSize({width,height});await page.reload();
  if(width>=760)await page.waitForFunction(()=>window.echoWitchSnapshot?.state==='title',undefined,{timeout:60000});else await page.getByText('横に広げて遊びます',{exact:true}).waitFor();
  await shot('title-'+width+'x'+height);
  const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth);assert.equal(overflow,false);report.checks['layout_'+width+'x'+height]=true;
 }
 await page.setViewportSize({width:1280,height:720});
 const failurePage=await context.newPage();await failurePage.route('**/*.wasm',route=>route.abort());await failurePage.goto(base);await failurePage.getByRole('button',{name:'もう一度読み込む'}).waitFor({timeout:60000});await failurePage.screenshot({path:path.join(out,'load-error.png')});
 await failurePage.unroute('**/*.wasm');await failurePage.getByRole('button',{name:'もう一度読み込む'}).click();await failurePage.waitForFunction(()=>window.echoWitchSnapshot?.state==='title',undefined,{timeout:60000});report.checks.load_failure_retry=true;await failurePage.close();
 assert.deepEqual(report.errors,[],'normal play must have no console errors');
 assert.notEqual(report.checks.focus_loss_requires_resume,false,'an observed focus loss must require explicit resume');
 report.success=true;
}catch(error){report.success=false;report.failure=String(error.stack||error);try{await shot('failure');report.failure_snapshot=await snap();}catch{}console.error(error);process.exitCode=1;}
finally{await writeFile(path.join(out,'results.json'),JSON.stringify(report,null,2));await browser.close();console.log('QA report: '+path.join(out,'results.json'));}
