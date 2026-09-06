import {spawn} from 'node:child_process';
import path from 'node:path';

// Independent simulations read the same imported game, but write distinct
// reports. Keep every scenario and failure gate while avoiding a serial wait.
const root=path.resolve(import.meta.dirname,'..');
const checks=[['storycampaign'],['balance','--quick']];
const statuses=await Promise.all(checks.map(args=>new Promise(resolve=>{
  console.log(`Starting ${args.join(' ')}`);
  const child=spawn(process.execPath,['scripts/godot.mjs',...args],{cwd:root,stdio:'inherit'});
  child.once('error',error=>{console.error(error);resolve(1);});
  child.once('close',code=>{
    console.log(`Finished ${args.join(' ')}: ${code===0?'passed':'failed'}`);
    resolve(code??1);
  });
})));
if(statuses.some(code=>code!==0))process.exit(1);
