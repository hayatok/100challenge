// Original Canvas2D paper diorama. Geography is supplied as a GeoJSON Feature.
// All counts and identities belong to the model; motion here only animates them.
const C = { ink:'#42584b', sea:'#d8e9e7', land:'#c8d9aa', side:'#96b18e', roof:'#b85744', roofLight:'#d47b5b', cream:'#f2e7c9', wood:'#c9ad7e', green:'#759b67', darkGreen:'#4b795b', water:'#8bbcc0', road:'#eadfc4', rail:'#73877c', blue:'#638b9c', gold:'#d2aa5b' };
const clamp = (n,a,b) => Math.max(a,Math.min(b,n));
const number = (n, fallback=0) => Number.isFinite(Number(n)) ? Number(n) : fallback;
const hash = (value) => { let n=2166136261; for (const c of String(value)) n=Math.imul(n^c.charCodeAt(0),16777619); return (n>>>0)/4294967296; };
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
    ctx.save();ctx.translate(x,y);ctx.scale(s,s);const sway=Math.sin(t+variant)*1.2;
    ellipse(1,1,10,3,'#8da87d55');line([[0,1],[sway,-23]],'#7f7854',2.3);
    if(variant%3===0){poly([[sway,-38],[-12+sway,-12],[13+sway,-12]],C.darkGreen,null);poly([[sway,-31],[-14+sway,-6],[15+sway,-6]],C.green,null);}
    else {ellipse(sway,-23,13,12,C.green);ellipse(-6+sway,-19,9,9,'#83a771');ellipse(7+sway,-25,9,10,C.darkGreen);ellipse(-2+sway,-30,8,8,'#8bb078');}
    ctx.restore();
  }
  function shadow(w=15){ellipse(2,2,w,5,'#5b73502b');}
  function house(kind='house',seed=0,lit=true,year=1900) {
    const modern=year>=1970,wide=kind==='shop'?22:16,h=kind==='shop'?17:20;
    shadow(wide+3);
    poly([[-wide,-h],[0,-h+wide*.46],[0,5],[-wide,5-wide*.46]],'#ddc79d');
    poly([[0,-h+wide*.46],[wide,-h],[wide,5-wide*.46],[0,5]],lit?C.cream:'#d6d4bd');
    if(modern&&seed>.64&&kind==='house'){
      poly([[-wide,-h],[0,-h-wide*.45],[wide,-h],[0,-h+wide*.45]],'#8b9e91');
      poly([[0,-h+wide*.45],[wide,-h],[wide,-h+4],[0,-h+wide*.45+4]],'#718c83');
    } else {
      poly([[-wide-3,-h-1],[-wide*.44,-h-17],[wide+3,-h-4],[wide*.22,-h+wide*.46]],seed>.7?'#738d85':C.roof);
      poly([[-wide*.44,-h-17],[2,-h-14],[wide+3,-h-4]],seed>.7?'#95a69a':C.roofLight);
      line([[-wide,-h-3],[-wide*.3,-h-15]],'#6f5544',.7);
    }
    const window=lit?'#f2cb72':'#6d837b';
    poly([[-wide+4,-h+5],[-4,-h+wide*.46+2],[-4,-h+wide*.46+8],[-wide+4,-h+11]],window,null);
    poly([[5,-h+wide*.46+4],[11,-h+2],[11,-h+12],[5,-h+wide*.46+14]],window,null);
    poly([[1,-5],[5,-7],[5,2],[1,4]],'#857a5a',null);
    if(kind==='shop'){
      poly([[1,-h+10],[wide,-h+1],[wide+5,-h+9],[6,-h+18]],seed>.6?'#6b9984':C.roofLight);
      line([[7,-h+7],[12,-h+15]],C.cream,3);line([[15,-h+3],[20,-h+11]],C.cream,3);
      poly([[8,3],[24,-5],[27,-2],[11,6]],C.wood);
      ellipse(13,1,2,1.7,C.gold);ellipse(18,-1,2,1.7,'#b96443');ellipse(22,-3,2,1.7,C.green);
    }
    if(!lit){line([[6,-16],[12,-9]],'#9b9f89',1);line([[12,-18],[6,-7]],'#9b9f89',1);}
  }
  function factory(seed,t) {
    shadow(28);
    poly([[-26,-18],[5,-2],[5,7],[-26,-9]],'#a8b7a0');poly([[5,-2],[29,-14],[29,-5],[5,7]],'#d4d9bd');
    poly([[-28,-19],[-17,-31],[-9,-24],[1,-23],[10,-35],[31,-15],[5,-1]],'#79948d');
    for(let i=0;i<5;i++)poly([[-23+i*5,-16+i*2.5],[-20+i*5,-14.5+i*2.5],[-20+i*5,-10+i*2.5],[-23+i*5,-11.5+i*2.5]],'#e6ddb0',null);
    poly([[13,-31],[18,-28],[18,-60],[13,-63]],'#a1765a');poly([[18,-28],[23,-31],[23,-63],[18,-60]],'#c09b75');
    poly([[12,-63],[17,-66],[24,-63],[18,-59]],'#7f7c63');
    for(let i=0;i<4;i++) {const phase=(t*.18+i*.24+seed)%1;ctx.globalAlpha=.28*(1-phase);ellipse(17+phase*14,-64-phase*28,3+phase*7,2+phase*4,'#889f96');}ctx.globalAlpha=1;
    poly([[11,-2],[19,-6],[19,1],[11,5]],'#7c9080');
  }
  function school(seed) {
    shadow(34);poly([[-34,-22],[6,-2],[6,9],[-34,-11]],'#dbcda5');poly([[6,-2],[32,-15],[32,-4],[6,9]],C.cream);
    poly([[-37,-23],[-12,-38],[35,-16],[7,-1]],'#b7634b');
    for(let i=0;i<6;i++)poly([[-29+i*5,-19+i*2.5],[-26+i*5,-17.5+i*2.5],[-26+i*5,-12+i*2.5],[-29+i*5,-13.5+i*2.5]],'#8aada8',null);
    poly([[-3,-25],[7,-30],[16,-25],[7,-20]],'#ede1bd');rect(3,-39,8,15,C.cream,C.ink);ellipse(7,-33,2.8,2.8,'#fff5d6',C.ink,.6);line([[7,-35],[7,-33],[9,-33]],C.ink,.6);
    line([[31,-13],[31,-44]],'#8b8d6e',1);poly([[31,-43],[42,-40],[31,-36]],seed>.5?'#d59d6d':'#a4b6a2',null);
  }
  function farm(seed,t) {
    poly([[-29,0],[0,-15],[31,0],[2,16]],seed>.5?'#aec584':'#b9ca86','#8ba674',.8);
    for(let i=0;i<6;i++){const y=-9+i*4;line([[-19+i*1.2,y],[8+i*1.2,y+13]],seed>.5?'#70965e':'#91a85e',1.8);}
    if(seed>.65){poly([[-27,0],[-8,-10],[4,-3],[-15,7]],'#a2c5b0',null);for(let i=0;i<5;i++)line([[-22+i*4,-1-i*2],[-19+i*4,-5-i*2]],'#698e5a',1);}
    else {ellipse(14,1,3,2,'#d5b766');line([[14,2],[14,-7]],'#9e9a60',.7);}
  }
  function waterTower() {
    shadow(16);for(const x of [-10,10])line([[x,2],[x,-26]],'#6c8c86',2);line([[-10,-12],[10,-24]],'#6c8c86',1);line([[10,-12],[-10,-24]],'#6c8c86',1);
    rect(-14,-38,28,15,'#99bdaf',C.ink);ellipse(0,-38,14,6,'#c2d8bb',C.ink);ellipse(0,-23,14,5,'#81a99c',C.ink);
    line([[12,-22],[20,-18],[20,6]],'#789f9c',2);ellipse(20,6,5,2,'#8ebcbb');
  }
  function rice(seed) {shadow(7);ellipse(0,-4,7,8,'#d0b888',C.ink,.8);ellipse(0,-10,6,2.7,'#e3d2a2',C.ink,.6);line([[-6,-5],[6,-5]],'#a08d65',1);line([[-4,-11],[-4,1]],'#b5a071',.7);line([[3,-11],[3,1]],'#b5a071',.7);}
  function glyph(type,seed,lit,year,t) {
    if(type==='farm')farm(seed,t);else if(type==='factory')factory(seed,t);else if(type==='school')school(seed);else if(type==='water')waterTower();else if(type==='rice')rice(seed);else house(type,seed,lit,year);
  }
  function person(person,x,y,scale,t,selected=false) {
    const seed=hash(person.id),color=['#b45d46','#6a8da0','#d0a657','#76966f','#977f93'][Math.floor(seed*5)];
    ctx.save();ctx.translate(x,y);ctx.scale(scale,scale);shadow(3);const step=Math.sin(t*7+seed*9)*1.2;
    if(selected){ellipse(0,0,8,4,'#fff2bc',C.roof,1.2);line([[0,-15],[0,-21]],C.roof,1.5);ellipse(0,-23,2,2,C.roof);}
    line([[-1,-3],[-2+step,0]],'#52675a',1.6);line([[1,-3],[2-step,0]],'#52675a',1.6);
    poly([[-2,-8],[2,-8],[3,-3],[-3,-3]],color,null);line([[-2,-7],[-4+step*.5,-4]],'#d7b48e',1.4);line([[2,-7],[4-step*.5,-4]],'#d7b48e',1.4);
    ellipse(0,-10,2.3,2.5,'#dcb890');ellipse(-.3,-11.7,2.2,1.3,'#525646');if(person.age>=6&&person.age<15)rect(-3,-7,2.5,4,'#b05f48',C.ink,.4);ctx.restore();
  }
  function vehicle(type,x,y,s=1,heading=1,year=2000) {
    ctx.save();ctx.translate(x,y);ctx.scale(s*heading,s);shadow(type==='train'?25:15);
    if(type==='ship'){
      poly([[-24,-2],[25,-2],[15,8],[-13,8]],'#7a968e');poly([[-24,-2],[25,-2],[17,-7],[-15,-7]],C.cream);rect(-8,-17,17,10,C.cream,C.ink);rect(-6,-14,5,4,C.blue);rect(2,-14,5,4,C.blue);line([[0,-17],[0,-32]],C.ink,1);poly([[0,-31],[13,-19],[0,-19]],'#f0ead2',null);line([[-31,9],[-19,9]],'#f6faf0',2);
    } else {
      const train=type==='train',bus=type==='bus',w=train?46:bus?30:19;
      rect(-w/2,-14,w,12,train?(year<1950?'#685f4e':C.cream):bus?'#a0b3a0':C.roof,C.ink);
      rect(-w/2,-4,w,4,train?C.roof:'#6f8d7d');for(let i=0;i<(train?6:bus?4:2);i++)rect(-w/2+3+i*6,-11,4,5,'#a4c5bd');
      for(const x of [-w*.32,w*.32])ellipse(x,0,2.5,2.5,'#43584c');if(train)rect(-w/2+1,-16,w-2,2,'#839a8c');
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
    rect(0,0,width,height,C.sea);ctx.save();ctx.globalAlpha=.28;
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
    for(const place of sorted){const [x,y]=project(place.lng,place.lat);const selected=place.id===options.placeId;
      ctx.save();ctx.translate(x,y);ctx.scale(minScale,minScale);
      if(selected){ellipse(0,5,37,17,'#f7edba77',C.roof,1.5);}
      const farmCount=count(place.visual?.farm,4),houseCount=count(Math.ceil(number(place.visual?.houses)/2),8),factoryCount=count(place.visual?.factory,3);
      for(let i=0;i<farmCount;i++){ctx.save();ctx.translate(-20+i*13,12+i%2*5);ctx.scale(.29,.29);farm(hash(place.id+i),t);ctx.restore();}
      for(let i=0;i<houseCount;i++){ctx.save();ctx.translate((i%4-1.5)*11,(Math.floor(i/4)-.5)*9);ctx.scale(.38,.38);house('house',hash(place.id+i),i>=count(Math.ceil(number(place.visual?.vacancy)/2),8),snapshot.year);ctx.restore();}
      for(let i=0;i<factoryCount;i++){ctx.save();ctx.translate(20+i*14,-7);ctx.scale(.32,.32);factory(hash(place.id),t);ctx.restore();}
      if(count(place.visual?.school,1)){ctx.save();ctx.translate(-23,-8);ctx.scale(.3,.3);school(.2);ctx.restore();}
      for(let i=0;i<count(Math.ceil(number(place.visual?.students)/2),6);i++)person({id:`overview-student-${place.id}-${i}`,age:10},-25+i*4,8,.28,t,false);
      if(count(place.visual?.water,1)){ctx.save();ctx.translate(17,11);ctx.scale(.24,.24);waterTower();ctx.restore();}
      if(count(place.visual?.rice,1)){ctx.save();ctx.translate(0,17);ctx.scale(.23,.23);rice(.3);ctx.restore();}
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
      residents.forEach((p,i)=>{const angle=t*.25+hash(p.id)*Math.PI*2;person(p,x+Math.cos(angle)*22*minScale,y+15*minScale+Math.sin(angle)*7*minScale,.49*minScale,t,p.id===options.selectedPersonId);});
      if(count(place.visual?.bus,1)){vehicle('bus',x+Math.sin(t*.3+hash(place.id)*9)*25*minScale,y+23*minScale,.32*minScale,1,snapshot.year);}
    }

    const shipRoutes=[[[130,33.2],[136,32]],[[137,35],[142,39]],[[128.5,27.2],[131,30]]];
    shipRoutes.forEach(([a,b],i)=>{const p=(t*.012+i*.31)%1,[x,y]=route(project(...a),project(...b),p,12);vehicle('ship',x,y,.47*minScale);});
    if(places.length>3){const a=project(133,34.3),b=project(140.5,39),[x,y]=route(a,b,(t*.022)%1);vehicle('train',x,y,.34*minScale,1,snapshot.year);}
    for(const l of labels){line([[l.fromX,l.fromY],[l.x,l.y]],'#6a8b7477',.8);rect(l.x-l.w/2,l.y-9,l.w,18,l.selected?'#fff3d4':'#f6f3dff0');text(l.label,l.x,l.y,l.fontSize,l.selected?C.roof:C.ink);hits.push({type:'place',id:l.id,x:l.x,y:l.y,w:l.w,h:18});}
  }
  function placeScene(snapshot,t,options) {
    const place=(snapshot.world?.places||[]).find(p=>p.id===options.placeId)||(snapshot.world?.places||[])[0];if(!place){mapScene(snapshot,t,options);return;}
    const scale=clamp(Math.min((width-30)/800,(height-90)/540),.44,1.5),cx=width/2,cy=height*.52;
    backdrop(t,snapshot.year,false);ctx.save();ctx.translate(cx,cy);ctx.scale(scale,scale);
    // An irregular paper base replaces the removed tile/puzzle surface.
    const base=[[-363,-39],[-239,-174],[-60,-223],[147,-184],[337,-75],[382,66],[224,192],[-38,222],[-277,149]];
    ctx.save();ctx.translate(0,13);poly(base,'#8caa8d',null);ctx.restore();poly(base,'#c8d9aa','#8ba47c',1.4);
    ctx.beginPath();base.forEach(([x,y],i)=>i?ctx.lineTo(x,y):ctx.moveTo(x,y));ctx.closePath();ctx.save();ctx.clip();
    // Backdrop mountain slopes and a waterway are author scenery, not a survey.
    poly([[-370,-120],[-277,-257],[-171,-137],[-90,-231],[30,-145],[111,-218],[262,-120]],'#b1c596',null);
    poly([[-354,-111],[-275,-219],[-212,-130],[-165,-174],[-97,-112]],'#9eb889',null);
    ctx.beginPath();ctx.moveTo(160,-226);ctx.bezierCurveTo(66,-99,294,-46,210,51);ctx.bezierCurveTo(169,107,204,169,307,224);ctx.strokeStyle='#e3e6be';ctx.lineWidth=37;ctx.stroke();ctx.strokeStyle=C.water;ctx.lineWidth=26;ctx.stroke();
    for(let i=0;i<9;i++){const yy=-170+i*42,xx=192+Math.sin(i*1.7)*35;line([[xx-6+Math.sin(t+i)*2,yy],[xx+4+Math.sin(t+i)*2,yy]],'#d9ece0',1.2);}
    // Broad walkable ribbons leave enough space to see people and vehicles.
    line([[-338,25],[-194,-45],[-29,25],[151,-59],[329,22]],C.road,16);
    line([[-220,150],[-98,78],[-29,25],[42,-68],[117,-166]],C.road,12);
    line([[-338,25],[-194,-45],[-29,25],[151,-59],[329,22]],'#b8b99a',.8);
    // Road bridge and riverside fences.
    poly([[175,-46],[188,-53],[230,-26],[217,-19]],'#c6b18a');line([[175,-52],[219,-25]],'#7f9075',1.6);line([[189,-58],[231,-31]],'#7f9075',1.6);
    const trees=[[-308,-24],[-264,71],[-194,132],[-141,-119],[-72,-167],[69,-151],[289,53],[248,133],[-293,-107],[102,142],[-22,170],[312,-48]];
    trees.forEach(([x,y],i)=>tree(x,y,.65+(i%3)*.13,t,i));
    line([[-364,86],[-161,171],[66,147],[372,52]],'#7e9482',8);line([[-364,84],[-161,169],[66,145],[372,50]],'#e8e4cb',3);
    for(let i=0;i<33;i++){const x=-360+i*23,y=x< -160?86+(x+364)*.42:x<66?171-(x+161)*.115:147-(x-66)*.31;line([[x-3,y-5],[x+3,y+5]],'#6e8272',1);}
    const buildings=(snapshot.world?.buildings||[]).filter(b=>b.placeId===place.id);
    // Painter order combines people and houses, so walkers pass behind roofs.
    const objects=buildings.map(b=>({kind:'building',item:b,pos:local(number(b.x,.5),number(b.y,.5)),depth:number(b.x)+number(b.y)}));
    const people=(snapshot.world?.people||[]).filter(p=>p.placeId===place.id&&p.alive!==false);
    people.forEach(p=>{const from=p.from||p,to=p.to||p,phase=(t*.055+hash(p.id))%2,progress=phase<=1?phase:2-phase;const x=mix(number(from.x,.5),number(to.x,.5),progress),y=mix(number(from.y,.5),number(to.y,.5),progress);objects.push({kind:'person',item:p,pos:local(x,y),depth:x+y});});
    objects.sort((a,b)=>a.depth-b.depth);
    for(const o of objects){const [x,y]=o.pos;if(o.kind==='building'){ctx.save();ctx.translate(x,y);glyph(o.item.type,hash(o.item.id),o.item.lit!==false,snapshot.year,t);if(o.item.type==='shop'&&place.visual?.priceIndex!==null&&place.visual?.priceIndex!==undefined){rect(-28,-49,60,13,'#f8f2dd',null);text(`指数 ${Number(place.visual.priceIndex).toFixed(1)}`,2,-42.5,9,C.ink);}ctx.restore();}
      else {person(o.item,x,y,1,t,o.item.id===options.selectedPersonId);hits.push({type:'person',id:o.item.id,x:cx+x*scale,y:cy+(y-6)*scale,r:Math.max(12,9*scale)});}}
    // Anonymous school silhouettes illustrate the education signal. They are
    // separate from the seeded family biographies and are never selectable.
    const schoolBuilding=buildings.find(b=>b.type==='school'),schoolPos=schoolBuilding?local(schoolBuilding.x,schoolBuilding.y):[-90,48];
    for(let i=0;i<count(place.visual?.students,16);i++){
      const drift=Math.sin(t*.7+i)*6;person({id:`student-${place.id}-${i}`,age:10},schoolPos[0]-26+(i%8)*7+drift,schoolPos[1]+16+Math.floor(i/8)*8,.68,t,false);
    }
    const vehicles=(snapshot.world?.vehicles||[]).filter(v=>v.placeId===place.id);
    vehicles.slice(0,6).forEach(v=>{const p=(t*.05+hash(v.id))%1,x=-300+p*610,y=x<-194?25-(x+338)*.49:x<-29?-45+(x+194)*.42:x<151?25-(x+29)*.47:-59+(x-151)*.46;vehicle(v.type,x,y,.64,1,snapshot.year);});
    const tp=(t*.04)%1,tx=-360+tp*720,ty=tx<-161?86+(tx+364)*.42:tx<66?171-(tx+161)*.115:147-(tx-66)*.31;
    for(let i=0;i<3;i++)vehicle('train',tx-i*30,ty-i*9,.62,1,snapshot.year);
    vehicle('car',-85+Math.sin(t*.3)*75,0+Math.sin(t*.3)*31,.55,Math.cos(t*.3)>=0?1:-1,snapshot.year);
    ctx.restore();ctx.restore();
    text(place.name,cx,32,17,C.ink);if(width>470)text(`${place.region}の、ある町`,cx,55,12,'#6a8270');
  }
  function render(snapshot,elapsedSeconds=0,options={}) {
    if(destroyed||!snapshot)return;hits=[];ctx.setTransform(dpr,0,0,dpr,0,0);ctx.lineCap='round';ctx.lineJoin='round';ctx.globalAlpha=1;
    const view=options.view==='place'?'place':'japan',t=options.reducedMotion?0:Math.max(0,number(elapsedSeconds));
    if(view==='place')placeScene(snapshot,t,options);else mapScene(snapshot,t,options);
  }
  function location(event){const r=canvas.getBoundingClientRect();return [event.clientX-r.left,event.clientY-r.top];}
  function hit(event){const [x,y]=location(event);return [...hits].reverse().find(h=>h.w?Math.abs(h.x-x)<h.w/2&&Math.abs(h.y-y)<h.h/2:(h.x-x)**2+(h.y-y)**2<h.r**2);}
  const click=(event)=>{const h=hit(event);if(!h)return;if(h.type==='person')onPersonSelect(h.id);else {onPlaceSelect(h.id);onViewChange('place',h.id);}};
  const move=(event)=>{canvas.style.cursor=hit(event)?'pointer':'default';};
  canvas.addEventListener('click',click);canvas.addEventListener('pointermove',move);resize();
  return {render,resize,destroy(){destroyed=true;hits=[];canvas.removeEventListener('click',click);canvas.removeEventListener('pointermove',move);canvas.style.cursor='';}};
}
