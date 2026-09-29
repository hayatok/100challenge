import * as T from 'three';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';

/** Original meter-scale shop dressing, including locally painted fictional labels. */
export function buildStoreInterior(shop:T.Group, ownGeo:<G extends T.BufferGeometry>(g:G)=>G,
  ownMat:<M extends T.Material>(m:M)=>M, ownTex:<X extends T.Texture>(t:X)=>X):void {
  let seed=9147;
  const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)|0;return(seed>>>0)/4294967296;};
  const sourceGeometries:T.BufferGeometry[]=[];
  const geo=<G extends T.BufferGeometry>(g:G)=>{sourceGeometries.push(g);return g;};
  function texture(draw:(c:CanvasRenderingContext2D)=>void){
    const canvas=document.createElement('canvas');canvas.width=canvas.height=512;
    draw(canvas.getContext('2d')!);const map=ownTex(new T.CanvasTexture(canvas));
    map.colorSpace=T.SRGBColorSpace;map.anisotropy=8;return map;
  }
  function aged(base:string,streaks=true){return texture(c=>{
    c.fillStyle=base;c.fillRect(0,0,512,512);
    for(let i=0;i<12000;i++){c.fillStyle=`rgba(${random()>.5?'255,242,214':'17,22,19'},${random()*.19})`;c.fillRect(random()*512,random()*512,1+random()*3,1+random()*2);}
    for(let i=0;i<65;i++){c.fillStyle=`rgba(45,35,20,${random()*.18})`;c.fillRect(random()*512,random()*512,random()*7+1,streaks?random()*180:random()*4);}
    for(let i=0;i<18;i++){const x=random()*512,y=random()*512,g=c.createRadialGradient(x,y,0,x,y,45);g.addColorStop(0,'rgba(50,42,30,.2)');g.addColorStop(1,'rgba(50,42,30,0)');c.fillStyle=g;c.fillRect(x-45,y-45,90,90);}
  });}
  const plaster=aged('#999686'),steelMap=aged('#a3a8a0'),enamelMap=aged('#bdbba4'),woodMap=aged('#65533a');
  const mat=(color:number,roughness=.7,metalness=0,map?:T.Texture)=>ownMat(new T.MeshStandardMaterial({color,roughness,metalness,map:map??null}));
  const wall=mat(0xc3c4b5,.95,0,plaster),ceiling=mat(0x676d64,.91,0,plaster),steel=mat(0xa1aaa3,.38,.65,steelMap),dark=mat(0x202b2a,.7,.28),rust=mat(0x594336,.84,.25),wood=mat(0xc9b191,.9,0,woodMap),enamel=mat(0xe0ddc5,.58,.12,enamelMap);
  const lamp=ownMat(new T.MeshStandardMaterial({color:0xeaf6e4,emissive:0xc9e9dd,emissiveIntensity:2.1,roughness:.26}));
  const warm=ownMat(new T.MeshStandardMaterial({color:0xffdc92,emissive:0xffb451,emissiveIntensity:2.3}));
  const cube=geo(new T.BoxGeometry(1,1,1)),cylinder=geo(new T.CylinderGeometry(1,1,1,16)),plane=geo(new T.PlaneGeometry(1,1));
  const batches=new Map<T.Material,T.BufferGeometry[]>();
  function put(g:T.BufferGeometry,m:T.Material,at:[number,number,number],scale:[number,number,number]=[1,1,1],rot:[number,number,number]=[0,0,0]){
    const matrix=new T.Matrix4().compose(new T.Vector3(...at),new T.Quaternion().setFromEuler(new T.Euler(...rot)),new T.Vector3(...scale));
    const transformed=g.clone().applyMatrix4(matrix);const list=batches.get(m)??[];list.push(transformed);batches.set(m,list);
  }
  const box=(x:number,y:number,z:number,w:number,h:number,d:number,m:T.Material,rot:[number,number,number]=[0,0,0])=>put(cube,m,[x,y,z],[w,h,d],rot);
  const round=(x:number,y:number,z:number,r:number,h:number,m:T.Material,rot:[number,number,number]=[0,0,0])=>put(cylinder,m,[x,y,z],[r,h,r],rot);
  const printMaterials=new Map<T.Texture,T.Material>();
  function panel(map:T.Texture,x:number,y:number,z:number,w:number,h:number,yaw=0){
    let m=printMaterials.get(map);if(!m){m=ownMat(new T.MeshStandardMaterial({map,roughness:.91,side:T.DoubleSide}));printMaterials.set(map,m);}
    put(plane,m,[x,y,z],[w,h,1],[0,yaw,0]);
  }
  function label(top:string,main:string,bottom:string,accent:string,price=false){return texture(c=>{
    c.fillStyle=price?'#e9d7a1':'#eee8d1';c.fillRect(0,0,512,512);
    c.fillStyle=accent;c.fillRect(0,0,512,price?8:68);c.fillRect(0,480,512,32);
    c.textAlign='center';c.textBaseline='middle';c.fillStyle=price?'#30382b':'#f2e8cd';c.font='bold 29px serif';c.fillText(top,256,35,price?470:290);
    c.fillStyle=accent;c.font=`bold ${price?155:100}px serif`;c.fillText(main,256,price?205:185,price?460:275);
    if(!price){c.strokeStyle=accent;c.lineWidth=3;c.beginPath();c.ellipse(256,350,80,68,0,0,Math.PI*2);c.stroke();for(let i=0;i<7;i++){c.save();c.translate(256,350);c.rotate(i*.9);c.beginPath();c.ellipse(20,0,30,11,-.5,0,Math.PI*2);c.fill();c.restore();}}
    c.font=`${price?'bold 116':'23'}px serif`;c.fillText(bottom,256,price?390:454,price?470:290);
    c.globalAlpha=.18;for(let i=0;i<250;i++){c.fillStyle='#4a442e';c.fillRect(random()*512,random()*512,random()*5,1);}
  });}
  const tile=texture(c=>{
    c.fillStyle='#666959';c.fillRect(0,0,512,512);
    for(let y=0;y<4;y++)for(let x=0;x<4;x++){const v=Math.floor(154+random()*23);c.fillStyle=`rgb(${v+12},${v+12},${v})`;c.fillRect(x*128+2,y*128+2,124,124);c.strokeStyle='rgba(237,226,194,.25)';c.strokeRect(x*128+4,y*128+4,120,120);}
    for(let i=0;i<8000;i++){c.fillStyle=`rgba(25,31,25,${random()*.12})`;c.fillRect(random()*512,random()*512,1+random()*3,1+random()*2);}
    for(let i=0;i<40;i++){c.strokeStyle='rgba(38,35,27,.25)';c.beginPath();const x=random()*512,y=random()*512;c.moveTo(x,y);c.lineTo(x+random()*40,y+random()*14);c.stroke();}
  });tile.wrapS=tile.wrapT=T.RepeatWrapping;tile.repeat.set(3,7);
  box(0,-.04,-6.2,6.2,.06,14,mat(0xccc9af,.31,.16,tile));
  for(const x of [-3.1,3.1]){box(x,2,-6.4,.18,4,14,wall);box(x*.976,.15,-6.4,.06,.3,14,dark);}
  box(0,4,-6.4,6.2,.15,14,ceiling);
  // Suspension rods, end clips and round paired tubes make lights credible at close range.
  for(const z of [-1.1,-4.6,-8.2,-11.5]){
    box(0,3.86,z,6.1,.13,.1,dark);box(-.25,3.7,z,1.65,.09,.38,steel);
    for(const zz of [-.12,.12])round(-.25,3.64,z+zz,.029,1.45,lamp,[0,0,Math.PI/2]);
    for(const x of [-.91,.41]){box(x,3.64,z,.06,.1,.35,dark);round(x,3.82,z,.014,.3,steel);}
  }
  for(const x of [-2.74,-2.48,2.57]){
    round(x,3.82,-6.5,.027,13,steel,[Math.PI/2,0,0]);
    for(const z of [-1,-3.2,-5.5,-7.8,-10.5])box(x,3.8,z,.1,.11,.028,rust);
  }
  // Merchandise has family-specific silhouettes, wrap labels and small lids/seams.
  const packMaps=[label('やまさか茶園','緑茶','香りを、そのまま。','#36583b'),label('毎日の食卓','トマト','完熟トマト / 400g','#a3422c'),label('国産大豆','しょうゆ','天然醸造 / 500ml','#473d2a'),label('朝の牧場','牛乳','生乳100% / 1000ml','#365d7b'),label('ふるさとの味','さば','水煮 / 190g','#314e67'),label('地元のお米','こしひかり','精米 / 2kg','#66643d')];
  const packMats=packMaps.map(map=>mat(0xffffff,.67,.05,map));
  const glassMats=[mat(0x54762c,.2,.2),mat(0x3d2b1a,.23,.22)];
  const capMats=[mat(0xc8c8a9,.42,.35),mat(0x752d20,.5,.22)];
  const bottle=geo(new T.LatheGeometry([[.001,0],[.09,0],[.102,.018],[.103,.29],[.098,.32],[.055,.385],[.042,.4],[.042,.48],[.001,.48]].map(([x,y])=>new T.Vector2(x,y)),16));
  const can=geo(new T.CylinderGeometry(.098,.098,.22,16)),wrapBottle=geo(new T.CylinderGeometry(.104,.104,.205,16,1,true)),wrapCan=geo(new T.CylinderGeometry(.099,.099,.185,16,1,true));
  const bag=geo(new T.SphereGeometry(1,10,8));
  const priceMaps=['108','138','228','198','298'].map(p=>label('本日のお買い得',p,'円','#93442c',true));
  for(let bay=0;bay<4;bay++){
    const z=-2.0-bay*2.55;box(-2.96,1.65,z,.06,3.12,2.45,ceiling);
    for(const edge of [-1.2,1.2]){
      box(-2.02,1.68,z+edge,.065,3.28,.065,steel);box(-2.96,1.68,z+edge,.065,3.28,.065,steel);
      for(let hole=0;hole<22;hole++)box(-1.981,.22+hole*.135,z+edge,.002,.037,.018,dark);
    }
    for(let level=0;level<5;level++){
      const y=.35+level*.62;box(-2.51,y,z,1.03,.045,2.48,steel);box(-1.987,y-.04,z,.045,.1,2.5,steel);
      for(let item=0;item<9;item++){
        if((item+bay*7+level*3)%19===0)continue;
        const zz=z-1.08+item*.25+(random()-.5)*.025,family=(level+bay)%6;
        for(let row=0;row<(item%4===0?2:1);row++){
          const x=-2.18-row*.25;
          if(family===0||family===2){
            put(bottle,glassMats[family===0?0:1],[x,y+.024,zz]);put(wrapBottle,packMats[family],[x,y+.205,zz],[1,1,1],[0,-Math.PI/2,0]);
            round(x,y+.506,zz,.046,.041,capMats[family===0?0:1]);
            for(const h of [.489,.5,.511])round(x,y+h,zz,.048,.003,capMats[family===0?0:1]);
          }else if(family===1||family===4){
            for(let stack=0;stack<(item%3===0?2:1);stack++){
              const yy=y+.136+stack*.226;put(can,steel,[x,yy,zz]);put(wrapCan,packMats[family],[x,yy,zz],[1,1,1],[0,-Math.PI/2,0]);
              round(x,yy+.108,zz,.102,.014,steel);round(x,yy+.111,zz,.083,.006,steel);
            }
          }else if(family===3){box(x,y+.235,zz,.20,.42,.20,packMats[3],[0,(random()-.5)*.12,0]);box(x,y+.474,zz,.2,.07,.12,capMats[0],[0,0,.12]);}
          else {put(bag,packMats[5],[x,y+.25,zz],[.12,.225,.115],[0,Math.PI/2,.05]);box(x,y+.471,zz,.20,.018,.028,enamel);}
        }
      }
      for(let p=0;p<2;p++)panel(priceMaps[(bay+level+p)%5],-1.953,y-.13,z-.73+p*1.15,.26,.24,Math.PI/2);
    }
  }
  // Cases contain actual baskets and leafy vegetables beneath sloping glazing.
  const leafMats=[mat(0x375932,.83),mat(0x536c3b,.8),mat(0x7d8954,.78)],leafVein=mat(0x929a66,.84);
  const leaf=geo(new T.SphereGeometry(1,9,6));
  const glassTex=texture(c=>{c.clearRect(0,0,512,512);for(let i=0;i<850;i++){c.fillStyle=`rgba(202,224,213,${.06+random()*.17})`;c.beginPath();c.ellipse(random()*512,random()*512,random()*1.6+.4,random()*3+.6,0,0,Math.PI*2);c.fill();}});
  const glass=ownMat(new T.MeshPhysicalMaterial({color:0x859d94,map:glassTex,transparent:true,opacity:.25,roughness:.19,metalness:.28,depthWrite:false,side:T.DoubleSide}));
  for(let bay=0;bay<3;bay++){
    const z=-2.1-bay*2.9;box(2.55,.53,z,1.04,1.03,2.82,enamel);box(1.995,.35,z,.025,.34,2.6,dark);
    for(let slot=0;slot<24;slot++)box(1.975,.36,z-1.25+slot*.11,.016,.28,.023,steel);
    box(2.25,.08,z,.7,.14,2.75,dark);box(2.55,1.08,z,1.07,.12,2.8,dark);round(1.94,1.01,z,.047,2.86,steel,[Math.PI/2,0,0]);
    for(let tray=0;tray<5;tray++){
      const zz=z-1.08+tray*.53;box(2.49,1.15,zz,.81,.045,.49,dark);box(2.49,1.25,zz-.255,.82,.22,.018,steel);
      for(let veg=0;veg<3;veg++){
        const xx=2.21+(veg%2)*.37,zzz=zz+(veg===2?.12:-.07);
        if((tray+bay)%3===0){for(let l=0;l<6;l++){const angle=l*1.08;put(leaf,leafMats[l%3],[xx+Math.sin(angle)*.065,1.29+l*.018,zzz+Math.cos(angle)*.07],[.17,.07,.14],[l*.16,angle,.25]);}}
        else {for(let l=0;l<4;l++){const off=(l-1.5)*.04;put(leaf,leafMats[l%3],[xx,1.33+l*.009,zzz+off],[.24,.045,.085],[.2,off,.25]);box(xx-.12,1.27,zzz+off,.26,.018,.015,leafVein,[0,0,.28]);}}
      }
      panel(priceMaps[tray],1.94,1.20,zz,.25,.22,-Math.PI/2);
    }
    box(2.38,1.67,z,1.13,.014,2.81,glass,[0,0,.56]);round(2.86,1.97,z,.032,2.83,steel,[Math.PI/2,0,0]);round(2.88,1.91,z,.017,2.71,lamp,[Math.PI/2,0,0]);
    for(const edge of [-1.39,1.39])box(2.38,1.67,z+edge,1.15,.038,.038,steel,[0,0,.56]);
  }
  for(let bay=0;bay<4;bay++){
    const z=-1.9-bay*2.25;box(3.001,2.8,z,.018,1.55,2.17,dark);box(2.983,2.8,z,.008,1.48,2.10,glass);
    for(const h of [2.03,3.56])box(2.96,h,z,.13,.07,2.22,steel);
    for(const zz of [-1.07,1.07])box(2.96,2.8,z+zz,.1,1.57,.055,steel);
  }
  panel(label('旬を、おいしく。','地元の野菜','今日も食卓へ','#42573c'),2.87,2.66,-6,.65,.92,-Math.PI/2);
  // A narrow, warm doorway leads into a deep room instead of a luminous flat panel.
  for(const side of [-1,1])box(side*2.26,1.96,-11.3,1.82,3.92,.2,wall);
  box(0,3.45,-11.3,2.7,.98,.2,wall);
  for(const x of [-1.37,1.37])box(x,1.48,-11.16,.12,2.96,.18,wood);
  box(0,2.99,-11.16,2.86,.12,.18,wood);
  panel(label('やまさか商店','いつもの食卓に','やさしい、まいにち。','#344639'),0,3.49,-11.17,3.2,.64);
  box(0,-.01,-13.3,3.8,.06,4,wood);box(0,1.65,-15.2,3.8,3.3,.12,wood);
  for(const x of [-1.85,1.85])box(x,1.65,-13.2,.12,3.3,4,wall);
  box(0,3.31,-13.2,3.8,.12,4,ceiling);round(-.28,3.08,-12.7,.012,.45,dark);
  put(geo(new T.ConeGeometry(.22,.16,16,1,true)),dark,[-.28,2.83,-12.7]);put(geo(new T.SphereGeometry(.063,12,8)),warm,[-.28,2.73,-12.7]);
  const cardboard=mat(0xd3bb85,.94,0,aged('#a58b5f',false)),tape=mat(0x9a865e,.7),stamp=label('やまさか商店','食品','取扱注意','#66583b');
  for(let i=0;i<13;i++){
    const x=(i%2?1:-1)*(1.2+random()*.24),y=.25+Math.floor(i/4)*.5,z=-12.0-Math.floor(i/2)%3*.78;
    box(x,y,z,.6,.48,.59,cardboard,[0,(random()-.5)*.12,0]);box(x,y+.245,z,.085,.009,.6,tape);panel(stamp,x,y,z+.302,.34,.19);
  }
  const note=label('納品予定','入荷','午前五時','#554b33');for(let i=0;i<3;i++)panel(note,-.9+i*.35,1.8+i*.22,-15.11,.22,.32);
  round(.05,.63,-14.0,.28,.08,wood);for(const x of [-.18,.18])for(const z of [-.18,.18])round(x,.30,-14.0+z,.025,.6,dark);
  // A side shelf and the open door leaf show the depth of the work room.
  for(const y of [.6,1.35,2.1]){box(1.37,y,-13.5,.75,.06,2.3,wood);for(let j=0;j<4;j++)box(1.38,y+.2,-14.3+j*.46,.43,.34,.39,cardboard);}
  box(1.28,1.45,-12.1,.08,2.78,1.7,wood,[0,-.22,0]);
  panel(label('毎日の食卓に','新鮮な食材','朝五時、入荷。','#3f4e3b'),-2.05,2.05,-11.17,.6,.85);
  // Open-sided baskets cast perforated silhouettes, unlike the previous solid crate.
  const crate=mat(0x294c3f,.78);
  function basket(x:number,y:number,z:number,ry=0){
    const rotation=new T.Euler(0,ry,0),p=new T.Vector3();
    const part=(xx:number,yy:number,zz:number,w:number,h:number,d:number)=>{p.set(xx,yy,zz).applyEuler(rotation).add(new T.Vector3(x,y,z));box(p.x,p.y,p.z,w,h,d,crate,[0,ry,0]);};
    part(0,.025,0,.72,.05,.48);
    for(const zz of [-.25,.25]){for(const yy of [.13,.26,.39])part(0,yy,zz,.76,.038,.035);for(let k=0;k<8;k++)part(-.34+k*.097,.22,zz,.022,.36,.035);}
    for(const xx of [-.375,.375]){for(const yy of [.13,.26,.39])part(xx,yy,0,.035,.038,.5);for(let k=0;k<5;k++)part(xx,.22,-.2+k*.1,.035,.36,.022);}
  }
  basket(1.68,0,-9.7,.18);basket(1.68,.43,-9.7,.18);basket(-1.72,0,-10.6,-.09);
  for(let i=0;i<9;i++)put(can,packMats[i%2?1:4],[(i%2?1:-1)*(1.25+random()*.45),.103,-2.4-random()*7.7],[1,1,1],[Math.PI/2,random()*3,0]);
  // Static geometry is batched by material, keeping a dense shop affordable to draw.
  for(const [material,parts] of batches){
    const geometry=ownGeo(mergeGeometries(parts,false)!);parts.forEach(p=>p.dispose());
    const mesh=new T.Mesh(geometry,material);mesh.name='Store / authored surfaces';mesh.castShadow=!material.transparent;mesh.receiveShadow=true;shop.add(mesh);
  }
  sourceGeometries.forEach(g=>g.dispose());
}
