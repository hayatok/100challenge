const {chromium}=await import(process.env.PLAYWRIGHT_MODULE||'playwright');
import {mkdir,writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const out=process.env.QA_OUT||new URL('../docs/verification/browser/quality-resize/',import.meta.url).pathname;
const base=process.env.BASE_URL||'http://127.0.0.1:4197/';
await mkdir(out,{recursive:true});
const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',args:['--enable-unsafe-swiftshader']});
const errors=[], samples=[];
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function setup(viewport){
 const page=await browser.newPage({viewport});
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 await page.goto(base);
 await page.waitForFunction(()=>window.echoWitchSnapshot?.state==='title');
 return page;
}
async function capture(page,name){
 await page.screenshot({path:out+'/'+name+'.png'});
 samples.push({name,viewport:page.viewportSize(),snapshot:await page.evaluate(()=>window.echoWitchSnapshot)});
}
let result;
try{
 const page=await setup({width:1280,height:720});
 await page.keyboard.press('Enter');
 await page.keyboard.down('d');await sleep(1400);await page.keyboard.up('d');
 await page.keyboard.press('Escape');await page.waitForFunction(()=>window.echoWitchSnapshot?.state==='paused');
 await sleep(300);await capture(page,'paused-1280');
 const before=await page.evaluate(()=>window.echoWitchSnapshot);
 await page.setViewportSize({width:960,height:540});
 await capture(page,'resize-immediate');
 await sleep(350);await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));await capture(page,'resize-settled');
 await sleep(1000);await capture(page,'resize-after-second');
 assert.equal((await page.evaluate(()=>window.echoWitchSnapshot)).elapsed,before.elapsed);
 await page.keyboard.press('Enter');await sleep(900);await capture(page,'resize-resumed');
 await page.keyboard.press('Escape');await sleep(400);await capture(page,'resize-repaused');
 for(let i=1;i<=3;i++){
  await page.setViewportSize({width:1280,height:720});await sleep(300);
  await page.setViewportSize({width:960,height:540});
  await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));await sleep(350);await capture(page,'repeat-'+i+'-paused-960');
 }
 await page.close();
 const fresh=await setup({width:960,height:540});await sleep(500);await capture(fresh,'fresh-title-960');
 await fresh.keyboard.press('Enter');await sleep(800);await capture(fresh,'fresh-playing-960');
 await fresh.keyboard.press('Escape');await fresh.waitForFunction(()=>window.echoWitchSnapshot?.state==='paused');await sleep(700);await capture(fresh,'fresh-paused-960');
 await fresh.keyboard.press('Enter');await sleep(800);await capture(fresh,'fresh-resumed-960');
 assert.deepEqual(errors,[]);result={success:true,samples,errors};
}catch(error){result={success:false,error:String(error.stack||error),samples,errors};process.exitCode=1;}
finally{await writeFile(out+'/results.json',JSON.stringify(result,null,2));await browser.close();console.log(JSON.stringify({success:result.success,error:result.error,screenshots:samples.map(x=>x.name),errors}));}
