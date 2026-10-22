import {uiControls} from './ui-controls.mjs';
import {mkdir,writeFile,readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import path from 'node:path';
import assert from 'node:assert/strict';
const {chromium}=await import(process.env.PLAYWRIGHT_MODULE||'playwright');
const root=path.resolve(import.meta.dirname,'..');
const base=process.env.BASE_URL||'http://127.0.0.1:4198/';
const out=path.resolve(process.env.QA_OUT||path.join(root,'.cache/motion/motion-browser'));
await mkdir(out,{recursive:true});
const buildSha=createHash('sha256').update(await readFile(path.join(root,'dist/index.pck'))).digest('hex');
const browser=await chromium.launch({headless:true,executablePath:process.env.CHROMIUM_BIN||(process.platform==='darwin'?'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome':undefined),args:['--enable-unsafe-swiftshader']});
const context=await browser.newContext({viewport:{width:1280,height:720},deviceScaleFactor:1,recordVideo:{dir:path.join(out,'video'),size:{width:1280,height:720}}});
const page=await context.newPage();
const {click}=uiControls(page);
const report={base,build_sha256:buildSha,started:new Date().toISOString(),note:'Real Web keyboard and mouse input; no game state setters. Software renderer, not a physical GPU benchmark.',checks:{},samples:[],errors:[],external_requests:[]};
page.on('pageerror',e=>report.errors.push(String(e)));
page.on('console',m=>{if(m.type()==='error')report.errors.push(m.text());});
page.on('request',r=>{if(!r.url().startsWith(base)&&!r.url().startsWith('data:')&&!r.url().startsWith('blob:'))report.external_requests.push(r.url());});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const snap=()=>page.evaluate(()=>window.echoWitchSnapshot??null);
const until=state=>page.waitForFunction(s=>window.echoWitchSnapshot?.state===s,state,{timeout:25000});
const gui=screen=>page.waitForFunction(s=>window.echoWitchSnapshot?.gui?.page===s,screen,{timeout:10000});
const shot=(name,clip)=>page.screenshot({path:path.join(out,name+'.png'),...(clip?{clip}:{})});
async function choose(){let s=await snap();let n=0;while(['upgrade','treasure'].includes(s.state)&&n++<5){await page.keyboard.press('1');await sleep(150);s=await snap();}return s;}
async function sample(label,ms){const rows=[];const start=Date.now();let frame=0;while(Date.now()-start<ms){const s=await choose();assert.ok(s.motion?.player,'real presentation snapshot is available');assert.deepEqual(report.errors,[]);const row={label,elapsed:s.elapsed,state:s.state,player:s.player,echo:s.echo,motion:s.motion};rows.push(row);report.samples.push(row);if(frame++<6)await shot(label+'-'+String(frame).padStart(2,'0'),{x:555,y:270,width:170,height:165});await sleep(130);}return rows;}
function frozen(m){return {clock:m.clock,generation:m.generation,serial:m.serial,player:m.player,echo:m.echo,enemies:m.enemies,event_count:m.event_count,death_count:m.death_count,recent_events:m.recent_events,camera:m.camera,actors:m.actors,atlas:m.fx.atlas_texture_id};}
let final;
try{
 await page.goto(base);await until('title');await page.locator('#canvas').focus();
 assert.ok(await page.evaluate(()=>Object.isFrozen(window.echoWitchSnapshot)&&Object.isFrozen(window.echoWitchSnapshot.motion)));
 report.checks.read_only=true;
 await page.keyboard.press('Enter');await until('playing');
 const idle=await sample('idle',850);
 await page.keyboard.down('d');const moving=await sample('walk',1250);await page.keyboard.up('d');
 const delayed=await sample('echo-replay',2450);
 assert.ok(moving.some(r=>r.motion.player.moving),'actual movement drives the body');
 // The read-only bridge publishes at 4 Hz, so the first sample after key-up
 // can still contain actual displacement. Classify by observed motion, not
 // the wall-clock label of the input interval.
 const walks=[...moving,...delayed].filter(r=>r.motion.player.moving&&r.motion.player.animation==='walk').map(r=>r.motion.player.frame);
 assert.ok(new Set(walks).size>=2,'walking uses multiple actual sprite frames');
 assert.ok(delayed.some(r=>!r.motion.player.moving&&r.motion.echo.moving),'the stopped player and still-moving delayed echo have separate poses');
 assert.ok(new Set([...idle,...moving,...delayed].map(r=>r.motion.player.animation)).has('cast'),'an actual spell drives a cast pose');
 report.checks.walk_frames=true;report.checks.separate_echo_motion=true;report.checks.cast_pose=true;
 await choose();await page.keyboard.press('Escape');await until('paused');await shot('pause-1280');
 const paused=await snap();await sleep(1000);const still=await snap();assert.deepEqual(frozen(still.motion),frozen(paused.motion));report.checks.pause_freezes_motion=true;
 await page.setViewportSize({width:960,height:540});await sleep(300);await shot('pause-960');
 const resized=await snap();assert.equal(resized.elapsed,paused.elapsed);assert.deepEqual(resized.motion.player,paused.motion.player);assert.deepEqual(resized.motion.actors,paused.motion.actors);report.checks.resize_preserves_frames_and_textures=true;
 await page.setViewportSize({width:1280,height:720});await page.keyboard.press('r');await until('playing');await sleep(300);let s=await snap();
 assert.equal(s.chapter,0);assert.equal(s.level,1);assert.ok(s.elapsed<1.0);assert.equal(s.motion.death_count,0);assert.deepEqual(s.motion.actors,paused.motion.actors);assert.equal(s.motion.fx.atlas_texture_id,paused.motion.fx.atlas_texture_id);assert.ok(s.motion.generation>paused.motion.generation);report.checks.retry_reuses_textures_and_resets_feedback=true;
 await page.reload();await until('title');await click('title_settings');await gui('settings');await click('settings_reduced_motion');await sleep(250);assert.equal((await snap()).settings.reduced_motion,true);await page.keyboard.press('Escape');await gui('');await page.keyboard.press('Enter');await until('playing');
 await page.keyboard.down('d');const reduced=await sample('reduced-walk',1600);await page.keyboard.up('d');
 const reducedWalks=reduced.filter(r=>r.motion.player.animation==='walk');assert.ok(reducedWalks.length>=2);assert.equal(new Set(reducedWalks.map(r=>r.motion.player.frame)).size,1,'reduced motion holds a readable walking pose');assert.ok(reduced.every(r=>r.motion.camera.x===0&&r.motion.camera.y===0));report.checks.reduced_motion_still_frames_and_no_shake=true;
 s=await choose();await page.keyboard.press('Escape');await until('paused');await shot('reduced-pause');
 assert.deepEqual(report.errors,[]);assert.deepEqual(report.external_requests,[]);report.checks.console_clean=true;report.checks.no_external_requests=true;
 final=await snap();report.final=final;report.finished=new Date().toISOString();
}catch(e){report.failure=String(e.stack||e);try{await shot('failure');report.final=await snap();}catch{}process.exitCode=1;}
await context.close();await browser.close();await writeFile(path.join(out,'results.json'),JSON.stringify(report,null,2));
console.log(JSON.stringify({checks:report.checks,samples:report.samples.length,failure:report.failure,errors:report.errors,build_sha256:buildSha},null,2));
