import type { Project } from './project'
export type History={past:Project[];present:Project;future:Project[];group:string|null}
export type Action={type:'edit';project:Project;group?:string}|{type:'replace';project:Project}|{type:'undo'}|{type:'redo'}|{type:'endGroup'}
export const initialHistory=(project:Project):History=>({past:[],present:project,future:[],group:null})
export function historyReducer(state:History,action:Action):History{
  if(action.type==='replace')return initialHistory(action.project)
  if(action.type==='endGroup')return {...state,group:null}
  if(action.type==='edit'){if(JSON.stringify(state.present)===JSON.stringify(action.project))return state;return{past:action.group&&state.group===action.group?state.past:[...state.past,state.present].slice(-50),present:action.project,future:[],group:action.group??null}}
  if(action.type==='undo'){const previous=state.past.at(-1);return previous?{past:state.past.slice(0,-1),present:previous,future:[state.present,...state.future],group:null}:state}
  const next=state.future[0];return next?{past:[...state.past,state.present].slice(-50),present:next,future:state.future.slice(1),group:null}:state
}
