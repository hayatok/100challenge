// A small authored day, independent of the historical/monthly clock and statistics.
export const DAILY_CYCLE_SECONDS=96;
const hash=value=>{let h=2166136261;for(const c of String(value)){h^=c.charCodeAt(0);h=Math.imul(h,16777619);}h^=h>>>16;return h>>>0;};
const choose=(seed,key,values)=>values[hash(`${seed}|${key}`)%values.length];
const action=(id,activity,text,prop,pose,destinationKind,extra={})=>({id,activity,text,prop,pose,destinationKind,minAge:16,...extra});
const coast=['hokkaido','hokuriku','sanin','sanyo','shikoku','kyushu','okinawa'];
export const ROUTINE_ACTIONS=Object.freeze([
  action('farm-hoe','畑の畝を整える','鍬で土を起こす。次の作業がしやすいよう、畝の間を整えていく。','tools','work','farm',{professions:['farmer'],seasons:['spring','summer','autumn'],slot:'work'}),
  action('farm-seed','種をまく','畑に小さな筋をつけ、種をまいて土をかける。','basket','work','farm',{professions:['farmer'],seasons:['spring'],slot:'work'}),
  action('farm-harvest','収穫物を籠に集める','畑を回り、実ったものを籠へ集める。午後は店に少し届けよう。','basket','work','farm',{professions:['farmer'],seasons:['summer','autumn'],slot:'work'}),
  action('farm-sort','納屋で種と道具を整える','外の仕事を休み、納屋で種と道具の手入れをする。','tools','work','farm',{professions:['farmer'],seasons:['winter'],slot:'work'}),
  action('fish-net','浜で網を繕う','網の目を一つずつ確かめ、ほどけた所を繕っていく。','net','work','coast',{professions:['fisher'],places:coast,slot:'work'}),
  action('fish-sort','水揚げを仕分ける','浜に届いた魚を籠に仕分ける。店の人に今日の分を渡そう。','basket','work','coast',{professions:['fisher'],places:coast,slot:'work'}),
  action('shop-display','店先に品物を並べる','荷をほどき、店先に品物を並べる。通りの人に朝の挨拶をする。','basket','work','shop',{professions:['merchant','food'],slot:'work'}),
  action('shop-ledger','売り買いを帳面につける','店の帳面を開き、今日の売り買いを書きつける。','book','work','shop',{professions:['merchant'],through:'1989-12',slot:'work'}),
  action('shop-register','レジで品物を受け渡す','品物を確かめてレジに通す。お客さんの袋に、そっと収めた。','basket','work','shop',{professions:['merchant'],from:'1970-01',slot:'work'}),
  action('craft-plane','木材を削る','作業場で材を押さえ、道具で少しずつ削っていく。','tools','work','workshop',{professions:['craft','builder'],slot:'work'}),
  action('craft-assemble','部品を組み合わせる','台の上に部品を並べ、形を確かめながら組み合わせる。','tools','work','workshop',{professions:['craft','mechanic'],slot:'work'}),
  action('textile-spin','糸を巻き取る','作業台の糸を巻き取り、次に使う分をそろえる。','cloth','work','workshop',{professions:['textile'],through:'1959-12',slot:'work'}),
  action('textile-sew','布を縫い合わせる','布を裁って縫い合わせる。袖を広げ、寸法をもう一度見る。','sewing','work','workshop',{professions:['textile'],slot:'work'}),
  action('office-paper','仕事の書類をそろえる','机で書類をそろえ、隣の人へ渡す分をまとめる。','book','work','office',{professions:['clerk'],through:'1999-12',slot:'work'}),
  action('office-computer','画面で仕事の資料を作る','机の画面で資料を整える。一区切りついたら、仲間に見せよう。','tablet','work','office',{professions:['clerk'],from:'1985-01',slot:'work'}),
  action('teacher-board','教室で文字を教える','教室で文字を示し、子どもたちの手元を見て回る。','book','study','school',{professions:['teacher'],slot:'work'}),
  action('teacher-prepare','授業の道具を整える','次の授業に使う本と道具を、教室でそろえている。','book','work','school',{professions:['teacher'],slot:'work'}),
  action('courier-sort','便りを仕分ける','届け先ごとに便りを仕分ける。袋を持ち、町を回る支度をする。','letter','work','post',{professions:['courier'],slot:'work'}),
  action('courier-deliver','家々へ便りを届ける','戸口で声を掛け、待っていた便りを手渡す。','letter','talk','path',{professions:['courier'],slot:'work'}),
  action('builder-measure','建物の寸法を測る','道具を広げて寸法を測る。仲間と印の位置を確かめる。','tools','work','workshop',{professions:['builder'],slot:'work'}),
  action('food-prepare','店の食事を仕込む','台所で材料をそろえ、昼の食事の支度を進める。','food','work','shop',{professions:['food'],slot:'work'}),
  action('mechanic-bicycle','自転車を修理する','車輪を回し、ゆるんだ所を工具で締め直す。','bicycle','work','workshop',{professions:['mechanic'],from:'1920-01',slot:'work'}),
  action('mechanic-motor','機械を点検する','作業場で機械の音を確かめ、部品の具合を見る。','tools','work','factory',{professions:['mechanic'],from:'1955-01',slot:'work'}),
  action('health-bag','手当ての道具をそろえる','訪ねる家に持っていく手当ての道具を、鞄へ入れる。','briefcase','care','clinic',{professions:['health'],slot:'work'}),
  action('health-visit','近所の人を気遣う','近所の人の話を聞き、休む場所を一緒に整える。','cloth','care','clinic',{professions:['health'],slot:'work'}),
  action('factory-inspect','工場で品を確かめる','できあがった品を並べ、道具で形や具合を確かめる。','tools','work','factory',{professions:['factory'],slot:'work'}),
  action('factory-pack','工場の品を箱へ詰める','品をまとめて箱へ詰める。次の人が運べるよう、台にそろえる。','cart','work','factory',{professions:['factory'],slot:'work'}),
  action('child-blocks','家で積み木を並べる','家族のそばで積み木を並べる。できた形を見てもらう。',null,'play','home',{minAge:0,maxAge:5,slot:'work'}),
  action('child-walk','家族と道端の草を見る','家族と近くの道へ。小さな葉を見つけ、指さしている。',null,'care','path',{minAge:0,maxAge:5,slot:'hobby',relation:'parent'}),
  action('school-read','教室で本を読む','教室で本を開き、隣の友だちと同じところを読んでみる。','book','study','school',{minAge:6,maxAge:22,roles:['student'],slot:'work'}),
  action('school-write','教室で文字を書く','机で文字を書く。分からない所を、先生に尋ねてみよう。','book','study','school',{minAge:6,maxAge:22,roles:['student'],slot:'work'}),
  action('school-clean','みんなで教室を掃く','授業のあと、友だちと教室を掃く。机の下まで、ほうきを動かす。','broom','work','school',{minAge:6,maxAge:22,roles:['student'],slot:'work'}),
  action('play-ball','友だちと球で遊ぶ','空き地で球を追いかける。次は誰の番か、声を掛け合う。','ball','play','square',{minAge:6,maxAge:17,slot:'hobby',relation:'schoolmate'}),
  action('play-stream','小川をのぞく','友だちと小川をのぞき、流れる葉を追っている。',null,'play','river',{minAge:6,maxAge:17,seasons:['spring','summer','autumn'],slot:'hobby',relation:'schoolmate'}),
  action('elder-garden','庭の鉢を手入れする','家のそばで鉢を手入れする。通りかかった人に、咲いた花を見せる。','basket','work','home',{minAge:65,slot:'work'}),
  action('elder-teach','手仕事を家族に教える','家族に道具の使い方を見せる。できた所を、一緒に確かめる。','tools','care','home',{minAge:65,slot:'work',relation:'child'}),
  action('elder-bench','広場で顔なじみと休む','広場で顔なじみとひと休み。帰りに買うものの話をしている。',null,'talk','square',{minAge:65,slot:'hobby',relation:'neighbor'}),
  action('errand-water','桶に水を汲む','井戸で桶を満たす。水が落ち着くのを待って、家へ運ぼう。','bucket','work','water',{minAge:16,through:'1959-12',slot:'errand'}),
  action('errand-market','店で食材を選ぶ','今日の食材を店で選ぶ。持ってきた籠に入れてもらう。','basket','queue','shop',{slot:'errand'}),
  action('errand-post','便りを郵便へ出す','書いた便りを郵便へ。離れて暮らす家族のことを、少し思い出す。','letter','queue','post',{slot:'errand'}),
  action('errand-repair','道具を修理に預ける','使い続けた道具を作業場へ持っていく。直す場所を相談する。','tools','talk','workshop',{slot:'errand'}),
  action('errand-laundry','たらいで布を洗う','布を洗い、絞って籠へ。干す場所を確かめて、家へ戻る。','cloth','work','water',{slot:'errand',through:'1969-12'}),
  action('errand-parcel','荷物を受け取る','町の店で届いた荷を受け取る。包みの角を確かめ、抱えて運ぶ。','cart','queue','shop',{slot:'errand',from:'1950-01'}),
  action('errand-phone','電話で家族に連絡する','家族に連絡し、夕方に会う場所を確かめる。','phone','talk','square',{slot:'errand',from:'2000-01'}),
  action('hobby-read','木陰で本を読む','持ってきた本を木陰で開く。栞を挟んで、景色を眺める。','book','rest','square',{slot:'hobby',hobbies:['reading']}),
  action('hobby-sketch','景色を描く','川べりに座り、手帳へ景色を描いている。','book','rest','river',{slot:'hobby',hobbies:['drawing']}),
  action('hobby-fish','川で釣り糸を垂らす','川べりで釣り糸を垂らす。浮きの動きをじっと待つ。','net','rest','river',{slot:'hobby',hobbies:['fishing'],seasons:['spring','summer','autumn']}),
  action('hobby-garden','花と野菜を見て回る','小さな畑で葉の具合を見る。草を抜いて、隣の人と見せ合う。','basket','work','farm',{slot:'hobby',hobbies:['gardening']}),
  action('hobby-sew','縁側で繕い物をする','縁側に座り、着慣れた布を繕う。糸を通して、もうひと針。','sewing','work','home',{slot:'hobby',hobbies:['sewing']}),
  action('hobby-game','顔なじみと盤を囲む','広場で盤を囲む。次の手を考える相手を、ゆっくり待っている。','book','play','square',{slot:'hobby',hobbies:['games'],relation:'neighbor'}),
  action('hobby-photo','町の景色を写真に残す','道の途中で立ち止まり、気に入った景色にカメラを向ける。','camera','rest','path',{slot:'hobby',hobbies:['photography'],from:'1960-01'}),
  action('hobby-radio','家でラジオを聞く','家でラジオを聞きながら、手元の道具を片づける。','radio','rest','home',{slot:'hobby',from:'1930-01',through:'1999-12'}),
  action('hobby-screen','画面で趣味を調べる','休憩の時間に、気になった趣味のことを画面で調べる。','tablet','rest','home',{slot:'hobby',from:'2000-01'}),
  action('hobby-walk','近所を遠回りする','町をゆっくり回る。いつもと違う道で、知り合いを見つけた。',null,'rest','path',{slot:'hobby'}),
  action('season-snow','家の前の雪を寄せる','家の前の雪を道具で寄せる。通る人のために、小さな道をあける。','tools','work','home',{slot:'errand',seasons:['winter'],places:['hokkaido','tohoku','hokuriku','koshin']}),
  action('season-festival','行事の道具を運ぶ','町の行事で使う道具を、近所の人と広場へ運ぶ。','cart','work','square',{slot:'errand',seasons:['summer','autumn'],relation:'neighbor'}),
  action('season-rain','雨宿りでひと息つく','店先で雨宿り。傘のしずくを払い、顔なじみと空を見上げる。','umbrella','rest','shop',{slot:'hobby',seasons:['spring','summer'],relation:'neighbor'}),
]);
const jobs={farmer:['畑の仕事','農家'],fisher:['浜の仕事','漁の仕事'],merchant:['商店の仕事','商店の仕事'],craft:['木工の仕事','木工の仕事'],textile:['織物と仕立て','縫製の仕事'],clerk:['事務の仕事','事務の仕事'],teacher:['学校の先生','学校の先生'],courier:['便りを届ける仕事','配達の仕事'],builder:['大工の仕事','建築の仕事'],food:['食事を作る仕事','食事を作る仕事'],mechanic:['道具を直す仕事','機械を直す仕事'],health:['手当ての仕事','暮らしを支える仕事'],factory:['工場の仕事','工場の仕事']};
export const PERSONALITIES=Object.freeze(['世話好き','好奇心旺盛','こつこつ派','話好き','慎重','のんびり']);
export const HOBBIES=Object.freeze({reading:'読書',drawing:'絵を描く',fishing:'釣り',gardening:'園芸',sewing:'繕い物',games:'盤遊び',photography:'写真',walking:'散歩'});
export function personaAt(person,year,seed=1){
  const age=year-person.birthYear,profession=person.profession??choose(seed,`${person.id}-profession`,Object.keys(jobs));
  const role=age<6?'child':age<person.workYear-person.birthYear?'student':age>=65?'elder':'worker';
  const hobby=person.hobbyKey??choose(seed,`${person.id}-hobby`,Object.keys(HOBBIES).filter(h=>h!=='photography'||person.birthYear>=1925));
  return {profession,role,occupation:role==='child'?'幼い子':role==='student'?'学びに通う':role==='elder'?`${jobs[profession][Number(year>=1960)]}の経験者`:jobs[profession][Number(year>=1960)],personality:person.personality??choose(seed,`${person.id}-personality`,PERSONALITIES),hobbyKey:hobby,hobby:HOBBIES[hobby]};
}
export function routineEligible(rule,person,year,month){
  const age=year-person.birthYear,season=month>=3&&month<=5?'spring':month>=6&&month<=8?'summer':month>=9&&month<=11?'autumn':'winter';
  const time=year*12+month-1,stamp=s=>Number(s.slice(0,4))*12+Number(s.slice(5,7))-1;
  return age>=rule.minAge&&age<=(rule.maxAge??Infinity)&&(!rule.roles||rule.roles.includes(person.role))&&(!rule.professions||(person.role==='worker'&&rule.professions.includes(person.profession)))&&(!rule.hobbies||rule.hobbies.includes(person.hobbyKey))&&(!rule.places||rule.places.includes(person.placeId))&&(!rule.seasons||rule.seasons.includes(season))&&(!rule.from||time>=stamp(rule.from))&&(!rule.through||time<=stamp(rule.through));
}
const fallbackAnchors={water:{x:.24,y:.67},farm:{x:.7,y:.67},coast:{x:.94,y:.24},school:{x:.4,y:.26},post:{x:.32,y:.42},station:{x:.18,y:.75},path:{x:.6,y:.43},square:{x:.48,y:.48},river:{x:.96,y:.32},workshop:{x:.73,y:.36},office:{x:.36,y:.3},factory:{x:.79,y:.28},clinic:{x:.32,y:.42},shop:{x:.48,y:.38}};
const sceneOf=rule=>({...rule,sourceMaterialIds:rule.sourceMaterialIds??(rule.sourceMaterialId?[rule.sourceMaterialId]:[]),fictional:true,sourceNote:rule.sourceNote??'人物・場面・町への置き分けは作者の創作です。'});
// Each visible resident has a real, local appointment. Grouping is authored,
// never inferred from national population or employment observations.
// These meeting places describe authored doorstep, garden, shopfront and public
// space around the town. They do not add measured facilities or change counts.
const MEETING_VENUES=Object.freeze([
  ['west-door','home-front','西の家々の前',-120,-105],['north-garden','garden','家々の庭先',0,-105],
  ['north-door','home-front','北の家々の前',120,-105],['west-shop','shop-front','西の店先',-200,-35],
  ['small-square','square','小さな広場',-80,-35],['workshop-front','shop-front','工房の軒先',40,-35],
  ['east-garden','garden','東の庭先',160,-35],['west-garden','garden','西の庭先',-160,35],
  ['south-door','home-front','南の家々の前',-40,35],['east-shop','shop-front','東の店先',80,35],
  ['quiet-square','square','通りの休み場',200,35],['south-garden','garden','南の庭先',-120,105],
  ['garden-path','garden','畑わきの庭先',0,105],['south-square','square','南の小広場',120,105],
].map(([id,kind,label,localX,localY])=>Object.freeze({id,kind,label,anchor:Object.freeze({x:.5+(localY/174+localX/320)/2,y:.5+(localY/174-localX/320)/2})})));
const projectedDistance=(a,b)=>Math.hypot(((a.x-a.y)-(b.x-b.y))*320,((a.x+a.y)-(b.x+b.y))*174);
export function createMeetings(people,year,seed){
  const result=Object.fromEntries(people.map(p=>[p.id,[]]));
  const partition=members=>{
    const groups=[];for(let i=0;i<members.length;i+=3)groups.push(members.slice(i,i+3));
    if(groups.length>1&&groups.at(-1).length===1)groups.at(-1).unshift(groups.at(-2).pop());
    return groups;
  };
  for(let day=0;day<3;day++){
    const groups=[],reserved=new Set();
    // Small children meet a family caregiver at every appointment, including
    // the family day. Remaining relatives form pairs/triads instead of crowds.
    for(const familyId of [...new Set(people.filter(p=>year-p.birthYear<6).map(p=>p.familyId))].sort()){
      const children=people.filter(p=>p.familyId===familyId&&year-p.birthYear<6),parents=people.filter(p=>p.familyId===familyId&&year-p.birthYear>=16);
      const caregiver=parents.find(p=>children.some(c=>c.parentIds.includes(p.id)))??parents[0];
      const group=[...children,...(caregiver?[caregiver]:[])];groups.push(group);for(const p of group)reserved.add(p.id);
    }
    const available=people.filter(p=>!reserved.has(p.id));
    if(day===0){for(const familyId of [...new Set(available.map(p=>p.familyId))].sort())groups.push(...partition(available.filter(p=>p.familyId===familyId).sort((a,b)=>a.birthYear-b.birthYear||a.order-b.order)));}
    else groups.push(...partition(available.sort((a,b)=>day===1?a.birthYear-b.birthYear||a.order-b.order:hash(`${seed}|${a.id}-meet`)-hash(`${seed}|${b.id}-meet`))));
    // Do not schedule a conversation alone if one person remains in a family.
    for(let i=groups.length-1;i>=0;i--)if(groups[i].length===1&&groups.length>1){const person=groups[i][0],target=groups.find((g,j)=>j!==i&&g.length<3&&g.some(q=>q.familyId===person.familyId))??groups.find((g,j)=>j!==i&&g.length<3)??groups.find((g,j)=>j!==i);target.push(person);groups.splice(i,1);}
    const usedVenues=[];
    groups.forEach((group,index)=>{
      const preferred=group.some(p=>year-p.birthYear<6)?['garden','home-front']:day===0?['home-front','garden']:group.every(p=>personaAt(p,year,seed).role==='student')?['square','garden']:['shop-front','square'];
      const venues=MEETING_VENUES.filter(v=>!usedVenues.includes(v)).map(venue=>({venue,distance:usedVenues.length?Math.min(...usedVenues.map(v=>projectedDistance(v.anchor,venue.anchor))):Infinity,preference:preferred.includes(venue.kind)?1:0,tie:hash(`${seed}|${people[0]?.placeId}-${day}-${venue.id}`)}));
      // All candidate pairs are at least 80 local pixels apart; farthest-first
      // spreads the first groups too, rather than filling one street first.
      venues.sort((a,b)=>b.distance-a.distance||b.preference-a.preference||a.tie-b.tie);
      const venue=venues[0]?.venue??MEETING_VENUES[index%MEETING_VENUES.length];usedVenues.push(venue);
      const meetingId=`${people[0]?.placeId}-${year}-day${day}-group${index}`,anchor=venue.anchor;
      for(const p of group){
        const others=group.filter(q=>q.id!==p.id).sort((a,b)=>Number(p.parentIds.includes(b.id)||p.childrenIds.includes(b.id))-Number(p.parentIds.includes(a.id)||p.childrenIds.includes(a.id))||a.order-b.order).slice(0,2);
        const companions=others.map(q=>({id:q.id,name:q.name,placeId:q.placeId,age:year-q.birthYear,...personaAt(q,year,seed),kind:p.parentIds.includes(q.id)?'parent':p.childrenIds.includes(q.id)?'child':p.siblingIds.includes(q.id)||p.familyId===q.familyId?'family':Math.abs(p.birthYear-q.birthYear)<=3&&personaAt(p,year,seed).role==='student'&&personaAt(q,year,seed).role==='student'?'schoolmate':'neighbor'}));
        result[p.id][day]={meetingId,anchor,venue:{id:venue.id,kind:venue.kind,label:venue.label},companions,memberIds:group.map(p=>p.id).sort(),fictional:true};
      }
    });
  }
  return result;
}
export function createRoutine(person,featured,seed,year,month,targets={},relationships=[],meetings=null){
  const eligible=ROUTINE_ACTIONS.filter(a=>routineEligible(a,person,year,month));
  let meetingAnchor=null;
  const anchor=kind=>kind==='home'?person.home:kind==='meeting'&&meetingAnchor?meetingAnchor:targets?.[kind]??fallbackAnchors[kind]??person.home;
  const relationIds=kind=>relationships.filter(r=>r.kind===kind).map(r=>r.id);
  const key=`${person.id}-${year}-${month}`;
  const days=Array.from({length:3},(_,day)=>{
    const stages=[];let at=person.home;meetingAnchor=null;
    const add=(rule,duration,phase,relation=null)=>{const scene=sceneOf(rule),to=anchor(scene.destinationKind),companionIds=relationIds(relation??rule.relation);duration+=person.personality==='こつこつ派'&&phase==='work'?3:person.personality==='話好き'&&phase==='social'?4:person.personality==='好奇心旺盛'&&phase==='hobby'?4:person.personality==='のんびり'&&['midday','night'].includes(phase)?3:person.personality==='世話好き'&&phase==='evening'?3:0;stages.push({id:`${day}-${stages.length}-${rule.id}`,phase,duration,from:{...to},to:{...to},scene,companionIds,fictional:true});at=to;};
    const travel=(kind,label,phase,relation=null)=>{const to=anchor(kind);if(Math.hypot(at.x-to.x,at.y-to.y)<.005)return;const transport=person.role==='child'?'walk':year>=1970&&person.role==='worker'&&['clerk','factory'].includes(person.profession)?'bicycle':'walk';stages.push({id:`${day}-${stages.length}-travel`,phase,duration:person.personality==='慎重'?7:5,from:{...at},to:{...to},scene:sceneOf({id:`travel-${phase}`,activity:label,text:`${label}。次の用事へ、町の道を進んでいる。`,prop:transport==='bicycle'?'bicycle':null,pose:'walk',destinationKind:kind}),companionIds:relationIds(relation),transport,fictional:true});at=to;};
    const select=(slot,n=0)=>{let pool=eligible.filter(a=>a.slot===slot);if(slot==='work'&&person.role==='student')pool=pool.filter(a=>a.roles?.includes('student'));if(slot==='work'&&person.role==='elder')pool=pool.filter(a=>a.minAge>=65);if(slot==='work'&&person.role==='child')pool=pool.filter(a=>a.maxAge===5);if(slot==='hobby'&&person.role==='child')pool=pool.filter(a=>a.maxAge===5);if(slot==='hobby'&&person.role==='student')pool=pool.filter(a=>a.minAge<16);return choose(seed,`${key}-${day}-${slot}-${n}`,pool.length?pool:eligible.filter(a=>a.id==='hobby-walk'))??ROUTINE_ACTIONS.find(a=>a.id==='child-blocks');};
    add({id:'breakfast',activity:'家族と朝の支度をする',text:'食卓の支度を手伝う。今日の用事を家族と確かめてから出かけよう。',prop:'food',pose:'eat',destinationKind:'home'},5,'morning','family');
    const work=select('work'),second=select('work',1);
    travel(work.destinationKind,person.role==='student'?'通学仲間と学校へ向かう':person.role==='child'?'家族のそばへ':person.role==='elder'?'朝の用事へ向かう':'仕事場へ向かう','outbound',person.role==='student'?'schoolmate':'family');
    add(work,9,'work',work.relation);add({id:'midday',activity:person.role==='student'?'友だちと昼の休憩':'昼の休憩をとる',text:'手を休めて昼のひと息。午後にすることを思い浮かべる。',prop:'food',pose:'eat',destinationKind:work.destinationKind},5,'midday',person.role==='student'?'schoolmate':'neighbor');
    travel(second.destinationKind,'午後の持ち場へ向かう','afternoon');add(second,8,'work');
    const errand=day===0&&featured?.sourceMaterialIds?.length?featured:person.role==='child'?ROUTINE_ACTIONS.find(a=>a.id==='child-walk'):person.role==='student'?{id:'school-return',activity:'帰り道で友だちと話す',text:'今日の授業の話をしながら、帰り道を進む。',prop:'book',pose:'talk',destinationKind:'path',relation:'schoolmate'}:day===0&&featured?featured:select('errand');
    travel(errand.destinationKind,person.role==='child'?'家族と近所へ出る':'仕事や学びのあと、用事へ向かう','errand',person.role==='child'?'parent':null);add(errand.pose==='walk'?{...errand,pose:errand.prop==='letter'?'talk':'work',activity:({water:'井戸で水を汲む',shop:'店で用事を済ませる',school:'学校で用事を済ませる',post:'便りを郵便へ出す',home:'持ち帰った物を片づける'})[errand.destinationKind]??errand.activity}:errand,8,'errand');
    const hobby=select('hobby');travel(hobby.destinationKind,'自分の楽しみへ少し寄り道','hobby',hobby.relation);add(hobby,9,'hobby');
    const meeting=meetings?.[day]??null;meetingAnchor=meeting?.anchor??fallbackAnchors.square;
    const venueLabel=meeting?.venue.label??'広場';
    const social={id:'neighbor-chat',conversationEnergy:person.personality==='話好き'?1.4:1,activity:person.role==='child'?`${venueLabel}で家族に見つけたものを見せる`:`${venueLabel}で顔なじみと話す`,text:person.role==='child'?`${venueLabel}で拾った葉を家族に見せる。帰る前に、もう一度道をのぞく。`:`${venueLabel}で顔なじみと会い、今日の小さな用事の話をする。`,prop:null,pose:'talk',destinationKind:'meeting',venueKind:meeting?.venue.kind??'square',venueLabel};
    travel(social.destinationKind,'顔なじみのいる場所へ向かう','social',person.role==='child'?'parent':'neighbor');add(social,6,'social',person.role==='child'?'parent':'neighbor');
    if(meeting){const stage=stages.at(-1);stage.meetingId=meeting.meetingId;stage.meetingVenue=meeting.venue;stage.companions=meeting.companions;stage.companionIds=meeting.companions.map(c=>c.id);stage.memberIds=meeting.memberIds;stage.facingId=meeting.companions[0]?.id??null;}
    travel('home','用事を済ませ、家へ帰る','return','family');add({id:'evening',activity:'家で夕方の支度をする',text:'持ち帰ったものを置き、家族と夕方の支度をする。今日も町でいくつかの用事が済んだ。',prop:'food',pose:'care',destinationKind:'home'},8,'evening','family');
    add({id:'night',activity:'家で一日を振り返る',text:'道具を片づけて、ひと休み。家族と話し、明日の用事に備える。',prop:person.hobbyKey==='reading'?'book':null,pose:'rest',destinationKind:'home'},5,'night','family');
    const socialIndex=stages.findIndex(stage=>stage.phase==='social'&&stage.scene.pose==='talk');
    const schedule=(items,start,end)=>{const total=items.reduce((sum,s)=>sum+s.duration,0);let cursor=start;for(const stage of items){stage.startsAt=cursor;cursor+=stage.duration/total*(end-start);stage.endsAt=cursor;}if(items.length)items.at(-1).endsAt=end;};
    schedule(stages.slice(0,socialIndex),0,72);schedule([stages[socialIndex]],72,80);schedule(stages.slice(socialIndex+1),80,DAILY_CYCLE_SECONDS);
    for(const stage of stages){stage.startHour=6+stage.startsAt/DAILY_CYCLE_SECONDS*16;stage.endHour=6+stage.endsAt/DAILY_CYCLE_SECONDS*16;}
    return stages;
  });
  return {days,stages:days[0],cycleSeconds:DAILY_CYCLE_SECONDS,sourceMaterialIds:featured?.sourceMaterialIds??[],fictional:true,note:'6時から22時までの架空の一日です。史実の日付・当日の行動・実際の勤務時間を再現していません。'};
}
export function dayClockAt(clockSeconds=0){
  const seconds=Math.max(0,Number.isFinite(clockSeconds)?clockSeconds:0),dayIndex=Math.floor(seconds/DAILY_CYCLE_SECONDS),phase=(seconds%DAILY_CYCLE_SECONDS)/DAILY_CYCLE_SECONDS,dailyHour=6+phase*16,minutes=Math.floor(dailyHour*60);
  return {dailyHour,timeLabel:`${String(Math.floor(minutes/60)).padStart(2,'0')}:${String(minutes%60).padStart(2,'0')}`,dayIndex,phase,fictional:true};
}
export function routineAt(person,clockSeconds=0){
  if(!person?.routine||!person.alive)return person;
  const clock=dayClockAt(clockSeconds),stages=person.routine.days[clock.dayIndex%person.routine.days.length],phaseSeconds=clock.phase*DAILY_CYCLE_SECONDS;
  const stageIndex=Math.max(0,stages.findIndex(stage=>phaseSeconds<stage.endsAt)),stage=stages[stageIndex],progress=Math.max(0,Math.min(1,(phaseSeconds-stage.startsAt)/(stage.endsAt-stage.startsAt)));
  const routeProgress=stage.scene.pose==='walk'?progress:1;
  return {...person,...clock,x:stage.from.x+(stage.to.x-stage.from.x)*routeProgress,y:stage.from.y+(stage.to.y-stage.from.y)*routeProgress,from:stage.from,to:stage.to,progress,scene:stage.scene,activity:stage.scene.activity,stageIndex,stage,sceneStages:stages,nextStage:stages[(stageIndex+1)%stages.length],companionIds:stage.companionIds,companions:stage.companions??[],meetingId:stage.meetingId??null,meetingVenue:stage.meetingVenue??null,memberIds:stage.memberIds??[],facingId:stage.facingId??null};
}
