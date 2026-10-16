import { ROUTINE_ACTIONS, routineEligible, personaAt } from './routines.js';
// Scene authorship and evidence eligibility live here; no historical person is
// copied into the fictional family tree. All coordinates and weather are art.
const datedMaterials = new Set(['L3-M004','L3-M005','L3-M006','L3-M007','L3-M008','L3-M012','L3-M017']);
function hash(value){let h=2166136261;for(const c of String(value)){h^=c.charCodeAt(0);h=Math.imul(h,16777619);}h^=h>>>16;h=Math.imul(h,0x85ebca6b);h^=h>>>13;h=Math.imul(h,0xc2b2ae35);return (h^(h>>>16))>>>0;}
const choose=(seed,key,values)=>values[hash(`${seed}|${key}`)%values.length];
const atMonth=(value,end=false)=>{if(value===null||value===undefined)return null;const m=String(value).match(/^(\d{4})(?:-(\d{2}))?/);return m&&(!m[2]||(Number(m[2])>=1&&Number(m[2])<=12))?Number(m[1])*12+(m[2]?Number(m[2]):end?12:1)-1:null;};
const profile=(id,activity,text,prop,pose,destinationKind,extra={})=>({id,activity,text,prop,pose,destinationKind,minAge:6,...extra});

export const LIFE_SCENE_RULES=Object.freeze([
  profile('shinano-water','井戸へ水を汲みに行く','桶を持って井戸へ。帰り道は、水をこぼさないようゆっくり歩く。','bucket','walk','water',{sourceMaterialId:'L3-M004',places:['koshin']}),
  profile('shinano-shopping','通い帳を持って店へ行く','通い帳を手に店先へ。今日の用事を済ませ、家族の待つ家へ戻る。','book','walk','shop',{sourceMaterialId:'L3-M004',places:['koshin'],minAge:16}),
  profile('shinano-school','野菜籠を持って学校へ行く','野菜を入れた籠を持ち、いつもの通学道を進む。','basket','walk','school',{sourceMaterialId:'L3-M004',places:['koshin'],from:'1946-01',minAge:6,maxAge:14}),
  profile('ishigaki-fish','浜で魚籠を受け取る','浜で魚籠を受け取り、顔なじみと声を交わす。仕事の続きは町の店先へ。','basket','talk','coast',{sourceMaterialId:'L3-M005',places:['okinawa'],minAge:16}),
  profile('tokyo-laundry','洗濯の手を動かす','たらいのそばで洗濯をする。干した布の具合を確かめて、もうひと仕事。','cloth','work','water',{sourceMaterialId:'L3-M006',places:['kanto'],minAge:16}),
  profile('tokyo-charcoal','燃料を家へ運ぶ','受け取った燃料を家へ運ぶ。置き場所を整えると、夕方の支度が始まる。','basket','walk','home',{sourceMaterialId:'L3-M006',places:['kanto'],minAge:16}),
  profile('kodaira-postcard','便りを出しに行く','短い便りを書いた葉書を持って外へ。用事のついでに商店ものぞこう。','letter','walk','post',{sourceMaterialId:'L3-M007',places:['kanto'],minAge:16}),
  profile('kodaira-greens','青物を買いに行く','冬から春の店先で青物を選ぶ。買ったものを籠に入れ、家へ向かう。','basket','walk','shop',{sourceMaterialId:'L3-M007',places:['kanto'],minAge:16}),
  profile('hiroshima-ledger','帳面に今日の用事を書く','家の帳面を広げて、今日の用事を書き留める。隣では家族が本を読んでいる。','book','work','home',{sourceMaterialId:'L3-M008',places:['sanyo'],minAge:16}),
  profile('hiroshima-book','家で本を読む','家族のそばで本を開く。分からなかったところを、あとで聞いてみよう。','book','rest','home',{sourceMaterialId:'L3-M008',places:['sanyo'],minAge:6,maxAge:14}),
  profile('kushi-cooperation','仲間と漁の道具を整える','浜で仲間と網や道具を整える。声を掛け合い、それぞれの持ち場を確かめる。','net','work','coast',{sourceMaterialId:'L3-M012',places:['shikoku','kyushu'],minAge:16}),
  profile('matsushige-weaving','織り上がりを確かめる','織り上がった布を広げ、目をそろえていく。手仕事の合間に、ひと息ついた。','cloth','work','home',{sourceMaterialId:'L3-M017',places:['shikoku'],windows:[['1911-02','1911-02'],['1916-04','1916-04']],minAge:16}),
]);

const authored=[...ROUTINE_ACTIONS,profile('walk-to-shop','買物の用事へ向かう','籠を手に、町の商店へ向かう。用事が済んだら家族の待つ家へ戻ろう。','basket','walk','shop',{minAge:16}),profile('walk-to-school','仲間と学校へ向かう','本を持ち、近所の仲間と学校へ向かう。','book','walk','school',{minAge:6,maxAge:17}),profile('walk-to-post','便りを届けに向かう','書いた便りを手に、町の郵便へ向かう。','letter','walk','post',{minAge:16})];
const children=[profile('child-play','家のそばで遊ぶ','家のそばで遊び、見つけたものを家族に見せる。',null,'rest','home',{minAge:0,maxAge:5}),profile('child-home','家族と過ごす','家族のそばで、ゆっくり一日を過ごす。','food','rest','home',{minAge:0,maxAge:5})];

export function createLifeIndex(materials){
  return new Map((materials??[]).filter(m=>datedMaterials.has(m.id)&&m.verification==='item_content_verified'&&atMonth(m.period_start)!==null&&atMonth(m.period_end,true)!==null).map(m=>[m.id,{material:m,start:atMonth(m.period_start),end:atMonth(m.period_end,true)}]));
}
export function seasonAt(year,month){
  const season=month>=3&&month<=5?'spring':month>=6&&month<=8?'summer':month>=9&&month<=11?'autumn':'winter';
  return {season,seasonLabel:{spring:'春',summer:'夏',autumn:'秋',winter:'冬'}[season],key:`${year+(month===12?1:0)}-${season}`};
}
function eligible(rule,person,year,month,index){
  const time=year*12+month-1,age=year-person.birthYear,season=seasonAt(year,month).season;
  if(age<rule.minAge||age>(rule.maxAge??Infinity)||(rule.places&&!rule.places.includes(person.placeId))||(rule.seasons&&!rule.seasons.includes(season)))return false;
  if(rule.from&&time<atMonth(rule.from))return false;
  if(rule.through&&time>atMonth(rule.through,true))return false;
  if(rule.windows&&!rule.windows.some(([from,through])=>time>=atMonth(from)&&time<=atMonth(through,true)))return false;
  if(rule.sourceMaterialId){const source=index.get(rule.sourceMaterialId);if(!source||time<source.start||time>source.end)return false;}
  return true;
}
export function lifeScene(index,person,seed,year,month,{sourceMaterialId=null}={}){
  const key=`${person.id}-${seasonAt(year,month).key}`,inspired=LIFE_SCENE_RULES.filter(rule=>(!sourceMaterialId||rule.sourceMaterialId===sourceMaterialId)&&eligible(rule,person,year,month,index));
  if(sourceMaterialId&&inspired.length===0)return null;
  const persona={...person,...personaAt(person,year,seed)};
  const base=(year-person.birthYear<6?children:authored).filter(rule=>eligible(rule,person,year,month,index)&&routineEligible(rule,persona,year,month));
  const sourceFirst=inspired.length&&(sourceMaterialId||hash(`${seed}|${key}-source`)%3!==0);
  const rule=choose(seed,key,sourceFirst?inspired:base),sourceMaterialIds=rule.sourceMaterialId?[rule.sourceMaterialId]:[];
  return {id:rule.id,activity:rule.activity,text:rule.text,prop:rule.prop,pose:rule.pose,destinationKind:rule.destinationKind,sourceMaterialIds,fictional:true,sourceNote:sourceMaterialIds.length?'地域の記録を手がかりにした架空の場面。記録の当人・家族・出来事を再現したものではありません。':'人物・場面・地域への置き分けは作者の創作です。'};
}
export function sceneDestination(scene,person,seed,placeIndex=0,targets=null){
  if(scene.destinationKind==='home')return person.home;
  if(targets?.[scene.destinationKind])return targets[scene.destinationKind];
  // Shop coordinates match the baseline shop-i geometry in model.js.
  if(scene.destinationKind==='shop')return {x:.12+hash(`${seed}|shop-${placeIndex}-x`)/4294967296*.76,y:.15+hash(`${seed}|shop-${placeIndex}-y`)/4294967296*.7};
  const anchors={water:{x:.24,y:.67},farm:{x:.7,y:.67},coast:{x:.94,y:.24},school:{x:.4,y:.26},post:{x:.32,y:.42},station:{x:.18,y:.75},path:{x:.6,y:.43},square:{x:.48,y:.48},river:{x:.96,y:.32},workshop:{x:.73,y:.36},office:{x:.36,y:.3},factory:{x:.79,y:.28},clinic:{x:.32,y:.42}};
  return anchors[scene.destinationKind]??person.destination;
}
export function placeAtmosphere(index,place,seed,year,month){
  const seasonal=seasonAt(year,month);
  const sourceMaterialIds=[...new Set(LIFE_SCENE_RULES.filter(rule=>rule.places.includes(place.id)&&rule.sourceMaterialId&&index.has(rule.sourceMaterialId)).filter(rule=>eligible(rule,{placeId:place.id,birthYear:year-30},year,month,index)).map(rule=>rule.sourceMaterialId))];
  const landscape={hokkaido:'field',tohoku:'field',hokuriku:'mountain',kanto:'town',koshin:'mountain',tokai:'field',kinki:'river',sanin:'coast',sanyo:'river',shikoku:'coast',kyushu:'coast',okinawa:'coast'}[place.id]??'town';
  const snow=seasonal.season==='winter'&&['hokkaido','tohoku','hokuriku','koshin'].includes(place.id);
  const weather=choose(seed,`${place.id}-${seasonal.key}-weather`,snow?['snow','cloudy','sunny']:['sunny','sunny','cloudy','rain']);
  return {season:seasonal.season,seasonLabel:seasonal.seasonLabel,landscape,weather,sourceMaterialIds,fictional:true,sourceNote:'季節・天気・風景は作者の演出です。史料の当日の天候や地域の実測ではありません。'};
}
