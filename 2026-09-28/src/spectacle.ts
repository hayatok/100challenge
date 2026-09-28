import type { GameEvent } from './game.ts';
export type Celebration = { title:string; caption:string; badge:string; theme:'gold'|'pink'|'cyan'; priority:number; remaining:number };
/** Events are processed in their original order. A minor hit never hides a jackpot. */
export class CelebrationState {
  current:Celebration|null=null;
  rushHits=0;
  rushing=false;
  private tier=0;
  private offer(title:string,caption:string,badge:string,priority:number,theme:Celebration['theme']='gold',remaining=1.8){
    if(this.current && this.current.priority>priority)return;
    this.current={title,caption,badge,priority,theme,remaining};
  }
  event(e:GameEvent){
    if(e.type==='rushStart'){this.rushing=true;this.rushHits=0;this.offer('限界残業','短文4連戦 / 打ち抜いて解放','突入',70);}
    if(e.type==='kill'&&!e.collateral){
      const combo=e.combo??0, tier=e.effectsLevel??0;
      if(this.rushing){this.rushHits++;this.offer(['一体撃破','二連撃','三連撃','四連撃'][Math.min(3,this.rushHits-1)],`${this.rushHits} / 4 撃破`,'連撃',40);}
      else if(tier>this.tier || combo>=20&&combo%5===0){this.offer(tier===4?'限界突破':['','連撃好調','熱烈勤務','残業上等'][tier]||'限界突破',`${combo} 連撃 / 勤務熱量上昇`,combo>=20?'継続':'覚醒',60,tier===2?'pink':'gold');}
      this.tier=tier;
    }
    if(e.type==='rushEnd'){this.rushing=false;if(e.success)this.offer('全員退勤','4 / 4 撃破 / 4連戦、突破。','完走',80);else this.offer('残業終了','通常戦へ / もう一度ためよう','再開',80,'cyan',.85);}
    if(e.type==='luckyStart')this.offer('幸運出勤','踊る深夜のボーナスタイム','開演',70,'pink');
    if(e.type==='luckyEnd'&&e.success)this.offer('大当り',`BONUS +${e.scoreDelta??500} / ${e.healing?'体力 +1':'今夜の幸運、いただきました。'}`,'大当り',90,'gold',2.1);
    if(e.type==='explosion'&&(e.count??0)>0)this.offer((e.count??0)>=2?'三体一掃':'二体一掃',`${(e.count??0)+1}体 一掃 / BONUS +${(e.count??0)*75}`,'連爆',65);
    if(e.type==='clear')this.offer('勤務終了','本日の勤務、完全終了。','退勤',100,'gold',2.8);
  }
  update(dt:number){if(this.current){this.current.remaining-=Math.max(0,dt);if(this.current.remaining<=0)this.current=null;}}
  reset(){this.current=null;this.rushing=false;this.rushHits=0;this.tier=0;}
}
