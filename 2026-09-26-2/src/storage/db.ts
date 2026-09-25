import { openDB } from 'idb'
import { parseProject, type Project } from '../domain/project'
const dbPromise=openDB('type-motion-studio',1,{upgrade(db){db.createObjectStore('projects',{keyPath:'id'})}})
type RecordValue={id:string;revision:number;updatedAt:number;project:Project}
export async function allProjects(){const db=await dbPromise;return (await db.getAll('projects') as RecordValue[]).map(r=>parseProject(r.project))}
export async function loadProject(id:string){const db=await dbPromise;const record=await db.get('projects',id) as RecordValue|undefined;return record?{project:parseProject(record.project),revision:record.revision}:null}
export async function saveProject(project:Project,expectedRevision:number){const db=await dbPromise;const tx=db.transaction('projects','readwrite'),old=await tx.store.get(project.id) as RecordValue|undefined;if(old&&old.revision!==expectedRevision)throw new Error('別のタブで編集が保存されました。JSONへ退避してください');const revision=expectedRevision+1;await tx.store.put({id:project.id,revision,updatedAt:Date.now(),project:parseProject(project)});await tx.done;return revision}
export async function deleteProject(id:string){const db=await dbPromise;await db.delete('projects',id)}
