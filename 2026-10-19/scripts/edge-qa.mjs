import {mkdir,writeFile,readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import path from 'node:path';
import assert from 'node:assert/strict';
const pw=await import(process.env.PLAYWRIGHT_MODULE||'playwright');
const kind=process.env.QA_BROWSER||'chromium';
const base=process.env.BASE_URL||'http://127.0.0.1:4197/';
const root=path.resolve(import.meta.dirname,'..');
const out=path.resolve(process.env.QA_OUT||path.join(root,'.cache/campaign-edge-'+kind));
await mkdir(out,{recursive:true});
const opts={headless:true,timeout:60000};
if(kind==='chromium'){opts.executablePath=process.env.CHROMIUM_BIN||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';opts.args=['--enable-unsafe-swiftshader'];}
let browser;
try{browser=await pw[kind].launch(opts);}catch(e){await writeFile(path.join(out,'launch-failure.json'),JSON.stringify({success:false,browser:kind,stage:'browser-launch',failure:String(e),note:'The game was not loaded; this is a test-browser setup failure.'},null,2));throw e;}
const report={browser:kind,version:browser.version(),started:new Date().toISOString(),checks:{},errors:[],external_requests:[],observations:[],note:'Isolated automated browser; real keyboard input, no gameplay state changes. WebKit is a test engine, not physical Safari.'};
const context=await browser.newContext({viewport:{width:1280,height:720},deviceScaleFactor:1});
const page=await context.newPage();
page.on('pageerror',e=>report.errors.push(String(e)));
page.on('console',m=>{if(m.type()==='error')report.errors.push(m.text());});
page.on('request',r=>{if(!r.url().startsWith(base)&&!r.url().startsWith('data:')&&!r.url().startsWith('blob:'))report.external_requests.push(r.url());});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const snap=()=>page.evaluate(()=>window.echoWitchSnapshot??null);
const until=state=>page.waitForFunction(s=>window.echoWitchSnapshot?.state===s,state,{timeout:60000});
const shot=name=>page.screenshot({path:path.join(out,name+'.png')});
let held=[];
async function hold(keys){for(const k of held)if(!keys.includes(k))await page.keyboard.up(k);for(const k of keys)if(!held.includes(k))await page.keyboard.down(k);held=keys;}
try{
 await page.goto(base);await until('title');await shot('title');await page.mouse.click(350,403);await page.waitForFunction(()=>window.echoWitchSnapshot?.gui?.page==='starters');await page.mouse.click(635,250);await page.waitForFunction(()=>window.echoWitchSnapshot?.gui?.page==='');assert.equal((await snap()).gui.starter,'moon');await page.locator('#canvas').focus();await page.keyboard.press('Enter');await until('playing');
 await hold(['d']);await sleep(2300);await hold([]);let s=await snap();assert.ok(s.echo.active);assert.ok(Math.hypot(s.player.x-s.echo.x,s.player.y-s.echo.y)>30);report.checks.echo=true;await shot('playing');
 // Moving keyboard focus outside the canvas is a real DOM focus change.
 await page.locator('#legal').focus();await until('paused');const stopped=await snap();await sleep(650);assert.equal((await snap()).elapsed,stopped.elapsed);await page.locator('#canvas').focus();await sleep(300);assert.equal((await snap()).state,'paused');report.checks.focus_loss_freezes_until_explicit_resume=true;await shot('focus-return');await page.keyboard.press('Escape');await until('playing');
 const started=Date.now();let lastLog=-30;
 while(Date.now()-started<180000){
  s=await snap();if(s.state==='defeat')break;
  if(['upgrade','treasure'].includes(s.state)){await hold([]);let i=s.choices.findIndex(c=>c.id==='spec_echo');if(i<0)i=s.choices.findIndex(c=>c.kind==='relic'&&!['blood_vial','ward_leaf'].includes(c.item_id));if(i<0)i=s.choices.findIndex(c=>c.kind==='heal');if(i<0)i=s.choices.findIndex(c=>c.id==='weapon:moon');await page.keyboard.press(String((i<0?0:i)+1));await sleep(200);continue;}
  assert.equal(s.state,'playing');if(s.elapsed-lastLog>=15){lastLog=s.elapsed;console.log(JSON.stringify({elapsed:s.elapsed,health:s.health,level:s.level,enemies:s.enemy_count,fps:s.perf?.fps}));}const e=(s.enemies??[]).filter(x=>x.hp>0).sort((a,b)=>Math.hypot(a.x-s.player.x,a.y-s.player.y)-Math.hypot(b.x-s.player.x,b.y-s.player.y))[0];
  if(e){const dx=e.x-s.player.x,dy=e.y-s.player.y;await hold([...(Math.abs(dx)>6?[dx>0?'d':'a']:[]),...(Math.abs(dy)>6?[dy>0?'s':'w']:[])]);}else await hold([]);
  await sleep(200);
 }
 await hold([]);s=await snap();assert.equal(s.state,'defeat','normal contact can cause defeat');report.defeat=s;report.checks.defeat_actual=true;await shot('defeat');
 const defeatedEquipment=s.equipment;await page.mouse.click(703,570);await page.waitForFunction(()=>window.echoWitchSnapshot?.gui?.page==='loadout');assert.deepEqual((await snap()).equipment,defeatedEquipment);await shot('defeat-loadout');await page.keyboard.press('Escape');await page.waitForFunction(()=>window.echoWitchSnapshot?.gui?.page==='');assert.equal((await snap()).state,'defeat');report.checks.result_loadout=true;const musicStarts=s.audio.music_starts;await page.keyboard.press('r');await until('playing');s=await snap();assert.equal(s.chapter,0);assert.equal(s.level,1);assert.equal(s.health,s.maximum_health);assert.equal(s.echo.active,false);assert.deepEqual(s.last_echo_attack,{});assert.ok(s.history_samples<=Math.ceil(s.chapter_elapsed*60)+2);assert.ok(s.elapsed<1);await page.waitForFunction(n=>window.echoWitchSnapshot?.audio?.music_starts>n,musicStarts,{timeout:5000});assert.equal((await snap()).audio.music_active,true);report.checks.retry_resets_run=true;
 await page.keyboard.press('Escape');await until('paused');s=await snap();
 for(const [width,height] of [[960,540],[1920,1080]]){await page.setViewportSize({width,height});await sleep(350);assert.equal((await snap()).elapsed,s.elapsed);await shot('pause-'+width);}
 report.checks.resize_paused_freezes=true;
 assert.deepEqual(report.errors,[]);assert.deepEqual(report.external_requests,[]);report.checks.console_clean=true;report.checks.no_external_requests=true;
 if(kind==='chromium'){
  const broken=await context.newPage();const expected=[];broken.on('console',m=>{if(m.type()==='error')expected.push(m.text());});broken.on('pageerror',e=>expected.push(String(e)));
  await broken.route('**/index.wasm',r=>r.abort('failed'));await broken.goto(base);await broken.getByRole('button',{name:'もう一度読み込む'}).waitFor({timeout:30000});await broken.screenshot({path:path.join(out,'load-error.png')});await broken.unroute('**/index.wasm');await broken.getByRole('button',{name:'もう一度読み込む'}).click();await broken.waitForFunction(()=>window.echoWitchSnapshot?.state==='title',null,{timeout:60000});await broken.screenshot({path:path.join(out,'load-recovered.png')});report.checks.load_error_and_retry=true;report.expected_load_errors=expected;await broken.close();
 }
 report.success=true;
}catch(e){report.success=false;report.failure=String(e.stack||e);try{await hold([]);report.snapshot=await snap();await shot('failure');}catch{}console.error(e);process.exitCode=1;}
finally{report.finished=new Date().toISOString();report.build_sha256=createHash('sha256').update(await readFile(path.join(root,'dist/index.pck'))).digest('hex');await writeFile(path.join(out,'results.json'),JSON.stringify(report,null,2));await browser.close();console.log('Edge report: '+path.join(out,'results.json'));}
