import { routineAt, dayClockAt } from './routines.js';
import { eraProfile, buildingArt, dailyLight } from './era-art.js';
// Original Canvas2D paper diorama. Geography is supplied as a GeoJSON Feature.
// All counts and identities belong to the model; motion here only animates them.
const C = { ink:'#42584b', sea:'#d8e9e7', land:'#c8d9aa', side:'#96b18e', roof:'#b85744', roofLight:'#d47b5b', cream:'#f2e7c9', wood:'#c9ad7e', green:'#759b67', darkGreen:'#4b795b', water:'#8bbcc0', road:'#eadfc4', rail:'#73877c', blue:'#638b9c', gold:'#d2aa5b' };
const clamp = (n,a,b) => Math.max(a,Math.min(b,n));
const number = (n, fallback=0) => Number.isFinite(Number(n)) ? Number(n) : fallback;
const hash = (value) => { let n=2166136261; for (const c of String(value)) n=Math.imul(n^c.charCodeAt(0),16777619); n^=n>>>16;n=Math.imul(n,0x85ebca6b);n^=n>>>13;n=Math.imul(n,0xc2b2ae35);return ((n^(n>>>16))>>>0)/4294967296; };
const count = (n, max=100) => Math.round(clamp(number(n),0,max));
const mix = (a,b,p) => a+(b-a)*p;

/** No timer: the owner passes a simulation clock and calls render in its rAF. */
export function createRenderer(canvas, {geometry, onPlaceSelect=()=>{}, onPersonSelect=()=>{}, onViewChange=()=>{}}={}) {
  const ctx=canvas.getContext('2d');
  if (!ctx) throw new Error('この環境では箱庭を描画できません。');
  let width=1000,height=680,dpr=1,hits=[],destroyed=false;
  const geo=geometry?.geometry || geometry;
  const polygons=geo?.type==='MultiPolygon' ? geo.coordinates : geo?.type==='Polygon' ? [geo.coordinates] : [];
  let mapPath=null, project=()=>[0,0];
  let ambience={season:'summer',landscape:'field',weather:'sunny'};
  let era=eraProfile(1900),light=dailyLight(10),lastTime=0,motionClock=0;
  const regionalLandscape={hokkaido:'field',tohoku:'mountain',hokuriku:'river',kanto:'river',koshin:'mountain',tokai:'field',kinki:'town',sanin:'coast',sanyo:'coast',shikoku:'mountain',kyushu:'field',okinawa:'coast'};
  function environment(place,snapshot){const month=number(snapshot.month,6);return {season:month<3||month===12?'winter':month<6?'spring':month<9?'summer':'autumn',landscape:regionalLandscape[place.id]||'field',weather:'sunny',placeId:place.id,...place.atmosphere};}
  function greens(){return ambience.season==='autumn'?['#a9b37c','#a88050','#c39b56']:ambience.season==='winter'?['#a5b49c','#658879','#b7c6aa']:ambience.season==='spring'?['#a7c58c','#6e9b73','#c8d6a1']:[C.green,C.darkGreen,'#8bb078'];}
  function hasSignal(snapshot,key){return number(snapshot.world?.directives?.[key])>0;}
  function allocation(snapshot,place,key,max=5){const localKey={railCount:'rail',deviceCount:'device',energyGlyphs:'energy'}[key]||key;const own=place.visual?.[localKey];if(own!==undefined&&own!==null)return count(own,max);const total=count(snapshot.world?.directives?.[key],100);const index=(snapshot.world?.places||[]).findIndex(p=>p.id===place.id);return count(Math.floor(total/12)+(index>=0&&index<total%12?1:0),max);}
  function poly(points,fill,stroke=C.ink,lineWidth=.8) {
    ctx.beginPath(); points.forEach(([x,y],i)=>i?ctx.lineTo(x,y):ctx.moveTo(x,y));ctx.closePath();
    if(fill){ctx.fillStyle=fill;ctx.fill();}if(stroke){ctx.strokeStyle=stroke;ctx.lineWidth=lineWidth;ctx.stroke();}
  }
  function line(points,color=C.ink,lineWidth=1) {
    ctx.beginPath();points.forEach(([x,y],i)=>i?ctx.lineTo(x,y):ctx.moveTo(x,y));ctx.strokeStyle=color;ctx.lineWidth=lineWidth;ctx.stroke();
  }
  function ellipse(x,y,rx,ry,fill,stroke=null,lineWidth=.8) {
    ctx.beginPath();ctx.ellipse(x,y,Math.max(.01,rx),Math.max(.01,ry),0,0,Math.PI*2);ctx.fillStyle=fill;ctx.fill();
    if(stroke){ctx.strokeStyle=stroke;ctx.lineWidth=lineWidth;ctx.stroke();}
  }
  function rect(x,y,w,h,fill,stroke=null,lineWidth=.8) {
    ctx.fillStyle=fill;ctx.fillRect(x,y,w,h);if(stroke){ctx.strokeStyle=stroke;ctx.lineWidth=lineWidth;ctx.strokeRect(x,y,w,h);}
  }
  function text(value,x,y,size=12,color=C.ink,align='center') {
    ctx.font=`${size}px system-ui, sans-serif`;ctx.textAlign=align;ctx.textBaseline='middle';ctx.fillStyle=color;ctx.fillText(String(value),x,y);
  }
  function tree(x,y,s=1,t=0,variant=0) {
    t=motionClock;
    ctx.save();ctx.translate(x,y);ctx.scale(s,s);const sway=Math.sin(t+variant)*1.2;const [leaf,dark,light]=greens();
    ellipse(1,1,10,3,'#8da87d55');line([[0,1],[sway,-23]],'#7f7854',2.3);
    if(ambience.placeId==='okinawa'){line([[0,0],[sway+3,-32]],'#a2946b',2.6);for(let j=0;j<5;j++){const a=j*Math.PI/2.5;line([[sway+3,-32],[sway+3+Math.cos(a)*16,-31+Math.sin(a)*8]],j%2?dark:leaf,3);}}
    else if(variant%3===0){poly([[sway,-38],[-12+sway,-12],[13+sway,-12]],dark,null);poly([[sway,-31],[-14+sway,-6],[15+sway,-6]],leaf,null);}
    else {ellipse(sway,-23,13,12,leaf);ellipse(-6+sway,-19,9,9,light);ellipse(7+sway,-25,9,10,dark);ellipse(-2+sway,-30,8,8,light);if(ambience.season==='spring'&&variant%4===1){for(let j=0;j<6;j++)ellipse(-8+j*3,-25+(j%2)*5,2.8,2.3,'#e9c2b0');}if(ambience.weather==='snow')ellipse(-2+sway,-31,9,3,'#eef0dc');}
    if(ambience.placeId==='hokkaido'){line([[0,0],[sway,-21]],'#e5e4c8',2);for(let j=0;j<4;j++)line([[-1,-4-j*4],[1,-5-j*4]],'#7a8770',.7);}
    ctx.restore();
  }
  function shadow(w=15){ellipse(2,2,w,5,'#5b73502b');}
  function house(kind='house',seed=0,lit=true,year=1900) {
    const profile=eraProfile(year),art=buildingArt(year,seed,kind,ambience.placeId),shop=kind==='shop';
    const wide=shop?26:art.floors>1?21:21,h=20+(art.floors-1)*15, roof=art.roof;
    const timber=['wood','woodshop'].includes(art.form), window=lit?(light.night||light.dusk?'#ffd58b':'#9ab4ac'):'#61796f';
    shadow(wide+8);
    // Fences and tiny gardens make the building meet its lane instead of floating.
    poly([[-wide-7,0],[0,-wide*.48-4],[wide+8,0],[0,wide*.48+5]],'#c6c6a0',null);
    line([[-wide-8,1],[-6,12]],'#aaa27f',1.4);
    poly([[-wide,-h],[0,-h+wide*.48],[0,6],[-wide,6-wide*.48]],timber?'#a98f6c':profile.side);
    poly([[0,-h+wide*.48],[wide,-h],[wide,6-wide*.48],[0,6]],lit?profile.wall:'#aab6a1');
    if(['tower','danchi','glass','retail'].includes(art.form)){
      poly([[-wide-2,-h],[0,-h-wide*.48],[wide+2,-h],[0,-h+wide*.48]],roof);
      poly([[0,-h+wide*.48],[wide+2,-h],[wide+2,-h+4],[0,-h+wide*.48+4]],profile.roofLight);
      for(let f=0;f<art.floors;f++)for(let j=0;j<3;j++){
        const xx=4+j*5,yy=-h+wide*.48+5+f*14-j*2.4;
        poly([[xx,yy],[xx+3.5,yy-1.7],[xx+3.5,yy+5.5],[xx,yy+7.2]],window,null);
        poly([[-wide+4+j*5,-h+6+f*14+j*2.4],[-wide+7.5+j*5,-h+7.7+f*14+j*2.4],[-wide+7.5+j*5,-h+13.2+f*14+j*2.4],[-wide+4+j*5,-h+11.5+f*14+j*2.4]],window,null);
      }
      if(art.form==='glass')for(let j=0;j<5;j++)line([[-wide+2+j*4,-h+2+j*1.9],[-wide+2+j*4,-6+j*1.9]],'#d9e8de',.7);
      if(art.balcony)for(let f=1;f<art.floors;f++)line([[0,-h+11+f*14],[wide,-h+1+f*14]],'#e5e4cc',2);
      if(year>=1978){rect(-13,-h-13,15,10,'#c4cdc1',C.ink,.7);line([[-10,-h-9],[-1,-h-9]],'#809a93',1);}
      if(art.solar){poly([[-17,-h-3],[-4,-h-9],[7,-h-4],[-6,-h+2]],'#395d70');for(let j=0;j<3;j++)line([[-14+j*4,-h-4-j*1.8],[-4+j*4,-h+j*-1.8]],'#8fb4bf',.6);}
      if(profile.id==='green'){ellipse(9,-h-3,8,4,'#6f9e71');ellipse(12,-h-7,6,3,'#a6bd8b');}
    } else {
      const straw=year<1920&&seed<.35&&ambience.placeId!=='okinawa';
      poly([[-wide-4,-h-2],[-wide*.45,-h-19],[wide+4,-h-5],[wide*.24,-h+wide*.48]],straw?'#a08e64':roof);
      poly([[-wide*.45,-h-19],[1,-h-16],[wide+4,-h-5]],straw?'#c1ad7e':profile.roofLight);
      for(let j=0;j<6;j++)line([[-wide+1+j*6,-h-5+j*1.5],[-wide*.38+j*5,-h-16+j*2.1]],straw?'#887954':'#405a5b',.65);
      line([[-wide*.45,-h-19],[1,-h-16]],'#e4d6ae',1.3);
      for(let j=0;j<3;j++)poly([[-wide+4+j*5,-h+6+j*2.4],[-wide+8+j*5,-h+8+j*2.4],[-wide+8+j*5,-h+15+j*2.4],[-wide+4+j*5,-h+13+j*2.4]],window,null);
      poly([[4,-h+wide*.48+5],[wide-4,-h+7],[wide-4,-h+15],[4,-h+wide*.48+13]],window,null);
      if(timber){for(let j=0;j<5;j++)line([[-wide+2,-h+5+j*4],[-2,-h+wide*.48+4+j*4]],'#79674d',.55);for(let j=0;j<4;j++)line([[6+j*3,-h+11-j*1.4],[6+j*3,-h+18-j*1.4]],'#74694f',.7);}
      if(art.form==='brick'||art.form==='brickshop')for(let j=0;j<5;j++)line([[-wide+2,-h+3+j*4],[-2,-h+wide*.48+2+j*4]],'#a57e61',.8);
      if(art.form==='suburban'){poly([[-15,-h+2],[-2,-h+8],[-2,-h+13],[-15,-h+7]],'#e5d8bd');rect(-16,-h-10,8,7,'#8caaa4',C.ink,.5);line([[-18,-h-12],[-5,-h-6]],C.ink,.8);}
    }
    poly([[1,-6],[6,-8],[6,3],[1,6]],'#6e6952');
    if(shop){
      poly([[0,-15],[wide+2,-27],[wide+8,-19],[6,-7]],year>=1978?profile.trim:'#9a775c');
      for(let j=0;j<4;j++)line([[3+j*6,-15-j*2.9],[8+j*6,-7-j*2.9]],'#eddfb5',2);
      const title=profile.sign;rect(-wide+2,-h-9,wide*2-4,12,year>=1978?'#f5e7c4':'#e5d5aa',profile.trim,.8);text(title,0,-h-3,shop&&title.length>5?7:9,profile.trim);
      poly([[7,4],[29,-7],[32,-2],[10,9]],C.wood);for(let j=0;j<5;j++)ellipse(11+j*4,3-j*1.8,2.4,2,j%2?'#b86848':'#d2b565');
      if(year>=1978){rect(-wide-9,-30,7,26,profile.trim,C.ink,.6);text('商',-wide-5.5,-22,6,'#fff0c8');text('店',-wide-5.5,-13,6,'#fff0c8');}
      if(year<1998){rect(wide+3,-10,5,8,year<1920?'#6f7a63':'#b95f4b',C.ink,.5);line([[wide+4,-8],[wide+7,-8]],'#e8d9b1',.7);line([[wide+5.5,-2],[wide+5.5,4]],C.ink,.7);}
      if(year>=1998){rect(wide+1,-16,8,14,'#eeeece',C.ink,.6);rect(wide+2,-14,6,5,'#7eb2b1');for(let j=0;j<3;j++)rect(wide+2+j*2,-7,1,2,C.roof);}
    }
    if(ambience.weather==='snow')line([[-wide*.4,-h-17],[wide+2,-h-5]],'#f1efdc',3);
    if(year<1960&&seed>.5){line([[-wide-5,0],[-wide-5,-10]],C.wood,1.6);line([[-wide-8,-8],[-wide-2,-8]],C.wood,1.3);}
    if(year>=1965&&kind==='house'){rect(-wide-5,-18,6,5,'#e1dfc6',C.ink,.5);ellipse(-wide-2,-15.5,1.7,1.7,'#9fafa5');}
    if(!lit){line([[7,-16],[15,-8]],'#798e79',1);line([[15,-19],[7,-6]],'#798e79',1);ellipse(-14,2,5,2,'#95a177');}
  }
  function factory(seed,t) {
    t=motionClock;
    shadow(28);
    if(era.from>=1955){poly([[-36,-21],[0,-39],[36,-21],[0,-3]],'#92aaa2');poly([[-36,-21],[0,-3],[0,14],[-36,-4]],'#c5c7ab');poly([[0,-3],[36,-21],[36,-4],[0,14]],'#e1dec2');for(let j=0;j<6;j++)poly([[-31+j*5,-17+j*2.5],[-28+j*5,-15.5+j*2.5],[-28+j*5,-8+j*2.5],[-31+j*5,-9.5+j*2.5]],'#809f9a',null);rect(20,-31,14,8,'#b7c6b7',C.ink,.6);if(era.from>=1998){for(let j=0;j<5;j++)line([[-25+j*6,-26+j*3],[-9+j*6,-34+j*3]],'#385e70',3);line([[12,4],[30,-5]],'#a3b8a7',4);}else{rect(17,-60,8,34,'#c5ab83',C.ink);for(let j=0;j<3;j++){const f=(t*.15+j*.33)%1;ctx.globalAlpha=.18*(1-f);ellipse(20+f*15,-61-f*23,4+f*8,3+f*4,'#829891');}ctx.globalAlpha=1;}return;}
    poly([[-26,-18],[5,-2],[5,7],[-26,-9]],'#a8b7a0');poly([[5,-2],[29,-14],[29,-5],[5,7]],'#d4d9bd');
    poly([[-28,-19],[-17,-31],[-9,-24],[1,-23],[10,-35],[31,-15],[5,-1]],'#79948d');
    for(let i=0;i<5;i++)poly([[-23+i*5,-16+i*2.5],[-20+i*5,-14.5+i*2.5],[-20+i*5,-10+i*2.5],[-23+i*5,-11.5+i*2.5]],'#e6ddb0',null);
    poly([[13,-31],[18,-28],[18,-60],[13,-63]],'#a1765a');poly([[18,-28],[23,-31],[23,-63],[18,-60]],'#c09b75');
    poly([[12,-63],[17,-66],[24,-63],[18,-59]],'#7f7c63');
    for(let i=0;i<4;i++) {const phase=(t*.18+i*.24+seed)%1;ctx.globalAlpha=.28*(1-phase);ellipse(17+phase*14,-64-phase*28,3+phase*7,2+phase*4,'#889f96');}ctx.globalAlpha=1;
    poly([[11,-2],[19,-6],[19,1],[11,5]],'#7c9080');
  }
  function school(seed) {
    shadow(34);
    if(era.from>=1955){poly([[-39,-40],[0,-20],[0,10],[-39,-10]],'#d4c8a5');poly([[0,-20],[39,-40],[39,-10],[0,10]],'#eee5c9');poly([[-41,-42],[0,-62],[41,-42],[0,-22]],'#9caaa0');for(let f=0;f<2;f++)for(let j=0;j<6;j++){poly([[4+j*5,-19+f*13-j*2.5],[7+j*5,-20.5+f*13-j*2.5],[7+j*5,-13.5+f*13-j*2.5],[4+j*5,-12+f*13-j*2.5]],'#84aaa5',null);poly([[-35+j*5,-35+f*13+j*2.5],[-32+j*5,-33.5+f*13+j*2.5],[-32+j*5,-26.5+f*13+j*2.5],[-35+j*5,-28+f*13+j*2.5]],'#84aaa5',null);}ellipse(0,-36,4,4,'#f9efd5',C.ink,.7);line([[0,-38],[0,-36],[2,-35]],C.ink,.7);line([[44,-5],[44,-45]],'#7c8f7a',1);poly([[44,-44],[55,-41],[44,-36]],'#bd765b',null);return;}poly([[-34,-22],[6,-2],[6,9],[-34,-11]],'#dbcda5');poly([[6,-2],[32,-15],[32,-4],[6,9]],C.cream);
    poly([[-37,-23],[-12,-38],[35,-16],[7,-1]],'#b7634b');
    for(let i=0;i<6;i++)poly([[-29+i*5,-19+i*2.5],[-26+i*5,-17.5+i*2.5],[-26+i*5,-12+i*2.5],[-29+i*5,-13.5+i*2.5]],'#8aada8',null);
    poly([[-3,-25],[7,-30],[16,-25],[7,-20]],'#ede1bd');rect(3,-39,8,15,C.cream,C.ink);ellipse(7,-33,2.8,2.8,'#fff5d6',C.ink,.6);line([[7,-35],[7,-33],[9,-33]],C.ink,.6);
    line([[31,-13],[31,-44]],'#8b8d6e',1);poly([[31,-43],[42,-40],[31,-36]],seed>.5?'#d59d6d':'#a4b6a2',null);
  }
  function farm(seed,t) {
    t=motionClock;
    const season=ambience.season,winter=season==='winter',autumn=season==='autumn';
    poly([[-29,0],[0,-15],[31,0],[2,16]],ambience.weather==='snow'?'#e3e7cf':winter?'#c7c7a1':autumn?'#d2bb78':season==='spring'?'#b9cdb1':'#a6bd78','#8ba674',.8);
    for(let i=0;i<6;i++){const y=-9+i*4;line([[-19+i*1.2,y],[8+i*1.2,y+13]],winter?'#a0a27b':autumn?'#a38850':'#70965e',1.8);}
    if(!winter)for(let i=0;i<9;i++){const x=-18+(i%3)*13,y=-2+Math.floor(i/3)*4;
      if(autumn){line([[x,y],[x-1,-5+y]],'#a79350',1);ellipse(x-2,y-5,2.5,1,C.gold);}
      else {line([[x,y],[x+Math.sin(t+i)*.5,y-4]],season==='spring'?'#7d9e74':'#537f50',1);}}
    if(autumn){poly([[14,6],[18,-7],[23,3]],'#c3a967');line([[16,0],[21,-2]],'#8d8157',1);}
    else if(seed>.65&&!winter){poly([[-27,0],[-8,-10],[4,-3],[-15,7]],'#a2c5b0',null);for(let i=0;i<5;i++)line([[-22+i*4,-1-i*2],[-19+i*4,-5-i*2]],'#698e5a',1);}
  }
  function waterTower() {
    shadow(16);for(const x of [-10,10])line([[x,2],[x,-26]],'#6c8c86',2);line([[-10,-12],[10,-24]],'#6c8c86',1);line([[10,-12],[-10,-24]],'#6c8c86',1);
    rect(-14,-38,28,15,'#99bdaf',C.ink);ellipse(0,-38,14,6,'#c2d8bb',C.ink);ellipse(0,-23,14,5,'#81a99c',C.ink);
    line([[12,-22],[20,-18],[20,6]],'#789f9c',2);ellipse(20,6,5,2,'#8ebcbb');
  }
  function rice(seed) {shadow(7);ellipse(0,-4,7,8,'#d0b888',C.ink,.8);ellipse(0,-10,6,2.7,'#e3d2a2',C.ink,.6);line([[-6,-5],[6,-5]],'#a08d65',1);line([[-4,-11],[-4,1]],'#b5a071',.7);line([[3,-11],[3,1]],'#b5a071',.7);}
  function glyph(type,seed,lit,year,t) {
    if(type==='energy')energyGlyph();else if(type==='device')deviceGlyph(year);else if(type==='farm')farm(seed,t);else if(type==='factory')factory(seed,t);else if(type==='school')school(seed);else if(type==='water')waterTower();else if(type==='rice')rice(seed);else house(type,seed,lit,year);
  }
  function propIcon(kind,x=4,y=-5,s=1,t=0) {
    ctx.save();ctx.translate(x,y);ctx.scale(s,s);
    if(kind==='bucket'){poly([[-3,-2],[3,-2],[2,3],[-2,3]],'#b3b9a4',C.ink,.6);line([[-3,-2],[-2,-5],[2,-5],[3,-2]],C.ink,.6);line([[-2,0],[2,0]],'#edf0d8',.7);}
    else if(kind==='basket'||kind==='food'){poly([[-4,-2],[4,-2],[3,2],[-3,2]],C.wood,C.ink,.6);line([[-3,-2],[-2,-5],[2,-5],[3,-2]],C.ink,.6);for(let i=0;i<3;i++)ellipse(-2+i*2,-2,1.5,1.4,kind==='food'?C.gold:C.green);}
    else if(kind==='net'){line([[-1,3],[2,-8]],C.wood,1.1);poly([[2,-8],[9,-7],[8,0],[0,1]],'#9db8ab66',C.ink,.5);for(let i=0;i<3;i++){line([[2+i*2,-7],[1+i*2,0]],'#698f87',.4);line([[1,-5+i*2],[8,-4+i*2]],'#698f87',.4);}}
    else if(kind==='cloth'){poly([[-4,-4],[4,-3],[4,3],[-3,2]],'#d1b39b',C.ink,.5);line([[-1,-3],[-1,2]],'#f6e6ce',1);line([[2,-3],[2,2]],'#a17570',.6);}
    else if(kind==='letter'){rect(-4,-3,8,5,'#f6edcc',C.ink,.6);line([[-4,-3],[0,0],[4,-3]],C.roof,.5);}
    else if(kind==='book'){poly([[-4,-4],[0,-3],[4,-4],[4,2],[0,3],[-4,2]],'#f2e8ca',C.ink,.6);line([[0,-3],[0,3]],C.roof,.8);}
    else if(kind==='tools'){line([[-3,3],[3,-5]],C.wood,1.5);line([[0,-6],[5,-3]],'#73867c',2);}
    else if(kind==='phone'){rect(-2,-4,4,7,'#4e625d',C.ink,.6);rect(-1,-3,2,4,'#bdd9cd');}
    else if(kind==='broom'){line([[-4,4],[3,-9]],'#a38b60',1.6);poly([[-4,2],[-8,7],[-1,10],[1,5]],'#c3ae79',C.ink,.5);}
    else if(kind==='ball'){ellipse(1,0,4,4,'#d4a066',C.ink,.6);line([[-2,-3],[4,3]],'#f2dfb6',.8);}
    else if(kind==='briefcase'){rect(-4,-2,9,6,'#8b7560',C.ink,.6);line([[-2,-2],[-2,-4],[2,-4],[2,-2]],C.ink,.7);}
    else if(kind==='camera'){rect(-4,-3,9,6,'#61766b',C.ink,.6);ellipse(0,0,2,2,'#a8c4b6',C.ink,.5);}
    else if(kind==='umbrella'){line([[0,-10],[0,4],[-2,5]],C.ink,.7);poly([[-9,-9],[-4,-15],[0,-17],[5,-15],[10,-9]],'#8faaa1',C.ink,.6);}
    else if(kind==='tablet'){rect(-4,-5,8,10,'#52756f',C.ink,.6);rect(-3,-4,6,7,'#bed6c8');}
    else if(kind==='cart'){poly([[-4,0],[7,-5],[10,0],[0,5]],C.wood,C.ink,.6);ellipse(-1,5,1.8,1.8,C.ink);ellipse(8,1,1.8,1.8,C.ink);line([[-4,0],[-6,-6]],C.wood,1);}
    else if(kind==='sewing'){rect(-5,0,10,2,C.wood,C.ink,.5);rect(-3,-5,5,5,'#697d70',C.ink,.5);line([[2,-5],[4,-5],[4,-1]],C.ink,.7);}
    else if(kind==='radio'){rect(-5,-4,10,7,'#ab8b67',C.ink,.5);ellipse(-2,-.5,2,2,'#677b6b');line([[3,-4],[6,-10]],C.ink,.5);}
    ctx.restore();
  }
  function person(person,x,y,scale,t,selected=false) {
    t=motionClock;
    const seed=hash(person.id),color=['#b45d46','#6a8da0','#d0a657','#76966f','#977f93'][Math.floor(seed*5)];
    const pose=person.scene?.pose||'walk',work=['work','care','study'].includes(pose),rest=['rest','eat','study'].includes(pose),talk=['talk','queue'].includes(pose);
    ctx.save();ctx.translate(x,y);ctx.scale(scale*(person.age<6?.77:person.age>=75?.92:1),scale*(person.age<6?.77:person.age>=75?.92:1));if(pose==='play')ctx.translate(0,-Math.max(0,Math.sin(t*3+seed*9))*1.8);shadow(3);const step=pose==='walk'?Math.sin(t*7+seed*9)*1.2:0,arm=work?Math.sin(t*3+seed*9)*1.2:talk?-.7:0;
    if(selected){ellipse(0,0,10,5,'#fff2bc',C.roof,1.7);line([[0,-16],[0,-23]],C.roof,1.8);poly([[0,-27],[-3,-24],[0,-21],[3,-24]],C.roof,null);}
    if(rest){line([[-5,-2],[5,-2]],C.wood,2);line([[-4,-2],[-4,2]],C.wood,1);line([[4,-2],[4,2]],C.wood,1);}
    if(rest){line([[-2,-3],[-4,-1],[0,0]],'#52675a',1.7);line([[1,-3],[4,-1],[5,0]],'#52675a',1.7);}
    else {line([[-1,-3],[-2+step,0]],'#52675a',1.6);line([[1,-3],[2-step,0]],'#52675a',1.6);}
    poly([[-2,-8],[2,-8],[3,era.from<1955?-1:-3],[-3,era.from<1955?-1:-3]],color,C.ink,.45);if(era.from<1955)line([[-2,-7],[2,-3]],'#e8d6af',.65);line([[-2,-7],[-4+step*.5,-4+arm]],'#d7b48e',1.4);line([[2,-7],[4-step*.5,-4+arm]],'#d7b48e',1.4);
    ellipse(0,-10,2.3,2.5,'#dcb890',C.ink,.35);ellipse(-.3,-11.7,2.2,1.3,'#525646');if(era.from<1940&&person.age>15&&seed>.5){ellipse(0,-12.5,3.4,.8,'#b3a076',C.ink,.4);rect(-1.7,-14,3.4,1.5,'#b3a076');}if(person.age>=6&&person.age<15)rect(-3,-7,2.5,4,'#b05f48',C.ink,.4);
    propIcon(person.scene?.prop,4,-4+arm,1,t);
    if(pose==='play'){const bounce=Math.abs(Math.sin(t*3+seed*4))*5;ellipse(7,-2-bounce,2.8,2.8,'#d8ad65',C.ink,.5);}
    if(pose==='study'||pose==='eat'){poly([[-5,-4],[5,-9],[13,-5],[3,0]],C.wood,C.ink,.6);line([[-3,-2],[-3,3]],C.wood,1);line([[10,-3],[10,2]],C.wood,1);propIcon(pose==='study'?'book':'food',4,-6,.65,t);}
    if(work){line([[4,1],[10,-2]],C.wood,1.5);ellipse(8,-2,3,1.4,'#c9b281');}
    if(talk){ellipse(7,-17,4,3,'#f4efd9',C.ink,.5);ellipse(6,-17,.5,.5,C.ink);ellipse(8,-17,.5,.5,C.ink);}
    ctx.restore();
  }
  function vehicle(type,x,y,s=1,heading=1,year=2000) {
    ctx.save();ctx.translate(x,y);ctx.scale(s*heading,s);shadow(type==='train'?25:15);
    if(type==='ship'){
      poly([[-24,-2],[25,-2],[15,8],[-13,8]],'#7a968e');poly([[-24,-2],[25,-2],[17,-7],[-15,-7]],C.cream);rect(-8,-17,17,10,C.cream,C.ink);rect(-6,-14,5,4,C.blue);rect(2,-14,5,4,C.blue);line([[0,-17],[0,-32]],C.ink,1);poly([[0,-31],[13,-19],[0,-19]],'#f0ead2',null);line([[-31,9],[-19,9]],'#f6faf0',2);
    } else {
      const train=type==='train',bus=type==='bus',w=train?46:bus?30:19;
      rect(-w/2,-14,w,12,train?(year<1955?'#5c6153':year<1978?'#a8b58b':year<1998?'#e3d7b7':'#c7d5cc'):bus?'#a0b3a0':C.roof,C.ink);
      rect(-w/2,-4,w,4,train?C.roof:'#6f8d7d');for(let i=0;i<(train?6:bus?4:2);i++)rect(-w/2+3+i*6,-11,4,5,'#a4c5bd');
      for(const x of [-w*.32,w*.32])ellipse(x,0,2.5,2.5,'#43584c');if(train){rect(-w/2+1,-16,w-2,2,year<1955?'#535e52':'#839a8c');if(year<1940){rect(12,-25,5,10,'#506457',C.ink,.5);for(let i=0;i<3;i++){const f=(i*.3+lastTime*.3)%1;ctx.globalAlpha=.25*(1-f);ellipse(13-f*20,-27-f*15,3+f*6,2+f*4,'#6c877a');}ctx.globalAlpha=1;}else if(year>=1955){line([[-5,-16],[0,-24],[6,-16]],C.ink,.7);if(year>=1978){rect(-w/2,-6,w,2,year<1998?'#bc6f4e':'#6b9c8e');}}}
    }ctx.restore();
  }
  function resize() {
    if(destroyed)return;const r=canvas.getBoundingClientRect();width=Math.max(280,r.width||1000);height=Math.max(280,r.height||680);dpr=clamp(globalThis.devicePixelRatio||1,1,2);
    canvas.width=Math.round(width*dpr);canvas.height=Math.round(height*dpr);ctx.setTransform(dpr,0,0,dpr,0,0);
    // Equirectangular reference, cos(36°) longitude correction. Far offshore
    // islands remain in the source file; the main map viewport is cropped.
    const mapScale=Math.min((width-90)/(22*Math.cos(Math.PI/5)),(height-80)/22);
    project=(lng,lat)=>[width*.49+(lng-136)*Math.cos(Math.PI/5)*mapScale,height*.49+(35-lat)*mapScale];
    mapPath=new Path2D();for(const polygon of polygons)for(const ring of polygon){ring.forEach(([lng,lat],i)=>{const [x,y]=project(lng,lat);if(i===0)mapPath.moveTo(x,y);else mapPath.lineTo(x,y);});mapPath.closePath();}
  }
  const local=(x,y,scale=1)=>[(x-y)*320*scale,(x+y-1)*174*scale];
  function backdrop(t,year,showSeaNames=true) {
    t=motionClock;
    rect(0,0,width,height,light.night?'#6b8586':light.dusk?'#dfc2a2':light.dawn?'#c9d4c5':'#d8e6de');
    if(!showSeaNames){ellipse(width*.82,height*.21,light.night?15:24,light.night?15:24,light.night?'#f0e4bb':'#e9d9ae');for(let i=0;i<4;i++){const x=width*(.12+i*.24),y=height*(.18+(i%2)*.05);ellipse(x,y,43,6,light.night?'#8b9d9566':'#edf0df88');ellipse(x+19,y-4,24,7,light.night?'#8b9d9566':'#edf0df88');}if(light.night)for(let i=0;i<28;i++)ellipse((i*163)%width,30+(i*51)%(height*.34),.8,.8,'#f7edd0');}
    ctx.save();ctx.globalAlpha=.28;
    for(let i=0;i<30;i++){const x=(i*173.3)%width,y=(i*89.7)%height;const offset=Math.sin(t*.35+i)*3;line([[x-7+offset,y],[x+7+offset,y]],'#9bbeb9',1);}
    ctx.restore();
    if(showSeaNames&&width>520){text('日本海',width*.2,height*.40,13,'#7b9e97');text('太平洋',width*.77,height*.75,13,'#7b9e97');}
  }
  function route(a,b,p,arc=0){return [mix(a[0],b[0],p),mix(a[1],b[1],p)-Math.sin(Math.PI*p)*arc];}
  function mapScene(snapshot,t,options) {
    backdrop(t,snapshot.year);if(mapPath){ctx.save();ctx.translate(0,7);ctx.fillStyle='#759a8d50';ctx.fill(mapPath,'evenodd');ctx.restore();ctx.fillStyle=C.land;ctx.strokeStyle='#789a7c';ctx.lineWidth=1.1;ctx.fill(mapPath,'evenodd');ctx.stroke(mapPath);}
    const places=snapshot.world?.places||[],buildings=snapshot.world?.buildings||[],people=snapshot.world?.people||[];
    const minScale=clamp(Math.min(width/1050,height/700),.5,1.3);
    // Author scenery marks the mountain spine; it is not topographic data.
    for(let i=0;i<20;i++){const lng=130.8+i*.59,lat=32.6+i*.48;if(i>15&&i<18)continue;const [x,y]=project(lng,lat);ctx.save();ctx.translate(x,y);ctx.scale(minScale,minScale);poly([[-8,2],[0,-9],[9,2]],'#9fba8c',null);line([[-3,-5],[0,-9],[5,-2]],'#b6caa0',.8);ctx.restore();}
    for(let i=0;i<places.length-1;i++){const a=places[i],b=places[i+1];if(Math.abs(a.lng-b.lng)>5||Math.abs(a.lat-b.lat)>5)continue;line([project(a.lng,a.lat),project(b.lng,b.lat)],'#a1ac8f',1);}
    const sorted=[...places].sort((a,b)=>b.lat-a.lat),labels=[];
    for(const place of sorted){ambience=environment(place,snapshot);const [x,y]=project(place.lng,place.lat);const selected=place.id===options.placeId;
      ctx.save();ctx.translate(x,y);ctx.scale(minScale,minScale);
      if(selected){ellipse(0,5,37,17,'#f7edba77',C.roof,1.5);}
      if(ambience.landscape==='coast')line([[21,-15],[34,-8],[31,7]],'#8bbcc0',3);else if(ambience.landscape==='mountain')poly([[-28,-10],[-18,-25],[-6,-10]],ambience.season==='autumn'?'#b5ae7d':'#a5bb91',null);
      if(ambience.weather==='snow')ellipse(-3,7,27,10,'#e8ebd188');
      const farmCount=count(place.visual?.farm,4),houseCount=count(Math.ceil(number(place.visual?.houses)/2),8),factoryCount=count(place.visual?.factory,3);
      for(let i=0;i<farmCount;i++){ctx.save();ctx.translate(-20+i*13,12+i%2*5);ctx.scale(.29,.29);farm(hash(place.id+i),t);ctx.restore();}
      for(let i=0;i<houseCount;i++){ctx.save();ctx.translate((i%4-1.5)*11,(Math.floor(i/4)-.5)*9);ctx.scale(.38,.38);house('house',hash(place.id+i),i>=count(Math.ceil(number(place.visual?.vacancy)/2),8),snapshot.year);ctx.restore();}
      for(let i=0;i<factoryCount;i++){ctx.save();ctx.translate(20+i*14,-7);ctx.scale(.32,.32);factory(hash(place.id),t);ctx.restore();}
      if(count(place.visual?.school,1)){ctx.save();ctx.translate(-23,-8);ctx.scale(.3,.3);school(.2);ctx.restore();}
      for(let i=0;i<count(Math.ceil(number(place.visual?.students)/2),6);i++)person({id:`overview-student-${place.id}-${i}`,age:10},-25+i*4,8,.28,t,false);
      if(count(place.visual?.water,1)){ctx.save();ctx.translate(17,11);ctx.scale(.24,.24);waterTower();ctx.restore();}
      if(count(place.visual?.rice,1)){ctx.save();ctx.translate(0,17);ctx.scale(.23,.23);rice(.3);ctx.restore();}
      if(allocation(snapshot,place,'deviceCount',1)){rect(27,-20,6,5,'#e7e1c6',C.ink,.5);rect(28,-19,4,3,C.blue);line([[30,-15],[30,-13]],C.ink,.6);}
      if(allocation(snapshot,place,'energyGlyphs',1)){rect(-9,20,5,5,'#ac916e',C.ink,.5);ellipse(-6.5,22,1,1.4,C.gold);}
      tree(-31,-1,.31,t,Math.floor(hash(place.id)*10));tree(29,14,.27,t,2);
      ctx.restore();
      const east=['hokkaido','tohoku','kanto','tokai','shikoku'].includes(place.id);
      const label=place.region||place.name,fontSize=clamp(11*minScale,10,13);ctx.font=`${fontSize}px system-ui`;const labelW=ctx.measureText(label).width+12;
      const labelX=clamp(x+(east?1:-1)*50*minScale,labelW/2+10,width-labelW/2-10);
      let labelY=clamp(y+18*minScale,28,height-42);
      // Leave the parent UI's top-right view controls readable.
      const switchWidth=width<560?100:225,switchHeight=width<560?108:86;
      if(labelX+labelW/2>width-switchWidth&&labelY<switchHeight)labelY=switchHeight+12;
      for(let tries=0;tries<20&&labels.some(l=>Math.abs(l.x-labelX)<(l.w+labelW)/2+4&&Math.abs(l.y-labelY)<22);tries++)labelY+=22;
      labels.push({x:labelX,y:labelY,w:labelW,fromX:x,fromY:y+13*minScale,label,fontSize,selected,id:place.id});
      hits.push({type:'place',id:place.id,x,y,r:Math.max(18,31*minScale)});
      const residents=people.filter(p=>p.placeId===place.id&&p.alive!==false).slice(0,4);
      residents.forEach((p,i)=>{const position=residentPosition(p,t);person(activePerson(p,t),x+(position[0]-.5)*45*minScale,y+15*minScale+(position[1]-.5)*20*minScale,.49*minScale,t,p.id===options.selectedPersonId);});
      if(count(place.visual?.bus,1)){vehicle('bus',x+Math.sin(motionClock*.3+hash(place.id)*9)*25*minScale,y+23*minScale,.32*minScale,1,snapshot.year);}
    }

    // Only a measured rail signal can create a moving miniature train.
    if(hasSignal(snapshot,'railCount')&&places.length>3){const a=project(133,34.3),b=project(140.5,39),[x,y]=route(a,b,(motionClock*.022)%1);vehicle('train',x,y,.34*minScale,1,snapshot.year);}
    for(const l of labels){line([[l.fromX,l.fromY],[l.x,l.y]],'#6a8b7477',.8);rect(l.x-l.w/2,l.y-9,l.w,18,l.selected?'#fff3d4':'#f6f3dff0');text(l.label,l.x,l.y,l.fontSize,l.selected?C.roof:C.ink);hits.push({type:'place',id:l.id,x:l.x,y:l.y,w:l.w,h:18});}
  }
  function residentPosition(p,t){const r=routineAt(p,t);return [number(r.x,.5),number(r.y,.5)];}
  function activePerson(p,t){return {...p,...routineAt(p,t)};}
  function landscape(t,place,year){
    t=motionClock;
    const land=ambience.landscape,season=ambience.season,snow=ambience.weather==='snow';
    if(land==='mountain'||land==='field'){
      poly([[-370,-120],[-277,-257],[-171,-137],[-90,-231],[30,-145],[111,-218],[262,-120]],season==='autumn'?'#c4bc8b':'#b1c596',null);
      poly([[-354,-111],[-275,-219],[-212,-130],[-165,-174],[-97,-112]],'#9eb889',null);
      if(snow){poly([[-300,-222],[-277,-257],[-248,-224],[-273,-232]],'#e9eddb',null);poly([[-113,-203],[-90,-231],[-66,-207],[-91,-213]],'#edf0dd',null);}
      if(land==='mountain')for(let i=0;i<4;i++){const x=-255+i*30,y=-115+i*17;poly([[x-42,y],[x+16,y-22],[x+58,y-1],[x,y+21]],i%2?'#b1be86':'#c5ca95','#90a279',.7);line([[x-40,y+5],[x,y+26],[x+57,y+5]],'#9d9675',3);for(let j=0;j<4;j++)line([[x-25+j*12,y],[x+3+j*10,y+13]],season==='autumn'?'#ad9656':'#819e64',1.4);}
    }
    if(land==='coast'){
      poly([[249,-194],[409,-95],[419,211],[180,246],[206,119],[257,37],[230,-47]],'#d4d9b0',null);
      poly([[266,-187],[416,-81],[420,218],[198,240],[224,119],[275,38],[248,-47]],C.water,null);
      for(let i=0;i<8;i++){const yy=-105+i*43,xx=305+Math.sin(i)*20,drift=Math.sin(t*.5+i)*3;line([[xx-10+drift,yy],[xx+12+drift,yy]],'#dbece1',1.5);}
      poly([[218,76],[235,69],[297,104],[281,111]],C.wood);for(let i=0;i<6;i++)line([[227+i*9,75+i*5],[222+i*9,79+i*5]],'#9a8b69',.8);
      // Fishing racks and a moored skiff are fictional local scenery, not a shipping count.
      for(const x of [211,243])line([[x,92],[x,54]],'#91866b',2);line([[211,56],[243,56]],'#91866b',1.6);for(let i=0;i<6;i++)line([[214+i*5,57],[216+i*5,84]],'#6d9188',.8);for(let i=0;i<5;i++)line([[214,61+i*5],[241,62+i*5]],'#6d9188',.6);
      poly([[279,126],[313,128],[302,137],[287,135]],'#7e9a90');poly([[283,125],[308,127],[300,132],[289,130]],'#d9c9a2');line([[289,129],[311,119]],'#7d8166',1.5);
    }else if(land==='river'||land==='town'){
      ctx.beginPath();ctx.moveTo(160,-226);ctx.bezierCurveTo(66,-99,294,-46,210,51);ctx.bezierCurveTo(169,107,204,169,307,224);ctx.strokeStyle='#e3e6be';ctx.lineWidth=37;ctx.stroke();ctx.strokeStyle=C.water;ctx.lineWidth=26;ctx.stroke();
      for(let i=0;i<9;i++){const yy=-170+i*42,xx=192+Math.sin(i*1.7)*35;line([[xx-6+Math.sin(t+i)*2,yy],[xx+4+Math.sin(t+i)*2,yy]],'#d9ece0',1.2);}
      poly([[175,-46],[188,-53],[230,-26],[217,-19]],'#c6b18a');line([[175,-52],[219,-25]],'#7f9075',1.6);line([[189,-58],[231,-31]],'#7f9075',1.6);
    }
    if(ambience.placeId==='tokai'){for(let i=0;i<4;i++)line([[-280+i*16,-84+i*6],[-205+i*16,-46+i*6]],'#72976c',7);}
    if(['shikoku','kyushu'].includes(ambience.placeId)){for(let i=0;i<5;i++){tree(-255+i*32,95+(i%2)*16,.65,t,i+2);if(season==='autumn'||season==='winter')for(let j=0;j<3;j++)ellipse(-258+i*32+j*3,78+(i%2)*16+(j%2)*3,2,2,'#d4a359');}}
    // A fictional stone well marks the optional water-fetching scene anchor.
    ellipse(-138,-15,12,6,'#b9baa3',C.ink,.8);rect(-149,-23,22,8,'#b4baa4',C.ink,.7);ellipse(-138,-23,11,5,'#d4d4b9',C.ink,.8);ellipse(-138,-23,7,3,'#758f84');line([[-150,-24],[-150,-44],[-126,-44],[-126,-24]],'#998765',1.5);line([[-138,-44],[-138,-25]],'#9a9979',.8);propIcon('bucket',-122,-17,1.4);
    // Household details: an open workbench, stacked fuel and washing on a line.
    poly([[-150,12],[-132,3],[-108,15],[-126,25]],'#bd9e71');line([[-144,15],[-144,24]],C.ink,1.5);line([[-114,20],[-114,29]],C.ink,1.5);line([[-141,9],[-122,19]],'#ece0b6',2);
    if(year<1960)for(let i=0;i<5;i++){line([[-174+i*3,16],[-169+i*3,9]],'#a0845f',2.4);ellipse(-173+i*3,16,1.3,1.1,'#d0b480');}
    line([[-74,-76],[-74,-103]],'#a19572',2);line([[-19,-48],[-19,-76]],'#a19572',2);line([[-74,-101],[-19,-74]],'#8c9279',.8);
    for(let i=0;i<3;i++){const x=-64+i*15,y=-96+i*7,sway=Math.sin(t+i)*1.5;poly([[x,y],[x+11,y+5],[x+11+sway,y+19],[x+sway,y+14]],['#e9dcc1','#9cb8ad','#c49a85'][i],null);}
    if(ambience.weather==='rain')for(let i=0;i<24;i++){const x=-300+(i*97)%650,y=-160+(i*47+t*22)%350;line([[x,y],[x-3,y+7]],'#638b9c55',.8);}
    if(snow)for(let i=0;i<32;i++){const x=-325+(i*73)%660,y=-180+(i*47+t*9)%370;ellipse(x,y,1.5,1.2,'#f5f4e1');}
  }
  function townStreets(buildings,year,t){
    const modern=year>=1955,road=era.road;
    // The streets share the world's coordinate system with destinations.
    for(const axis of ['x','y'])for(const value of [.28,.52,.76]){
      const a=axis==='x'?local(value,.07):local(.07,value),b=axis==='x'?local(value,.93):local(.93,value);
      line([a,b],modern?'#c7ccba':'#dcd1ae',modern?24:16);line([a,b],road,modern?16:11);
      if(modern){for(let j=0;j<8;j++){const f=j/8,g=(j+.42)/8;line([[mix(a[0],b[0],f),mix(a[1],b[1],f)],[mix(a[0],b[0],g),mix(a[1],b[1],g)]],'#d8deca',.8);}}
    }
    for(const b of buildings){const p=local(b.x,b.y),near=[.28,.52,.76].reduce((v,n)=>Math.abs(n-b.x)<Math.abs(v-b.x)?n:v,.28),q=local(near,b.y);line([p,q],modern?'#c9cfbc':'#e3d3b0',5);}
    const square=local(.52,.52);ellipse(square[0],square[1],36,18,modern?'#b3c4af':'#d2c5a2','#9aaf96',1);ellipse(square[0],square[1],21,10,modern?'#a0b6a4':'#baba91',null);
    tree(square[0],square[1],.6,t,5);line([[square[0]-26,square[1]+11],[square[0]-8,square[1]+20]],'#ae926e',3);line([[square[0]+7,square[1]+18],[square[0]+25,square[1]+9]],'#ae926e',3);
    // Road furniture is authored scenery; it does not depict utility coverage.
    for(let j=0;j<5;j++){const [x,y]=local(.28,.17+j*.16);line([[x-10,y-3],[x-10,y-58]],year<1955?'#8a7757':'#82978b',2);line([[x-19,y-53],[x-1,y-53]],'#637e70',1.3);ellipse(x-15,y-54,1.3,2,'#d9e0c4');ellipse(x-5,y-54,1.3,2,'#d9e0c4');if(j<4){const [xx,yy]=local(.28,.33+j*.16);ctx.beginPath();ctx.moveTo(x-15,y-54);ctx.quadraticCurveTo((x+xx)/2-15,(y+yy)/2-45,xx-15,yy-54);ctx.strokeStyle='#6e82746b';ctx.lineWidth=.65;ctx.stroke();}if(year>=1955){line([[x-10,y-49],[x+1,y-47]],'#87978a',1);ellipse(x+1,y-47,3,1.5,light.night?'#ffdc8e':'#d9dec4');if(light.night){ctx.globalAlpha=.12;ellipse(x+1,y+3,22,11,'#ffd180');ctx.globalAlpha=1;}}}
    // Allotments and a little playground create readable districts.
    for(let j=0;j<4;j++){const [x,y]=local(.12+j*.13,.88);poly([[x-23,y],[x,y-12],[x+23,y],[x,y+12]],ambience.season==='autumn'?'#c8b475':'#a3b57f','#8e9e77',.65);for(let k=0;k<4;k++)line([[x-14+k*7,y-4+k*1.5],[x-3+k*7,y+2+k*1.5]],ambience.season==='winter'?'#9aa17c':'#72976b',1.6);}
    const [px,py]=local(.17,.58);ellipse(px,py,30,14,'#d4c8a1','#aab893',.7);line([[px-18,py],[px-18,py-30],[px+14,py-14],[px+14,py+16]],'#9b8360',1.4);line([[px-10,py-26],[px-10,py-7]],'#8a9276',.8);line([[px+3,py-20],[px+3,py-1]],'#8a9276',.8);line([[px-14,py-5],[px-6,py-1]],'#b29a6d',2);line([[px-1,py+1],[px+7,py+5]],'#b29a6d',2);
    if(modern)for(const row of [.28,.76])for(let j=0;j<5;j++){const [x,y]=local(.49+j*.011,row);line([[x-4,y-2],[x+3,y+2]],'#e7e9d5',2.5);}
  }
  function scenicDistricts(place,year){
    // A collection of little blocks, not a row of identical display models.
    // All structures here are author scenery, independent of macro counts.
    const dense=['kanto','kinki','tokai'].includes(place.id),rural=['hokkaido','koshin','shikoku','kyushu'].includes(place.id),items=[];
    const add=(x,y,kind,index,s=.8)=>{const seed=hash(place.id+'district-'+index);items.push({kind:'scenery',item:{type:kind,seed:kind==='shop'?seed:seed*.78},pos:[x,y],depth:1+y/174,scale:s});};
    // Three uneven rear blocks leave alleys and taller landmarks between them.
    const rear=[[-244,-92],[-210,-118],[-164,-95],[-134,-141],[-91,-108],[-57,-155],[-15,-121],[29,-153],[67,-112],[105,-140],[145,-103],[179,-124],[215,-90]];
    rear.forEach(([x,y],i)=>{if(!dense&&i%4===2)return;add(x,y,i%6===1?'shop':'house',i,.66+(i%3)*.09);});
    // The left foreground has a lane of shops and small back gardens.
    const foreground=[[-244,40],[-225,76],[-192,106],[-155,131],[-115,158],[-72,175]];
    foreground.forEach(([x,y],i)=>add(x,y,i===1||i===4?'shop':'house',20+i,.72+(i%2)*.08));
    // A few quiet buildings around the cultivated eastern edge.
    for(let i=0;i<(dense?3:4);i++)add(100+i*32,124-i*17,i===0&&!rural?'shop':'house',40+i,.64);
    if(year>=1955&&dense){add(28,-139,'house',70,.9);items[items.length-1].item.seed=.92;add(-143,-112,'house',71,.84);items[items.length-1].item.seed=.85;}
    return items;
  }
  function regionalScenery(place,t,year){
    t=motionClock;
    const land=ambience.landscape,north=['hokkaido','tohoku','hokuriku','koshin'].includes(place.id),forest=land==='mountain';
    // Meandering edges and patches soften the street grid into a lived-in town.
    const plots=[[-286,75],[-263,104],[-225,137],[-181,164],[121,162],[154,145],[185,124]];
    for(let i=0;i<plots.length;i++){const [x,y]=plots[i];poly([[x-25,y],[x+3,y-15],[x+32,y],[x+4,y+16]],ambience.season==='winter'?'#b0b99b':ambience.season==='autumn'?'#c3b478':'#a1b87d','#8fa37a',.6);for(let k=0;k<5;k++)line([[x-15+k*7,y-3+k*.8],[x-2+k*7,y+5+k*.8]],ambience.season==='autumn'?'#a78e54':'#789c64',1.8);if(i%2===0){line([[x-28,y],[x-3,y+17],[x+31,y+1]],'#ad9b72',1);for(let k=0;k<5;k++)line([[x-25+k*12,y+(k<3?k*4:20-k*4)],[x-25+k*12,y-7+(k<3?k*4:20-k*4)]],'#a18d68',1);}}
    const groves=forest?[[-296,-98],[-240,-158],[-144,-177],[79,-189],[-310,38],[-219,173]]:north?[[-287,-111],[-170,-176],[60,-185],[-303,44],[-195,172]]:[[-285,-108],[-127,-187],[90,-181],[-304,37],[-200,177]];
    for(let g=0;g<groves.length;g++){const [gx,gy]=groves[g],amount=forest?6:north?4:3;for(let j=0;j<amount;j++)tree(gx+(j%3)*17,gy+Math.floor(j/3)*14+(j%2)*4,.6+hash(place.id+g+j)*.35,t,north?j*3:g+j);}
    if(land==='coast'){
      // A harbor with a breakwater, nets, crates and lighthouse is a strong region cue.
      poly([[259,-32],[275,-40],[345,-3],[329,5]],'#b7bba5','#8e9d89',1);line([[265,-35],[336,1]],'#e6dec1',2);rect(320,-24,10,20,'#f0dfb9',C.ink,.7);poly([[318,-24],[325,-30],[332,-24]],'#b66049');ellipse(325,-22,2,2,light.night?'#ffe59c':'#7fa09a');for(let j=0;j<5;j++){const x=254+j*9,y=61+j*4;poly([[x,y],[x+5,y-3],[x+11,y],[x+6,y+4]],'#b69c71',C.ink,.55);line([[x+5,y-3],[x+5,y+3]],'#8e7d5f',.55);}for(let j=0;j<4;j++)line([[273+j*7,120+j*3],[280+j*7,111+j*3]],'#6b9289',.8);
    }else if(land==='river'||land==='town'){
      for(let j=0;j<10;j++){const x=198+Math.sin(j*1.7)*29,y=-158+j*35;line([[x+17,y],[x+16,y-8]],'#7b9e7d',1);line([[x+19,y],[x+22,y-6]],'#88a378',1);ellipse(x+10,y+3,2,1.4,'#c1c5a2');}
      poly([[180,30],[194,21],[238,44],[224,53]],year<1955?'#b4a079':'#b4bbaa');for(let j=0;j<6;j++)line([[183+j*7,28+j*3.6],[192+j*7,23+j*3.6]],'#e3d4ac',.9);line([[180,25],[224,48]],'#6d8875',1.5);line([[194,16],[238,39]],'#6d8875',1.5);
    }
    // A shrine and approach remain while the surrounding town changes.
    const x=-285,y=-15;poly([[x-24,y],[x,y-12],[x+26,y],[x,y+13]],'#bdbea0',null);rect(x-9,y-21,18,18,'#bca078',C.ink);poly([[x-20,y-22],[x,y-34],[x+20,y-22],[x,y-12]],'#647c70');line([[x-17,y+19],[x-17,y-4]],'#ab6350',2.7);line([[x+17,y+2],[x+17,y-21]],'#ab6350',2.7);line([[x-23,y-7],[x+23,y-29]],'#a85d4b',3.7);line([[x-21,y-2],[x+21,y-22]],'#a85d4b',1.8);line([[x,y+10],[x+20,y+20],[x+37,y+15]],'#d8c8a1',7);
    if(place.id==='hokkaido'){poly([[-279,-135],[-245,-152],[-211,-134],[-245,-117]],'#baa87c');for(let j=0;j<6;j++)line([[-268+j*8,-133+j*1.2],[-245+j*5,-144+j*2.7]],'#8b9a64',2.2);rect(-249,-170,10,19,'#d5c3a0',C.ink,.6);poly([[-252,-170],[-244,-177],[-236,-170]],'#9e6050');}
    if(place.id==='tokai'){for(let j=0;j<5;j++)line([[82+j*13,169-j*7],[118+j*13,188-j*7]],'#679164',5);}
    if(['shikoku','kyushu'].includes(place.id)){for(let j=0;j<7;j++){tree(152+j%3*23,156-Math.floor(j/3)*22,.5,t,j+2);for(let k=0;k<3;k++)ellipse(149+j%3*23+k*4,143-Math.floor(j/3)*22+(k%2)*4,1.5,1.5,'#d7a04f');}}
  }
  function streetTransport(year,t){
    t=motionClock;
    const p=(t*.025+.17)%1,[x,y]=local(.76,.08+p*.82);ctx.save();ctx.translate(x,y);ctx.scale(.75,.75);
    if(era.transport==='cart'){line([[-17,-3],[17,-3]],'#977d57',2);poly([[-13,-13],[10,-13],[15,-4],[-8,-4]],'#bda374');ellipse(-8,0,4,4,'#796e50',C.ink);ellipse(12,0,4,4,'#796e50',C.ink);line([[15,-5],[28,-9]],C.wood,2);ellipse(29,-13,5,3,'#9c8664');line([[28,-12],[26,-2]],C.wood,2);}
    else if(era.transport==='bicycle'){for(const a of [-8,9])ellipse(a,0,5,5,null||'#c2c9ad',C.ink,1);line([[-8,0],[0,-10],[9,0],[-8,0],[2,-4],[0,-10]],C.ink,1);person({id:'scenery-cyclist',scene:{pose:'rest'},age:28},0,-5,.8,t);}
    else if(era.transport==='tram'){rect(-25,-22,50,18,'#b09265',C.ink);rect(-25,-8,50,5,'#567f70');for(let j=0;j<6;j++)rect(-21+j*7,-19,5,8,'#a1bab0');line([[-8,-23],[0,-32],[8,-23]],C.ink,1);ellipse(-15,0,3,3,C.ink);ellipse(15,0,3,3,C.ink);}
    else{poly([[-17,-5],[-10,-15],[8,-15],[18,-5]],era.transport==='electric'?'#e4e4cc':era.transport==='compact'?'#a1b6ac':'#cfb977');poly([[-16,-5],[18,-5],[20,1],[-18,1]],era.transport==='sedan'?'#b76a54':'#e6e5cb');poly([[-8,-13],[1,-13],[1,-7],[-13,-7]],'#6f9a9b',null);poly([[4,-13],[9,-13],[15,-7],[4,-7]],'#6f9a9b',null);ellipse(-11,2,3,3,C.ink);ellipse(12,2,3,3,C.ink);if(light.night){ctx.globalAlpha=.15;poly([[20,0],[67,-15],[67,8]],'#ffe0a4',null);ctx.globalAlpha=1;}}
    ctx.restore();
  }
  function infrastructure(snapshot,place,t){
    t=motionClock;
    const measuredRails=allocation(snapshot,place,'railCount',3),rails=Math.max(1,measuredRails),a=local(.15,.02),b=local(.15,.98);
    // Track and one scenery train are authored period atmosphere. Extra carriages
    // continue to illustrate the model's measured rail allocation separately.
    line([a,b],'#aaa88b',12);line([a,b],'#5f7c70',5);line([[a[0]-3,a[1]+2],[b[0]-3,b[1]+2]],'#ece5c8',1.2);line([[a[0]+3,a[1]-2],[b[0]+3,b[1]-2]],'#ece5c8',1.2);
    for(let i=0;i<32;i++){const x=mix(a[0],b[0],i/31),y=mix(a[1],b[1],i/31);line([[x-4,y-4],[x+4,y+4]],'#71826d',1);}
    const p=(t*.024)%1,tx=mix(a[0],b[0],p),ty=mix(a[1],b[1],p);
    for(let i=0;i<rails;i++)vehicle('train',tx+i*30,ty-i*16,.62,-1,snapshot.year);
    const [sx,sy]=local(.18,.75);
    poly([[sx-32,sy+6],[sx-6,sy-7],[sx+21,sy+6],[sx-6,sy+20]],'#c8ba9b','#9b9f82',.7);
    poly([[sx-20,sy-3],[sx,sy-13],[sx+20,sy-3],[sx,sy+7]],era.roof);line([[sx-14,sy],[sx-14,sy-14]],'#8e8367',1.5);line([[sx+14,sy],[sx+14,sy-14]],'#8e8367',1.5);
    rect(sx-12,sy-26,24,10,'#f4e8c3',C.ink,.6);text('町の駅',sx,sy-21,7.5,C.ink);
    if(snapshot.year>=1955)for(let i=0;i<4;i++){const x=mix(a[0],b[0],i/3),y=mix(a[1],b[1],i/3);line([[x-10,y],[x-10,y-44],[x+8,y-44]],'#789184',1.3);if(i<3)line([[x-10,y-44],[mix(a[0],b[0],(i+1)/3)-10,mix(a[1],b[1],(i+1)/3)-44]],'#82998c88',.7);}
  }
  function energyGlyph(){
    shadow(12);poly([[-10,0],[0,-5],[10,0],[0,6]],'#b19772');rect(-6,-14,12,13,'#a98c6d',C.ink,.8);ellipse(0,-7,3,4,'#d8a665');ellipse(0,-7,1.2,2.5,'#f2d589');for(let j=0;j<4;j++)line([[-14+j*3,5],[-7+j*3,0]],'#8d795c',2);
  }
  function deviceGlyph(year){
    shadow(14);poly([[-13,0],[0,-6],[13,0],[0,7]],C.wood);line([[-10,1],[-10,8]],C.wood,1.5);line([[10,1],[10,8]],C.wood,1.5);if(year>=2010){rect(-3,-13,7,12,'#526b63',C.ink,.8);rect(-2,-11,5,8,'#afd0c2');ellipse(0,-2,.7,.7,'#e7e3cc');}else{rect(-9,-18,18,13,'#dedac3',C.ink,.8);rect(-6,-15,12,7,'#89aca4');line([[0,-5],[0,-1]],C.ink,1);poly([[-7,-1],[6,-1],[9,2],[-5,4]],'#e6e1c8',C.ink,.6);}
  }

  function residentBubble(p,x,y,figureScale=1){
    const activity=String(p.scene?.activity||p.activity||'暮らしのひとこま'),label=activity.length>15?activity.slice(0,14)+'…':activity,size=width<560?11:12;
    ctx.font=`${size}px system-ui`;const w=Math.min(width-24,ctx.measureText(label).width+42),xx=clamp(x,w/2+12,width-w/2-12);let yy=clamp(y-32*figureScale-18,85,height-60);
    if(xx-w/2<230&&yy<175)yy=175;
    line([[x,y-27*figureScale],[xx,yy+13]],C.roof,1);rect(xx-w/2,yy-13,w,26,'#faf4dd',C.roof,1.2);propIcon(p.scene?.prop,xx-w/2+15,yy,1.5);text(label,xx+9,yy,size,C.ink);
  }
  function placeScene(snapshot,t,options) {
    const place=(snapshot.world?.places||[]).find(p=>p.id===options.placeId)||(snapshot.world?.places||[])[0];if(!place){mapScene(snapshot,t,options);return;}
    const zoom=clamp(number(options.zoom,1),1,1.6),scale=clamp(Math.min((width-28)/790,(height-54)/490),.30,1.8)*zoom,cx=width/2,cy=height*.55,residentScale=2.2;
    ambience=environment(place,snapshot);backdrop(t,snapshot.year,false);ctx.save();ctx.translate(cx,cy);ctx.scale(scale,scale);
    const base=[[-373,-32],[-256,-169],[-64,-223],[149,-191],[338,-80],[383,66],[225,193],[-38,224],[-279,151]];
    // Cut earth and a paper rim give the entire town weight and a readable edge.
    ctx.save();ctx.translate(0,19);poly(base,'#7f9b86',null);ctx.restore();ctx.save();ctx.translate(0,10);poly(base,'#a4b69a',null);ctx.restore();
    poly(base,ambience.weather==='snow'?'#dce3ce':ambience.season==='autumn'?'#d0caa0':ambience.season==='winter'?'#c4cbb0':'#bdcba0','#8caa86',1.3);
    const buildings=(snapshot.world?.buildings||[]).filter(b=>b.placeId===place.id);
    ctx.beginPath();base.forEach(([x,y],i)=>i?ctx.lineTo(x,y):ctx.moveTo(x,y));ctx.closePath();ctx.save();ctx.clip();
    landscape(t,place,snapshot.year);
    townStreets(buildings,snapshot.year,t);
    regionalScenery(place,t,snapshot.year);
    // Orchard and field borders hold the quieter edge of town.
    const trees=[[-315,-24],[-277,72],[-211,136],[-160,-137],[-72,-185],[100,-169],[297,50],[263,133],[-293,-107],[104,151],[-22,186],[315,-48]];
    trees.forEach(([x,y],i)=>{if(ambience.landscape!=='coast'||x<220)tree(x,y,.7+(i%3)*.13,t,i);});
    infrastructure(snapshot,place,t);
    // Painter order combines people and buildings, preserving destination space.
    const objects=scenicDistricts(place,snapshot.year).concat(buildings.map(b=>({kind:'building',item:b,pos:local(number(b.x,.5),number(b.y,.5)),depth:number(b.x)+number(b.y)})));
    const people=snapshot.world?.placePeople?.[place.id]||(snapshot.world?.people||[]).filter(p=>p.placeId===place.id&&p.alive!==false);
    people.forEach(p=>{const person=activePerson(p,t),x=number(person.x,.5),y=number(person.y,.5);const pos=local(x,y),spread=person.scene?.pose==='walk'?8:34;pos[0]+=(hash(person.id+'offset-x')-.5)*spread;pos[1]+=(hash(person.id+'offset-y')-.5)*spread*.6;objects.push({kind:'person',item:person,pos,depth:x+y+(pos[1]-local(x,y)[1])/174});});
    objects.sort((a,b)=>a.depth-b.depth);
    for(const o of objects){const [x,y]=o.pos;if(o.kind==='scenery'){ctx.save();ctx.translate(x,y);ctx.scale(o.scale,o.scale);house(o.item.type,o.item.seed,true,snapshot.year);ctx.restore();}else if(o.kind==='building'){
      ctx.save();ctx.translate(x,y);ctx.scale(1.13,1.13);glyph(o.item.type,hash(o.item.id+place.id),o.item.lit!==false,snapshot.year,t);
      if(o.item.type==='shop'&&place.visual?.priceIndex!==null&&place.visual?.priceIndex!==undefined){rect(-29,15,61,12,'#f8f2dd',C.ink,.5);text(`指数 ${Number(place.visual.priceIndex).toFixed(1)}`,1,21,8.5,C.ink);}ctx.restore();
    }else{person(o.item,x,y,residentScale,t,false);hits.push({type:'person',id:o.item.id,x:cx+x*scale,y:cy+(y-6*residentScale)*scale,r:Math.max(14,10*residentScale*scale)});}}
    const focus=objects.find(o=>o.kind==='person'&&o.item.id===options.selectedPersonId);
    if(focus){
      const from=local(number(focus.item.from?.x,.5),number(focus.item.from?.y,.5)),to=local(number(focus.item.to?.x,.5),number(focus.item.to?.y,.5));
      if(focus.item.scene?.pose==='walk'){ctx.save();ctx.setLineDash([3,5]);line([from,to],'#a5553d',1.4);ctx.restore();ellipse(to[0],to[1],13,6,'#f9e5a788',C.roof,1.2);}
      // Always show the person being followed, including at a tall destination.
      ctx.save();ctx.globalAlpha=.3;ellipse(focus.pos[0],focus.pos[1]-13,16,24,'#fff5ca');ctx.restore();person(focus.item,focus.pos[0],focus.pos[1],residentScale*1.13,t,true);
    }
    const schoolBuilding=buildings.find(b=>b.type==='school'),schoolPos=schoolBuilding?local(schoolBuilding.x,schoolBuilding.y):[-90,48];
    for(let i=0;i<count(place.visual?.students,16);i++){const drift=Math.sin(motionClock*.7+i)*3;person({id:`student-${place.id}-${i}`,age:10,scene:{pose:'play'}},schoolPos[0]-26+(i%8)*7+drift,schoolPos[1]+16+Math.floor(i/8)*8,.68,t,false);}
    const vehicles=(snapshot.world?.vehicles||[]).filter(v=>v.placeId===place.id&&v.type==='bus');
    vehicles.slice(0,6).forEach(v=>{const p=(motionClock*.035+hash(v.id))%1,[x,y]=local(.76,.08+p*.84);vehicle(v.type,x,y,.75,1,snapshot.year);});
    streetTransport(snapshot.year,t);
    if(light.night||light.dusk||light.dawn){ctx.globalAlpha=light.night?.15:light.dusk?.07:.04;poly(base,light.night?'#244c62':light.dusk?'#d6a06c':'#c0d7c2',null);ctx.globalAlpha=1;}
    ctx.restore();ctx.restore();
    const selected=objects.find(o=>o.kind==='person'&&o.item.id===options.selectedPersonId);if(selected)residentBubble(selected.item,cx+selected.pos[0]*scale,cy+selected.pos[1]*scale,residentScale*scale);
    // A quiet model label complements the owner's year stamp, never covers roofs.
    const labelW=Math.min(width-30,280);rect(cx-labelW/2,height-34,labelW,25,'#f4edd8ec','#9aa88b',.7);text(`${place.name}  ·  ${era.label}`,cx,height-21.5,width<560?10:12,C.ink);
  }
  function render(snapshot,elapsedSeconds=0,options={}) {
    if(destroyed||!snapshot)return;hits=[];ctx.setTransform(dpr,0,0,dpr,0,0);ctx.lineCap='round';ctx.lineJoin='round';ctx.globalAlpha=1;
    const view=options.view==='place'?'place':'japan',t=Math.max(0,number(elapsedSeconds));
    motionClock=options.reducedMotion?0:t;
    lastTime=motionClock;era=eraProfile(snapshot.year);light=dailyLight(options.dailyHour??dayClockAt(t).dailyHour);
    if(view==='place')placeScene(snapshot,t,options);else mapScene(snapshot,t,options);
  }
  function location(event){const r=canvas.getBoundingClientRect();return [event.clientX-r.left,event.clientY-r.top];}
  function hit(event){const [x,y]=location(event);return [...hits].reverse().find(h=>h.w?Math.abs(h.x-x)<h.w/2&&Math.abs(h.y-y)<h.h/2:(h.x-x)**2+(h.y-y)**2<h.r**2);}
  const click=(event)=>{const h=hit(event);if(!h)return;if(h.type==='person')onPersonSelect(h.id);else {onPlaceSelect(h.id);onViewChange('place',h.id);}};
  const move=(event)=>{canvas.style.cursor=hit(event)?'pointer':'default';};
  canvas.addEventListener('click',click);canvas.addEventListener('pointermove',move);resize();
  return {render,resize,destroy(){destroyed=true;hits=[];canvas.removeEventListener('click',click);canvas.removeEventListener('pointermove',move);canvas.style.cursor='';}};
}
