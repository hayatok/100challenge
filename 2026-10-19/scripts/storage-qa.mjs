import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {existsSync} from 'node:fs';
import {mkdir,readFile,writeFile} from 'node:fs/promises';
import path from 'node:path';

// Storage fixtures and overrides exist only inside fresh, disposable browser contexts.
// The game is controlled by real mouse/keyboard input; its public snapshot stays read-only.
const {chromium}=await import(process.env.PLAYWRIGHT_MODULE||'playwright');
const root=path.resolve(import.meta.dirname,'..');
const base=process.env.BASE_URL||'http://127.0.0.1:4197/';
const origin=new URL(base).origin;
const out=path.resolve(process.env.QA_OUT||path.join(root,'.cache/campaign-storage'));
const storageKey='echo-witch-profile-v1';
const executablePath=process.env.CHROMIUM_BIN||(process.platform==='darwin'&&existsSync('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')?'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome':undefined);
await mkdir(out,{recursive:true});
const browser=await chromium.launch({headless:true,executablePath,args:['--enable-unsafe-swiftshader']});
const report={base,started:new Date().toISOString(),environment:'Isolated headless Chrome, fresh context for every scenario; software WebGL.',cases:[],success:false};
const delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const fingerprint=async()=>createHash('sha256').update(await readFile(path.join(root,'dist/index.pck'))).digest('hex');
try{report.pck_sha256_before=await fingerprint();}catch{}

async function scenario(name,fixture,body){
 const row={name,fixture:fixture.mode,checks:[],console:[],page_errors:[],external_requests:[],expected_storage_faults:[],screenshots:[],success:false};
 report.cases.push(row);
 const context=await browser.newContext({viewport:{width:1280,height:720},deviceScaleFactor:1});
 if(fixture.mode!=='normal'){
  await context.addInitScript(({fixture,key,origin})=>{
   if(location.origin!==origin)return;
   const storage=window.localStorage;
   const nativeGet=Storage.prototype.getItem;
   const nativeSet=Storage.prototype.setItem;
   const marker='echo-witch-storage-qa-initialized';
   if(!sessionStorage.getItem(marker)){
    if(Object.hasOwn(fixture,'raw'))nativeSet.call(storage,key,fixture.raw);
    sessionStorage.setItem(marker,'yes');
   }
   const faults=[];
   Object.defineProperty(window,'__echoStorageQA',{configurable:false,value:{
    faults,
    original:()=>nativeGet.call(storage,key),
   }});
   if(fixture.mode==='blocked_read'){
    Object.defineProperty(window,'localStorage',{configurable:true,get(){
     faults.push({operation:'read storage',name:'SecurityError'});
     throw new DOMException('Storage disabled by isolated QA fixture','SecurityError');
    }});
   }
   if(fixture.mode==='blocked_write'){
    Storage.prototype.setItem=function(item,value){
     if(this===storage&&String(item).startsWith(key)){
      faults.push({operation:'write storage',name:'QuotaExceededError'});
      throw new DOMException('Storage quota exhausted by isolated QA fixture','QuotaExceededError');
     }
     return nativeSet.call(this,item,value);
    };
   }
  },{fixture,key:storageKey,origin});
 }
 const page=await context.newPage();
 page.on('console',message=>row.console.push({type:message.type(),text:message.text()}));
 page.on('pageerror',error=>row.page_errors.push(String(error)));
 page.on('request',request=>{if(!request.url().startsWith(origin+'/')&&!request.url().startsWith('data:')&&!request.url().startsWith('blob:'))row.external_requests.push(request.url());});
 const snapshot=()=>page.evaluate(()=>window.echoWitchSnapshot??null);
 const wait=async predicate=>{
  await page.waitForFunction(predicate,null,{timeout:20000});
  return snapshot();
 };
 const state=stateName=>page.waitForFunction(value=>window.echoWitchSnapshot?.state===value,stateName,{timeout:20000});
 const gui=pageName=>page.waitForFunction(value=>window.echoWitchSnapshot?.gui?.page===value,pageName,{timeout:10000});
 const click=async(x,y)=>{
  const canvas=await page.locator('#canvas').boundingBox();
  assert.ok(canvas&&canvas.width>0&&canvas.height>0,'real game canvas is visible');
  await page.mouse.click(canvas.x+x*canvas.width/1280,canvas.y+y*canvas.height/720);
 };
 const key=keyName=>page.keyboard.press(keyName);
 const check=(condition,label)=>{assert.ok(condition,label);row.checks.push(label);};
 const equal=(actual,expected,label)=>{assert.deepEqual(actual,expected,label);row.checks.push(label);};
 const shot=async suffix=>{
  const filename=name+'-'+suffix+'.png';
  await page.screenshot({path:path.join(out,filename)});
  row.screenshots.push(filename);
 };
 const load=async()=>{
  await page.goto(base);
  await page.locator('#canvas').waitFor({state:'visible'});
  await state('title');
  await page.locator('#canvas').focus();
  check(await page.evaluate(()=>document.getElementById('status').hidden),'HTML loading view yields to the live game canvas');
  return snapshot();
 };
 const raw=()=>page.evaluate(key=>localStorage.getItem(key),storageKey);
 const original=()=>page.evaluate(()=>window.__echoStorageQA?.original());
 const openSettings=async()=>{await click(488,556);await gui('settings');};
 const openWarning=async()=>{await click(326,674);await gui('storage');};
 try{
  await body({page,load,snapshot,wait,state,gui,click,key,check,equal,shot,raw,original,openSettings,openWarning,row});
  row.final=await snapshot();
  row.expected_storage_faults=await page.evaluate(()=>window.__echoStorageQA?.faults??[]);
  if(fixture.mode.startsWith('blocked_'))check(row.expected_storage_faults.length>0,'isolated storage fixture actually exercised the intended failure');
  equal(row.page_errors,[],'no unhandled page exception');
  equal(row.console.filter(message=>message.type==='error'),[],'no game or browser console error');
  equal(row.external_requests,[],'all requested assets are local to the game origin');
  row.success=true;
 }catch(error){
  row.failure=String(error.stack||error);
  try{await shot('failure');row.failure_snapshot=await snapshot();row.expected_storage_faults=await page.evaluate(()=>window.__echoStorageQA?.faults??[]);}catch{}
  console.error(name+': '+String(error));
 }finally{
  await writeFile(path.join(out,name+'.json'),JSON.stringify(row,null,2));
  await context.close();
  console.log(JSON.stringify({case:name,success:row.success,checks:row.checks.length,console_errors:row.console.filter(message=>message.type==='error').length,page_errors:row.page_errors.length,fixture_faults:row.expected_storage_faults.length}));
 }
}

try{
 await scenario('normal',{mode:'normal'},async({page,load,snapshot,wait,gui,click,key,check,equal,shot,raw,openSettings,row})=>{
  let s=await load();
  equal(s.profile.data.starters,['lightning','moon'],'fresh profile only unlocks the initial two starters');
  check(await page.evaluate(()=>Object.isFrozen(window.echoWitchSnapshot)&&Object.getOwnPropertyDescriptor(window,'echoWitchSnapshot').writable===false),'public game snapshot is immutable');
  await shot('title');
  await click(344,403);await gui('starters');await shot('starter-locks');
  for(const [index,x,y] of [[2,1010,251],[3,262,437],[4,636,437],[5,1010,437]]){
   await click(x,y);await delay(200);s=await snapshot();
   equal({page:s.gui.page,starter:s.gui.starter,state:s.state},{page:'starters',starter:'lightning',state:'title'},'locked starter '+index+' cannot be selected or start combat');
  }
  await key('Escape');await gui('');
  await openSettings();
  await click(337,205);await wait(()=>window.echoWitchSnapshot.settings.sound===false);
  await click(917,205);await wait(()=>window.echoWitchSnapshot.settings.reduced_motion===true);
  await click(917,293);await wait(()=>window.echoWitchSnapshot.settings.large_text===true);
  await click(337,360);await key('Home');
  for(let n=0;n<5;n++)await key('ArrowRight');
  await wait(()=>window.echoWitchSnapshot.settings.music_volume===0.25);
  await click(337,488);await key('Home');
  for(let n=0;n<9;n++)await key('ArrowRight');
  await wait(()=>window.echoWitchSnapshot.settings.sfx_volume===0.45);
  s=await snapshot();
  const expected={sound:false,reduced_motion:true,large_text:true,music_volume:0.25,sfx_volume:0.45};
  equal(s.settings,expected,'all five settings change through real mouse and keyboard input');
  equal(JSON.parse(await raw()).settings,expected,'settings are serialized into browser-local storage');
  await shot('settings-large');
  await page.setViewportSize({width:960,height:540});await delay(350);await shot('settings-large-960');
  await page.reload();await page.waitForFunction(()=>window.echoWitchSnapshot?.state==='title');
  s=await snapshot();equal(s.settings,expected,'settings survive a complete page reload');
  equal(s.profile.status,'saved','reload visibly recognizes the saved profile');
  await shot('title-restored-960');
  await page.setViewportSize({width:1280,height:720});await delay(250);await openSettings();
  await click(917,621);await gui('storage');await shot('storage-saved');
  await key('Escape');await gui('settings');
  equal((await snapshot()).state,'title','Back from storage returns to settings without starting combat');
  row.settings_after_reload=s.settings;
 });

 async function corruptCase(name,rawFixture){
  await scenario(name,{mode:'corrupt',raw:rawFixture},async({load,snapshot,wait,gui,click,key,equal,check,shot,raw,openSettings,openWarning,page,row})=>{
   let s=await load();
   equal(s.profile.status,'invalid','malformed or unsupported record is visible as invalid');
   equal(s.profile.can_save,false,'automatic saving remains disabled for an unreadable record');
   equal(await raw(),rawFixture,'initial load preserves every character of the unreadable record');
   await shot('title-invalid');
   await openWarning();await shot('storage-invalid');
   await key('Escape');await gui('');await openSettings();
   await click(337,205);await wait(()=>window.echoWitchSnapshot.settings.sound===false);
   equal(await raw(),rawFixture,'changing settings cannot overwrite the unreadable record');
   equal((await snapshot()).profile.status,'invalid','storage warning remains after a setting change');
   await shot('settings-with-warning');
   await key('Escape');await gui('');await openWarning();
   await click(917,621);await wait(()=>window.echoWitchSnapshot.profile.status==='saved');
   s=await snapshot();
   const backups=await page.evaluate(key=>Object.keys(localStorage).filter(item=>item.startsWith(key+'-unreadable-')).map(item=>({key:item,raw:localStorage.getItem(item)})),storageKey);
   equal(backups.length,1,'explicit recovery makes exactly one archived copy');
   equal(backups[0].raw,rawFixture,'archived copy preserves the exact unreadable original');
   equal(JSON.parse(await raw()),s.profile.data,'recovery writes a valid fresh profile after archiving');
   equal(s.settings.sound,true,'recovery applies the fresh default settings');
   equal(s.gui.page,'storage','explicit recovery stays on the record page');
   await shot('storage-recovered');
   await page.reload();await page.waitForFunction(()=>window.echoWitchSnapshot?.state==='title');
   s=await snapshot();equal(s.profile.status,'saved','recovered record reloads without another invalid state');
   check(s.profile.can_save,'recovered profile can save');
   row.archived_raw=backups[0].raw;
   row.archive_key=backups[0].key;
   await shot('title-after-recovery');
  });
 }
 await corruptCase('corrupt-json','{"version":1,"settings":{"sound":');
 await corruptCase('corrupt-empty','');
 await corruptCase('unsupported-version',JSON.stringify({version:99,settings:{sound:true,reduced_motion:false,music_volume:0.65,sfx_volume:0.8,large_text:false},starters:['lightning','moon'],discoveries:{weapons:['lightning','moon'],relics:[],enemies:[],evolutions:[]},clears:[],best:{chapter:0,kills:0,seconds:0,victories:0},runs:0}));

 await scenario('blocked-read',{mode:'blocked_read',raw:'preserve existing inaccessible data'},async({load,snapshot,wait,gui,click,key,equal,check,shot,original,openWarning,openSettings,row})=>{
  let s=await load();equal(s.profile.status,'blocked','storage read denial is visible at initial title');equal(s.profile.can_save,false,'unavailable storage is not reported as saveable');
  equal(await original(),'preserve existing inaccessible data','denied read does not erase an existing stored value');
  await shot('title');await openWarning();await shot('storage');
  await click(917,621);await delay(300);equal((await snapshot()).profile.status,'blocked','retry reports that storage remains unavailable');
  await key('Escape');await gui('');await openSettings();await click(337,205);await wait(()=>window.echoWitchSnapshot.settings.sound===false);
  equal(await original(),'preserve existing inaccessible data','setting changes preserve inaccessible original data');await shot('settings');
  await key('Escape');await gui('');await key('Enter');await wait(()=>window.echoWitchSnapshot.state==='playing');await key('Escape');await wait(()=>window.echoWitchSnapshot.state==='paused');
  s=await snapshot();await delay(500);equal((await snapshot()).elapsed,s.elapsed,'play and explicit pause remain usable while storage is denied');
  check(s.profile.status==='blocked'&&s.settings.sound===false,'in-memory settings work without persistent storage');
  row.paused_elapsed=s.elapsed;await shot('pause-without-save');
 });

 await scenario('blocked-write',{mode:'blocked_write'},async({load,snapshot,wait,gui,click,key,equal,check,shot,raw,openSettings,row})=>{
  await load();await openSettings();await click(337,205);await wait(()=>window.echoWitchSnapshot.profile.status==='blocked');
  let s=await snapshot();equal(s.settings.sound,false,'write denial still applies the requested in-memory setting');equal(s.profile.can_save,false,'write failure is visible in save availability');equal(await raw(),null,'failed write does not create or alter a stored record');await shot('settings-error');
  await click(917,621);await gui('storage');await shot('storage-error');await click(917,621);await delay(300);
  s=await snapshot();equal(s.profile.status,'blocked','write retry keeps the failure visible');equal(await raw(),null,'write retry also leaves the stored value untouched');
  check(s.settings.sound===false,'failed retry preserves current settings');
  row.profile_after_write_failure=s.profile;
 });
 report.success=report.cases.every(row=>row.success);
}catch(error){report.failure=String(error.stack||error);console.error(error);}
finally{
 try{report.pck_sha256_after=await fingerprint();report.bundle_unchanged=report.pck_sha256_after===report.pck_sha256_before;if(!report.bundle_unchanged){report.success=false;report.failure='Game bundle changed while storage scenarios were running';}}catch{}
 report.finished=new Date().toISOString();
 await writeFile(path.join(out,'results.json'),JSON.stringify(report,null,2));
 await browser.close();
 console.log('Storage QA report: '+path.join(out,'results.json'));
 if(!report.success)process.exitCode=1;
}
