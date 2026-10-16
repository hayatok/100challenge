// The archive is evidence; this small world is author-created fiction.
export const PLACES = Object.freeze([
  ['hokkaido','北海道','白樺町',.81,.13,142.1,43.2],['tohoku','東北','こもれび町',.72,.35,140.5,39.3],
  ['hokuriku','北陸','雪あかり町',.55,.48,137.1,36.8],['kanto','関東','川風町',.70,.57,139.5,35.8],
  ['koshin','甲信','山ぶどう町',.60,.56,138.2,36.0],['tokai','東海','茶の葉町',.58,.65,137.0,35.1],
  ['kinki','近畿','水の輪町',.45,.66,135.4,34.8],['sanin','山陰','浜なす町',.33,.61,133.1,35.2],
  ['sanyo','山陽','ひだまり町',.32,.72,133.1,34.5],['shikoku','四国','青葉町',.34,.81,133.5,33.8],
  ['kyushu','九州','みかん町',.17,.83,130.7,32.5],['okinawa','沖縄','珊瑚町',.12,.95,127.7,26.3],
].map(([id,region,name,x,y,lng,lat]) => Object.freeze({id,region,name,x,y,lng,lat,fictional:true})));

export const MODEL_RULES = Object.freeze({
  population: '全国人口÷600000を四捨五入し120〜230人の模型。参照なしは作者の180人。地域人口ではない。',
  housing: '総住宅数÷450000を四捨五入し48〜160軒。空き家数も÷450000。参照なしは作者の84軒。',
  industry: '同一系列・同一区分の最初の数値を12個の模型とし、その値との比で田畑・工場を4〜36個描く。分類境界で基点を取り直す。',
  water: '上水道給水人口÷10000000を四捨五入し設備の模型を0〜16個。普及率は作らない。',
  education: '小学校は同じ系列の初観測との比×48人影・×6校、大学は同じ系列との比×2キャンパス。単位未確定のため人数換算をせず比のみ。',
  rice: '供給純食料kg÷5を四捨五入し0〜30俵の模型。購入量や摂取量ではない。分類境界を表示する。',
  prices: '2025年基準の総合・食料指数をそのまま商店の札へ。円や個人の購入量へ変換しない。',
  bus: '参照月の乗合輸送人員（原単位「千」）÷100000を四捨五入し0〜8台の模型。実車両数ではない。',
  lives: '出生間隔は25年、寿命は種から決める68〜92年の作者設定。出生死亡統計や出来事を個人の運命へ変換しない。',
});
const MIN_YEAR=1900, MAX_YEAR=2026;
const clamp=(n,min,max)=>Math.max(min,Math.min(max,n));
function hash(text) { let h=2166136261;for(const c of String(text)){h^=c.charCodeAt(0);h=Math.imul(h,16777619);}h^=h>>>16;h=Math.imul(h,0x85ebca6b);h^=h>>>13;h=Math.imul(h,0xc2b2ae35);return (h^(h>>>16))>>>0; }
const random=(seed,key)=>hash(`${seed}|${key}`)/4294967296;
const pick=(seed,key,array)=>array[Math.floor(random(seed,key)*array.length)];
const monthIndex=(year,month=1)=>year*12+month-1;
function dateIndex(value,end=false) {
  if(value===null||value===undefined||value==='')return null;
  const match=String(value).match(/^(\d{4})(?:-(\d{2}))?/);
  return match?monthIndex(Number(match[1]),match[2]?Number(match[2]):end?12:1):null;
}
function observationMonth(point) { const m=String(point.timeLabel??point.time_label??'').match(/年(\d{1,2})月/);return m?Number(m[1]):null; }
function numericPoint(point) {return point.kind==='number'&&Number.isFinite(point.value)&&typeof point.raw==='string'&&point.raw.trim()!==''&&Number(point.raw.replace(/,/g,''))===point.value;}
function latestBefore(points,time) {
  let lo=0,hi=points.length;
  while(lo<hi){const mid=(lo+hi)>>>1;if(points[mid].time<=time)lo=mid+1;else hi=mid;}
  return lo?points[lo-1]:null;
}
function makeIndex(archive,drivers) {
  if(archive?.version!==1||drivers?.version!==1||!Array.isArray(archive.series)||!Array.isArray(drivers.drivers)||drivers.drivers.length!==8)throw new Error('史料を読み込めませんでした。');
  const sources=new Map(archive.sources.map(s=>[s.id,s]));
  const series=new Map(archive.series.map(s=>[s.id,{series:s,points:s.points.map(point=>({point,time:monthIndex(point.year,observationMonth(point)??1)})).sort((a,b)=>a.time-b.time)}]));
  for(const driver of drivers.drivers)for(const id of driver.seriesIds)if(!series.has(id))throw new Error(`参照系列がありません: ${id}`);
  const events=archive.events.map(event=>({event,start:dateIndex(event.date_start),end:dateIndex(event.date_end,true)})).filter(e=>e.start!==null).sort((a,b)=>a.start-b.start);
  const living=archive.living.map(item=>({item,start:dateIndex(item.period_start),end:dateIndex(item.period_end,true)}));
  return {archive,drivers:drivers.drivers,series,sources,events,living};
}
function segmentStart(driver,year) { return Math.max(-Infinity,...(driver.boundaries??[]).filter(b=>b.year<=year).map(b=>b.year)); }
function observe(index,driver,id,year,month) {
  const entry=index.series.get(id), found=latestBefore(entry.points,monthIndex(year,month)), start=segmentStart(driver,year);
  const point=found?.point??null;
  const blocked=point&&(point.year<start||!numericPoint(point));
  const status=!point||blocked?'unavailable':point.year===year&&(observationMonth(point)===null||observationMonth(point)===month)?'exact':'historical';
  const baseline=entry.points.find(p=>p.point.year>=start&&numericPoint(p.point)&&p.point.value>0)?.point??null;
  return {status,value:status==='unavailable'?null:point.value,unit:point?.unit??entry.series.unit,point,series:entry.series,source:index.sources.get(entry.series.sourceId)??null,segment:Number.isFinite(start)?start:null,baseline,reason:!point?'この時点までの観測を採用していません。':blocked?'欠測記号、または比較区分の境界を越えるため背景に使いません。':status==='historical'?`${point.timeLabel}の過去の断面を参考にした模型です。`:null};
}
function macroAt(index,year,month) {
  return Object.fromEntries(index.drivers.map(driver=>{
    let ids=driver.seriesIds;
    if(driver.id==='industry')ids=year<1953?ids.slice(0,2):year<2003?[ids[2],ids[3]]:[ids[2],ids[4]];
    const observations=ids.map(id=>observe(index,driver,id,year,month));
    const first=observations[0];
    return [driver.id,{id:driver.id,label:driver.label,...first,observations,notes:driver.notes,boundaries:driver.boundaries,authorRule:MODEL_RULES[driver.id]}];
  }));
}
const count=(value,divisor,min=0,max=Infinity)=>value===null?0:clamp(Math.round(value/divisor),min,max);
const ratioCount=(observation,base,min,max)=>observation?.value===null||!observation?.baseline?0:clamp(Math.round(base*observation.value/observation.baseline.value),min,max);
function directivesAt(macro) {
  const observation=(id,n=0)=>macro[id].observations[n];
  const p=observation('population'),h=observation('housing'),v=observation('housing',1),school=observation('education'),college=observation('education',1);
  return {
    personCount:p.value===null?180:count(p.value,600000,120,230),
    houseCount:h.value===null?84:count(h.value,450000,48,160),
    emptyHouseCount:count(v.value,450000,0,40),
    farmCount:ratioCount(observation('industry'),12,4,36),factoryCount:ratioCount(observation('industry',1),12,4,36),
    waterCount:count(observation('water').value,10000000,0,16),
    schoolCount:ratioCount(school,6,1,12),studentCount:ratioCount(school,48,0,96),campusCount:ratioCount(college,2,0,12),
    riceSacks:count(observation('rice').value,5,0,30),
    priceIndex:observation('prices').value,foodPriceIndex:observation('prices',1).value,
    busCount:count(observation('bus').value,100000,0,8),
    populationBasis:p.value===null?'author':'observation',housingBasis:h.value===null?'author':'observation',
    rules:MODEL_RULES,references:Object.fromEntries(Object.entries(macro).map(([id,signal])=>[id,signal.observations.map(o=>({pointId:o.point?.id??null,seriesId:o.series.id,sourceId:o.source?.id??null,status:o.status,year:o.point?.year??null,timeLabel:o.point?.timeLabel??null,segment:o.segment}))])),
  };
}
const surnames=['森','川上','小野','田中','木村','井上','高橋','坂本','中村','林','山口','石川'];
const names=['はる','あき','さち','一郎','健','明','よし','みどり','ふみ','誠','ゆき','直'];
function makePeople(seed) {
  const people=[];
  for(const place of PLACES)for(let family=0;family<5;family++){
    const familyId=`${place.id}-f${family}`,surname=pick(seed,`${familyId}-name`,surnames),offset=Math.floor(random(seed,`${familyId}-offset`)*25);
    for(let generation=0;generation<10;generation++)for(let sibling=0;sibling<2;sibling++){
      const id=`${familyId}-g${generation}-${sibling}`,birthYear=1810+offset+generation*25+sibling*3,deathYear=birthYear+68+Math.floor(random(seed,`${id}-life`)*25);
      people.push({id,name:surname+pick(seed,`${id}-given`,names),familyId,placeId:place.id,birthYear,deathYear,generation,
        parentIds:generation?[`${familyId}-g${generation-1}-0`]:[],
        childrenIds:sibling===0&&generation<9?[`${familyId}-g${generation+1}-0`,`${familyId}-g${generation+1}-1`]:[],
        siblingIds:[`${familyId}-g${generation}-${1-sibling}`],
        occupation:pick(seed,`${id}-job`,['商店の仕事','畑の仕事','ものづくり','仕立ての仕事']),
        home:{x:.15+random(seed,`${familyId}-hx`)*.7,y:.2+random(seed,`${familyId}-hy`)*.6},
        destination:{x:.15+random(seed,`${id}-dx`)*.7,y:.2+random(seed,`${id}-dy`)*.6},
        order:hash(`${seed}-${id}-order`)});
    }
  }
  const byId=new Map(people.map(p=>[p.id,p]));
  for(const person of people){person.childBirths=person.childrenIds.map(id=>({id,year:byId.get(id).birthYear}));person.schoolYear=person.birthYear+5+Math.floor(random(seed,`${person.id}-school`)*3);person.workYear=person.birthYear+16+Math.floor(random(seed,`${person.id}-work`)*7);}
  return {people,byId};
}
const dailyActivities=[
  ['買物に出かける','米屋や商店をのぞいて、家へ帰った。'],
  ['親戚への便りを書く','親戚に便りを書き、近ごろの暮らしを伝えた。'],
  ['畑の手伝いをする','畑仕事を手伝い、土のついた道具を洗った。'],
  ['家を手入れする','家の小さな傷みを直して、道具を片づけた。'],
  ['近所を散歩する','道ばたの花を見ながら、いつもの道を歩いた。'],
  ['祭りの支度をする','近所の人と、町の祭りの支度を進めた。'],
  ['商店で話をする','商店先で顔なじみと、しばらく話した。'],
  ['家族と過ごす','家族と食卓を囲み、今日のことを話した。'],
];
function dailyAt(person,seed,year,month) {
  const age=year-person.birthYear;
  const options=age<6?[['家のそばで遊ぶ','家のそばで遊び、見つけたものを家族に見せた。'],['家族と過ごす','家族とゆっくり一日を過ごした。']]:dailyActivities;
  const [activity,text]=pick(seed,`${person.id}-${year}-${month}-daily`,options);
  return {id:`${person.id}-${year}-${month}`,year,month,activity,text,kind:'daily',fictional:true};
}
function personAt(person,time,seed,journal=false) {
  if(!person)return null;
  const year=Math.floor(time/12),age=year-person.birthYear,alive=age>=0&&year<person.deathYear;
  const progress=((time%12)+random(seed,`${person.id}-walk`)*12)%12/12;
  const outbound=progress<.5,portion=outbound?progress*2:(1-progress)*2;
  const month=Math.floor(time%12)+1,dailyEvent=alive?dailyAt(person,seed,year,month):null;
  const routine=random(seed,`${person.id}-${year}-${month}-routine`);
  const activity=!alive?(age<0?'まだ生まれていない':'人生の記録'):age>=6&&age<15&&routine<.4?'学校へ歩く':age>=16&&age<68&&routine<.45?person.occupation+'へ歩く':dailyEvent.activity;
  const atHome=['親戚への便りを書く','家を手入れする','家族と過ごす'].includes(activity);
  const destination=atHome?person.home:person.destination;
  const lifeEvents=[{year:person.birthYear,text:'この架空の家族に生まれる',kind:'birth'},{year:person.schoolYear,text:pick(seed,`${person.id}-school-note`,['近所の子と、学びの日々が始まる','新しい道具を持って、学びに通い始める','家族に見送られ、学びの日々が始まる']),kind:'school'},{year:person.workYear,text:person.occupation+pick(seed,`${person.id}-work-note`,['を覚え始める','で新しい仲間と出会う','を少しずつ任される']),kind:'work'},...person.childBirths.map(child=>({year:child.year,text:'家族に次の世代が加わる',kind:'family',personId:child.id})),{year:person.deathYear,text:'この人の人生の記録が終わる',kind:'death'}].filter(e=>e.year<=year).map(e=>({...e,month:1,fictional:true}));
  if(journal)for(let y=person.birthYear+6;y<=Math.min(year,person.deathYear-1);y++)for(let season=0;season<3;season++){
    const m=1+season*4+Math.floor(random(seed,`${person.id}-${y}-${season}-journal`)*4);
    if(y===year&&m>month)continue;
    lifeEvents.push(dailyAt(person,seed,y,m));
  }
  lifeEvents.sort((a,b)=>a.year-b.year||a.month-b.month);
  return {...person,age:Math.max(0,Math.min(age,person.deathYear-person.birthYear)),alive,activity,
    x:person.home.x+(destination.x-person.home.x)*portion,y:person.home.y+(destination.y-person.home.y)*portion,
    from:outbound?person.home:destination,to:outbound?destination:person.home,progress:portion,lifeEvents,dailyEvent,fictional:true,authorRule:MODEL_RULES.lives};
}
function buildWorld(sim,macro) {
  const directives=directivesAt(macro),{seed,time}=sim;
  const candidates=sim._people.people.filter(p=>p.birthYear<=Math.floor(time/12)&&p.deathYear>Math.floor(time/12)).sort((a,b)=>a.order-b.order);
  const people=candidates.slice(0,directives.personCount).map(p=>personAt(p,time,seed));
  const selected=sim._people.byId.get(sim.personId);
  if(selected&&selected.birthYear<=Math.floor(time/12)&&selected.deathYear>Math.floor(time/12)&&!people.some(p=>p.id===selected.id))people[people.length-1]=personAt(selected,time,seed);
  const places=PLACES.map(place=>({...place,visual:{houses:0,farm:0,factory:0,vacancy:0,school:0,students:0,water:0,rice:0,bus:0,shops:0,priceIndex:directives.priceIndex,foodPriceIndex:directives.foodPriceIndex}}));
  const buildings=[],vehicles=[];
  const scatter=(total,type,visual)=>{
    for(let i=0;i<total;i++){
      const place=places[i%places.length],id=`${type}-${i}`,lit=type!=='house'||i>=Math.min(directives.emptyHouseCount,directives.houseCount);
      place.visual[visual]++;if(type==='house'&&!lit)place.visual.vacancy++;
      buildings.push({id,placeId:place.id,type,x:.12+random(seed,`${id}-x`)*.76,y:.15+random(seed,`${id}-y`)*.7,lit,fictional:true});
    }
  };
  scatter(directives.houseCount,'house','houses');scatter(directives.farmCount,'farm','farm');scatter(directives.factoryCount,'factory','factory');scatter(directives.waterCount,'water','water');scatter(directives.schoolCount+directives.campusCount,'school','school');scatter(directives.riceSacks,'rice','rice');
  scatter(12,'shop','shops'); // A baseline fictional shop in each town, never a measured shop count.
  for(let i=0;i<directives.studentCount;i++)places[i%12].visual.students++;
  for(let i=0;i<directives.busCount;i++){
    const place=places[i%12],phase=(time/3+i*.23)%1;place.visual.bus++;
    vehicles.push({id:`bus-${i}`,placeId:place.id,type:'bus',x:.15+.7*phase,y:.75,from:{x:.15,y:.75},to:{x:.85,y:.75}});
  }
  return {places,people,buildings,vehicles,directives,scopeNote:'町ごとの模型の置き分けは作者設定です。実際の地域人口・路線・個人の暮らしを推計していません。'};
}
function atTime(sim,time) {return {...sim,time:clamp(time,monthIndex(MIN_YEAR),monthIndex(MAX_YEAR,10))};}
export function createSimulation(archive,drivers,{seed=1,year=1900,month=1,placeId='kanto'}={}) {
  if(!Number.isFinite(Number(seed)))throw new Error('暮らしの種は数値で指定してください。');
  const sim={version:1,seed:Number(seed)>>>0,time:monthIndex(1900),placeId:PLACES.some(p=>p.id===placeId)?placeId:'kanto',personId:null,_index:makeIndex(archive,drivers),_people:makePeople(Number(seed)>>>0)};
  return seek(sim,year,month);
}
export function seek(sim,year,month=1) {
  if(!Number.isInteger(year)||!Number.isInteger(month)||month<1||month>12)throw new Error('年と月を確かめてください。');
  return atTime(sim,monthIndex(year,month));
}
export function advance(sim,months=1) {if(!Number.isFinite(months))throw new Error('進める月数を確かめてください。');return atTime(sim,sim.time+months);}
export function reroll(sim,newSeed=sim.seed+1) {
  if(!Number.isFinite(Number(newSeed)))throw new Error('暮らしの種は数値で指定してください。');
  const seed=Number(newSeed)>>>0;return {...sim,seed,_people:makePeople(seed),personId:null};
}
export function selectPerson(sim,id) {return sim._people.byId.has(id)?{...sim,personId:id,placeId:sim._people.byId.get(id).placeId}:sim;}
export function selectPlace(sim,id) {return PLACES.some(p=>p.id===id)?{...sim,placeId:id,personId:null}:sim;}
export function serializeSimulation(sim) {return JSON.stringify({version:1,seed:sim.seed,time:sim.time,placeId:sim.placeId,personId:sim.personId});}
export function restoreSimulation(archive,drivers,raw) {
  let data;try{data=typeof raw==='string'?JSON.parse(raw):raw;}catch{throw new Error('保存された暮らしを読み込めません。');}
  if(!data||typeof data!=='object'||Object.keys(data).length!==5||!['version','seed','time','placeId','personId'].every(k=>Object.hasOwn(data,k))||data.version!==1||!Number.isInteger(data.seed)||data.seed<0||data.seed>4294967295||!Number.isFinite(data.time)||data.time<monthIndex(MIN_YEAR)||data.time>monthIndex(MAX_YEAR,10)||!PLACES.some(p=>p.id===data.placeId)||(data.personId!==null&&typeof data.personId!=='string'))throw new Error('保存された暮らしを読み込めません。');
  const sim={...createSimulation(archive,drivers,{seed:data.seed,placeId:data.placeId}),time:data.time,personId:data.personId};
  if(data.personId!==null&&!sim._people.byId.has(data.personId))throw new Error('保存された人物が見つかりません。');
  return sim;
}
export function snapshot(sim) {
  const year=Math.floor(sim.time/12),month=Math.floor(sim.time%12)+1,macro=macroAt(sim._index,year,month),world=buildWorld(sim,macro);
  const events=sim._index.events.filter(e=>e.start<=Math.floor(sim.time));
  const activeEvents=events.filter(e=>e.end!==null&&e.end>=Math.floor(sim.time)).map(e=>e.event);
  const living=sim._index.living.filter(e=>e.start!==null&&e.end!==null&&e.start<=sim.time&&e.end>=Math.floor(sim.time)).map(e=>e.item);
  const selectedPerson=personAt(sim._people.byId.get(sim.personId),sim.time,sim.seed,true);
  if(selectedPerson){const ids=[...selectedPerson.parentIds,...selectedPerson.siblingIds,...selectedPerson.childrenIds];selectedPerson.family=ids.map(id=>personAt(sim._people.byId.get(id),sim.time,sim.seed)).filter(p=>p&&p.birthYear<=year);selectedPerson.childrenIds=selectedPerson.childrenIds.filter(id=>sim._people.byId.get(id).birthYear<=year);}
  return {year,month,seed:sim.seed,ended:sim.time>=monthIndex(MAX_YEAR,10),macro,events:events.slice(-6).reverse().map(e=>e.event),activeEvents,living,world,selectedPerson,selectedPlace:world.places.find(p=>p.id===sim.placeId),scopeNote:sim._index.archive.scopeNote};
}
