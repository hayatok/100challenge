import { openDB } from 'idb'
import { parseRecipe, type SavedState } from '../domain/model'
let dbPromise:ReturnType<typeof openDB>|undefined
const database=()=>dbPromise??(dbPromise=openDB('moving-cover-2026-09-25',1,{upgrade(db){db.createObjectStore('state')}}))
export async function readState():Promise<SavedState|null>{const db=await database();const raw=await db.get('state','root') as SavedState|undefined;if(!raw)return null
  if(raw.version!==1||!Array.isArray(raw.boards)||!Array.isArray(raw.favorites)||raw.boards.length>50||raw.favorites.length>50||!raw.boards.some(b=>b.id===raw.activeBoardId))throw new Error('保存データを確認できません。JSONで退避するか、新しく始めてください。')
  raw.boards.forEach(b=>{if(!b.candidates.length||b.candidates.length>4||!b.candidates.some(r=>r.id===b.selectedId))throw new Error('履歴のデータが不正です。');b.candidates.forEach(parseRecipe)})
  raw.favorites.forEach(parseRecipe);return raw }
export async function writeState(snapshot:SavedState,expectedRevision:number){const db=await database(),tx=db.transaction('state','readwrite');const current=await tx.store.get('root') as SavedState|undefined
  if((current?.revision??0)!==expectedRevision){tx.abort();throw new Error('別のタブで更新されました。')}
  const next={...snapshot,revision:expectedRevision+1};await tx.store.put(next,'root');await tx.done;return next.revision }
export async function clearSavedState(){const db=await database();await db.delete('state','root')}
