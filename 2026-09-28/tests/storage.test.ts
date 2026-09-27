import test from 'node:test';
import assert from 'node:assert/strict';
import { readSave, writeSave, defaultPreferences } from '../src/storage.ts';
Object.defineProperty(globalThis,'matchMedia',{value:()=>({matches:false}),configurable:true});
let content:string|null=null;
Object.defineProperty(globalThis,'localStorage',{value:{getItem:()=>content,setItem:(_key:string,value:string)=>{content=value;}},configurable:true});
test('broken storage falls back without preventing a new game',()=>{content='{broken';assert.deepEqual(readSave().preferences,defaultPreferences());assert.deepEqual(readSave().results,[]);});
test('saved controls reject invalid difficulty and constrain volume',()=>{content=JSON.stringify({preferences:{difficulty:'impossible',music:9,effects:-2,motion:'false',practice:true}});const p=readSave().preferences;assert.equal(p.difficulty,'normal');assert.equal(p.music,1);assert.equal(p.effects,0);assert.equal(p.motion,true);assert.equal(p.practice,true);});
test('storage quota denial is reported as a recoverable failure',()=>{Object.defineProperty(globalThis,'localStorage',{value:{getItem:()=>null,setItem:()=>{throw new Error('quota');}},configurable:true});assert.equal(writeSave(defaultPreferences(),[]),false);});
