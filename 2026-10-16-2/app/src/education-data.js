import { presetTracks, observationsAt } from './charts.js';
import { cleanSeriesLabel, displayUnit, displayTimeLabel } from './ui-copy.js';
import { eventYear } from './history-data.js';
import { safeURL } from './storage.js';

export const LENSES = Object.freeze([
  {id:'population',label:'人口',kind:'people',question:'日本に暮らす人の数は、どう変わった？',intro:'増え続けた時期と、増え方が変わる時期。線の傾きから、大きな変化の節目を探そう。',graph:'population'},
  {id:'work',label:'仕事',kind:'people',question:'農業・林業で働く人の数は、どう変わった？',intro:'農業・林業の就業者数を、調査の時代ごとにたどる。地域の仕事や家族の記録とも読み合わせよう。',graph:'industry'},
  {id:'food',label:'食卓',kind:'rice',question:'米の供給量は、どれくらい変わった？',intro:'一人一年当たりの米の供給量を比べる。食卓の変化を、食べ物が届く側の数字から見てみよう。',graph:'rice'},
  {id:'prices',label:'物価',kind:'prices',question:'同じ「100」は、何をものさしにしている？',intro:'2025年を100とする物価指数。値段の水準と、上がり方の速さを分けて読む。',graph:'prices'},
  {id:'education',label:'学校',kind:'books',question:'小学生の数は、いつ増え、いつ減った？',intro:'1948〜2024年の小学校の記録。1948〜2016年と2017年以後の資料を分けて、学ぶ子どもの数の変化を読む。',graph:'education'},
  {id:'communication',label:'通信',kind:'computers',question:'パソコンを持つ世帯の割合は、どう変わった？',intro:'1996〜2016年の世帯保有率。パソコンが家庭に広がる様子を、調査の区切りを確かめながら読む。',graph:'communication'},
  {id:'housing',label:'住まい',kind:'homes',question:'家が増えれば、住まいの問題はなくなる？',intro:'住宅の数が増えた時代を読む。空き家や地域ごとの暮らしにも視線を広げよう。',graph:'housing'},
].map(Object.freeze));

const DEFAULT_MEASURES = Object.freeze({population:'population',work:'agriculture',food:'rice',prices:'cpi',education:'primary',communication:'computer',housing:'housing'});
const EXTRA_MEASURES = Object.freeze({
  work: [
    {id:'manufacturing',label:'製造業の就業者数',question:'製造業で働く人の数は、どう変わった？',intro:'工場などで働く人の数を比べる。国勢調査と労働力調査、産業分類の違いを区切って読む。',kind:'people'},
    {id:'unemployment',label:'完全失業率',question:'完全失業率は、いつ高まり、いつ下がった？',intro:'1968年1月〜2026年8月の月ごとの記録。労働力人口に占める完全失業者の割合を読み、働く人の状況を考えよう。',kind:'people'},
  ],
  education: [
    {id:'advancement',label:'大学・短期大学への進学率',question:'大学・短期大学への進学率は、どう変わった？',intro:'1954〜2016年の大学学部・短期大学本科への進学率。過年度の高校卒業者なども含む全国の割合を読む。',kind:'books'},
  ],
  communication: [
    {id:'smartphone',label:'スマートフォンの世帯保有率',question:'スマートフォンは、何年で広がった？',intro:'2010〜2016年の世帯保有率。100マスの変化から、道具が暮らしに入る速さを実感する。',kind:'phones'},
    {id:'mobile',label:'携帯電話の世帯保有率',question:'携帯電話を持つ世帯の割合は、どう変わった？',intro:'1996〜2000年、2005年、2006〜2016年の記録を分けて読む。後半はPHSを含む携帯電話で、スマートフォンを含む別分類とは区別する。',kind:'phones'},
  ],
});

export function lensMeasures(id) {
  const lens=LENSES.find(l=>l.id===id)||LENSES[0];
  const labels={work:'農業・林業の就業者数',education:'小学校の在学者数',communication:'パソコンの世帯保有率'};
  return [{id:DEFAULT_MEASURES[lens.id],label:labels[lens.id]||lens.label,question:lens.question,intro:lens.intro,kind:lens.kind},...(EXTRA_MEASURES[lens.id]||[])].map(measure=>({...measure}));
}

function segmentedTracks(archive,drivers,driverId,seriesIndex,labelFor) {
  const driver=drivers.drivers.find(d=>d.id===driverId);
  return (driver?.segments||[]).flatMap(segment=>{
    const entry=archive.series.find(e=>e.id===segment.seriesIds[seriesIndex]);
    if(!entry)return [];
    const from=Number(segment.from.slice(0,4))+(Number(segment.from.slice(5,7))-1)/12;
    const through=Number(segment.through.slice(0,4))+Number(segment.through.slice(5,7))/12-1e-5;
    return [{entry,label:labelFor(entry,segment),from,through,limitation:segment.limitation,boundaries:driver.boundaries}];
  });
}
function seriesTrack(archive,statId,match,{from=1900,through=2026.999,boundaries=[],label}={}) {
  const entry=archive.series.find(e=>e.statId===statId&&match.test(e.label));
  return entry?[{entry,label:label||cleanSeriesLabel(entry.label),from,through,boundaries}]:[];
}
function industryLabel(entry,segment) {
  const subject=/農業[，、]林業/.test(entry.label)?'農業・林業':/農業/.test(entry.label)?'農業':'製造業';
  const scope=entry.statId==='SD2-STAT001'?'国勢調査':entry.statId==='SD2-STAT002'?'旧産業分類':/15歳以上/.test(entry.label)?'15歳以上':segment.from.startsWith('2007')?'2007年改定の産業分類':'労働力調査';
  return `${subject}の就業者数（${scope}）`;
}

export function lensTracks(archive,drivers,id,measureId) {
  const lens=LENSES.find(l=>l.id===id)||LENSES[0];
  const measures=lensMeasures(lens.id),measure=measures.find(m=>m.id===measureId)||measures[0];
  if(lens.id==='work') {
    if(measure.id==='unemployment')return seriesTrack(archive,'SD-STAT006',/完全失業者.*15歳以上.*率/,{from:1968,through:2026+8/12-1e-5,label:'完全失業率（15歳以上・月次）'});
    return segmentedTracks(archive,drivers,'industry',measure.id==='manufacturing'?1:0,industryLabel);
  }
  if(lens.id==='education') {
    if(measure.id==='advancement')return seriesTrack(archive,'SD-STAT004',/大学（学部）・短期大学（本科）への進学率/,{from:1954,through:2016.999,label:'大学学部・短期大学本科への進学率（過年度高卒者等を含む）'});
    return segmentedTracks(archive,drivers,'education',0,(entry)=>entry.statId==='SD-STAT003'?'小学校の在学者数（1948〜2016年の統計）':'小学校児童数（2017年以後の統計）');
  }
  if(lens.id==='communication') {
    const boundaries=drivers.drivers.find(d=>d.id==='communication')?.boundaries||[];
    if(measure.id==='smartphone')return seriesTrack(archive,'E3-ST005',/^スマートフォン\s*\//,{from:2010,through:2016.999,boundaries,label:'スマートフォンの世帯保有率'});
    if(measure.id==='mobile')return [
      ...seriesTrack(archive,'E3-ST003',/\/ 携帯電話 \/ /,{from:1996,through:2000.999,boundaries,label:'携帯電話の世帯保有率（1996〜2000年）'}),
      ...seriesTrack(archive,'E3-ST004',/^携帯電話 \/ /,{from:2005,through:2005.999,boundaries,label:'携帯電話の世帯保有率（2005年の断面）'}),
      ...seriesTrack(archive,'E3-ST005',/^携帯電話\(PHSを含む\) \/ /,{from:2006,through:2016.999,boundaries,label:'携帯電話の世帯保有率（PHSを含む・2006〜2016年）'}),
    ];
    return segmentedTracks(archive,drivers,'communication',0,entry=>cleanSeriesLabel(entry.label)).filter(track=>/パソコン/.test(track.entry.label)).map(track=>({...track,label:'パソコンの世帯保有率'}));
  }
  return presetTracks(archive,drivers,lens.graph);
}

/** Pick actual records, never a filled or interpolated year. Units stay separate. */
export function comparisonRecords(tracks,unit=null) {
  const units=[...new Set(tracks.map(t=>t.entry.unit))];
  const chosen=unit??units[0];
  const result=[];
  for(let year=1900;year<=2026;year++)for(const {point,track} of observationsAt(tracks.filter(t=>t.entry.unit===chosen),year)){
    if(point.kind==='number'&&Number.isFinite(point.value))result.push({key:point.id,point,track,unit:chosen});
  }
  return result;
}
export function comparisonPayload(record) {
  return record?{value:record.point.value,year:displayTimeLabel(record.point)||record.point.year,label:record.track.label||cleanSeriesLabel(record.track.entry.label)}:{value:null,year:'',label:''};
}
export const figureUnit = record => displayUnit(record?.unit || '');
export function chapterAt(chapters,year) {return chapters.find(c=>Number(year)>=c.from&&Number(year)<=c.through)||chapters[0];}

export function validateEducation(lessons,media,archive) {
  if(!Array.isArray(lessons?.chapters)||lessons.chapters.length!==8||!Array.isArray(media?.items)||media.items.length<10)throw new Error('教材の資料を読み込めませんでした。');
  const events=new Map(archive.events.map(e=>[e.id,e])),living=new Set(archive.living.map(e=>e.id)),sources=new Set(archive.sources.map(s=>s.id));
  const chapterIds=new Set();
  let next=1900;
  for(const c of lessons.chapters){
    if(!c.id||chapterIds.has(c.id)||!Number.isInteger(c.from)||!Number.isInteger(c.through)||c.from!==next||c.through<c.from||!LENSES.some(l=>l.id===c.dataLens))throw new Error('章の年代を読み込めませんでした。');
    chapterIds.add(c.id);
    for(const section of [c,...(c.focus||[])]){
      for(const id of section.eventIds||[]){const event=events.get(id),year=eventYear(event);if(!event||year<c.from||year>c.through||year===null)throw new Error('出来事の資料を読み込めませんでした。');}
      for(const id of section.livingIds||[])if(!living.has(id))throw new Error('暮らしの資料を読み込めませんでした。');
    }
    for(const id of c.sourceIds||[])if(!sources.has(id))throw new Error('章の出典を読み込めませんでした。');
    for(const source of c.sources||[])if(!source.title||!safeURL(source.url))throw new Error('章の出典を読み込めませんでした。');
    next=c.through+1;
  }
  if(next!==2027)throw new Error('章の年代を読み込めませんでした。');
  const photos=new Set();
  for(const item of media.items){
    if(!item.id||photos.has(item.id)||!/^\.\/assets\/history\/[\w.-]+\.(?:jpg|png|webp)$/.test(item.src)||!safeURL(item.sourceUrl)||!safeURL(item.licenseUrl)||!item.license||!item.alt||!Number.isInteger(item.year)||!Array.isArray(item.chapters)||!item.chapters.length||!Array.isArray(item.hotspots)||!item.hotspots.length)throw new Error('写真の資料情報が足りません。');
    if(item.chapters.some(id=>!chapterIds.has(id))||!lessons.chapters.some(c=>item.chapters.includes(c.id)&&item.year>=c.from&&item.year<=c.through))throw new Error('写真と章の年代を読み込めませんでした。');
    for(const h of item.hotspots)if(!Number.isFinite(h.x)||!Number.isFinite(h.y)||h.x<0||h.x>100||h.y<0||h.y>100||!h.title||!h.text)throw new Error('写真の見どころを読み込めませんでした。');
    photos.add(item.id);
  }
  for(const c of lessons.chapters)if(!media.items.some(item=>item.chapters.includes(c.id)))throw new Error('章の写真を読み込めませんでした。');
  const comparisons=new Set();
  for(const c of media.comparisons||[]){if(!c.id||comparisons.has(c.id)||c.beforeId===c.afterId||!photos.has(c.beforeId)||!photos.has(c.afterId))throw new Error('比較する写真を読み込めませんでした。');comparisons.add(c.id);}
  return true;
}


// Confirmed duplicate descriptions of one event. Source records remain intact.
const EVENT_GROUPS = Object.freeze([
  ['H2-E024','L-E003'], ['H2-E016','L-E004'], ['H-E102','L-E027'],
]);
export function educationEvents(events) {
  const aliases=new Map(EVENT_GROUPS.flatMap(ids=>ids.map(id=>[id,ids[0]])));
  const groups=new Map();
  for(const event of events){const key=aliases.get(event.id)||event.id;if(!groups.has(key))groups.set(key,[]);groups.get(key).push(event);}
  return [...groups.entries()].map(([key,records])=>{
    if(records.length===1)return records[0];
    const primary=records.find(e=>e.id===key)||records[0];
    return {...primary,source_ids:[...new Set(records.flatMap(e=>e.source_ids||[]))],topic_ids:[...new Set(records.flatMap(e=>e.topic_ids||[]))],theme_ids:[...new Set(records.flatMap(e=>e.theme_ids||[]))],relatedRecords:records};
  });
}
