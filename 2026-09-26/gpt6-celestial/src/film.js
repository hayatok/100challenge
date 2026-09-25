/* CELESTIAL / CUT 02. Every animation is evaluated from absolute time. */
(() => {
'use strict';
const W=1920,H=1080,TAU=Math.PI*2,C={ink:'#111115',paper:'#f4f0e7',blue:'#3d48ef',orange:'#ff7345',silver:'#cbd0e1'};
const clamp=(v,a=0,b=1)=>Math.max(a,Math.min(b,v)),mix=(a,b,p)=>a+(b-a)*p,seg=(t,a,b)=>clamp((t-a)/(b-a));
const ease=v=>{v=clamp(v);return v*v*(3-2*v)},out=v=>1-(1-clamp(v))**4;
const expo=v=>{v=clamp(v);return v===0?0:v===1?1:v<.5?2**(20*v-10)/2:(2-2**(-20*v+10))/2};
const spring=v=>v<=0?0:1-Math.exp(-8*v)*Math.cos(10*v),hash=i=>{const v=Math.sin(i*127.1+311.7)*43758.5453;return v-Math.floor(v)};
const stars=Array.from({length:880},(_,i)=>({a:hash(i+1)*TAU,r:60+hash(i+41)*1500,z:hash(i+811),x:hash(i+11)*W,y:hash(i+401)*H}));
let g,clouds;
const colorMix=(a,b,p)=>{const aa=parseInt(a.slice(1),16),bb=parseInt(b.slice(1),16);return '#'+[16,8,0].map(n=>Math.round(mix((aa>>n)&255,(bb>>n)&255,p)).toString(16).padStart(2,'0')).join('')};
const font=(size,weight=700)=>`${weight} ${size}px Celestial, sans-serif`;
function bg(c){g.fillStyle=c;g.fillRect(0,0,W,H)}
function line(x,y,xx,yy,c=C.paper,w=1,a=1){g.save();g.globalAlpha*=a;g.strokeStyle=c;g.lineWidth=w;g.beginPath();g.moveTo(x,y);g.lineTo(xx,yy);g.stroke();g.restore()}
function disk(x,y,r,c){if(r<=0)return;g.fillStyle=c;g.beginPath();g.arc(x,y,r,0,TAU);g.fill()}
function ring(x,y,r,c,w=1,a=1){if(r<=0)return;g.save();g.globalAlpha*=a;g.strokeStyle=c;g.lineWidth=w;g.beginPath();g.arc(x,y,r,0,TAU);g.stroke();g.restore()}
function txt(s,x,y,size,c=C.paper,weight=700,align='center',stroke=false){g.save();g.font=font(size,weight);g.textAlign=align;g.textBaseline='middle';g.fillStyle=c;g.strokeStyle=c;g.lineWidth=1.4;if(stroke)g.strokeText(s,x,y);else g.fillText(s,x,y);g.restore()}
function width(s,size){g.font=font(size);return g.measureText(s).width}
function fit(s,y,maxWidth,size,c=C.paper){g.save();g.translate(960,y);g.scale(Math.min(1,maxWidth/width(s,size)),1);txt(s,0,0,size,c);g.restore()}
function small(s,x,y,c=C.paper,align='left'){txt(s,x,y,21,c,500,align)}
function star(x,y,r,rotation=0,c=C.paper){g.save();g.translate(x,y);g.rotate(rotation);g.beginPath();for(let i=0;i<8;i++){const a=i*Math.PI/4,rr=i%2?r*.13:r;g.lineTo(Math.cos(a)*rr,Math.sin(a)*rr)}g.closePath();g.fillStyle=c;g.fill();g.restore()}
function meta(t,act,c=C.paper){small('CELESTIAL   /   GPT–6',70,63,c);small(act,1850,63,c,'right');small('THREE BODIES. ONE UNIVERSE.',70,1018,c);small(`${Math.min(48,Math.floor(t*2)+1).toString().padStart(2,'0')} / 48`,1850,1018,c,'right');line(70,978,1850,978,c,1,.25);line(70,978,70+1780*t/24,978,c,3,.85)}
function field(t,a=.5){g.save();for(let i=0;i<stars.length;i+=3){const s=stars[i];g.globalAlpha=a*(.3+.7*s.z);disk((s.x+t*8*s.z)%W,s.y,1+s.z*1.8,C.paper)}g.restore()}
function makeCloud(word,size,maxWidth){const c=document.createElement('canvas');c.width=W;c.height=H;const k=c.getContext('2d',{willReadFrequently:true});k.font=font(size);k.textAlign='center';k.textBaseline='middle';k.translate(960,535);k.scale(Math.min(1,maxWidth/k.measureText(word).width),1);k.fillText(word,0,0);const data=k.getImageData(0,0,W,H).data,points=[];for(let y=160;y<900;y+=12)for(let x=70;x<1850;x+=12)if(data[(y*W+x)*4+3]>150)points.push({x,y});return points}
function ensureClouds(){if(!clouds)clouds={astra:makeCloud('ASTRA',490,1780),six:makeCloud('6',740,650)}}
// Delayed letter springs, anisotropic stretch, and velocity-dependent outline trails.
function kinetic(word,y,size,maxWidth,q,c,settledLast=false){const total=[...word].reduce((n,ch)=>n+width(ch,size),0),scale=Math.min(1,maxWidth/total);let x=-total/2;g.save();g.translate(960,y);g.scale(scale,1);for(let i=0;i<word.length;i++){const w=width(word[i],size),p=settledLast&&i===word.length-1?1:spring(Math.max(0,q-i*.07)*1.7),d=1-p;g.save();g.translate(x+w/2,d*(i%2?-450:450));g.rotate(d*(i%2?.16:-.16));g.scale(1+Math.abs(d)*.75,Math.max(.05,1-d*.72));if(Math.abs(d)>.015)for(let j=3;j>0;j--){g.save();g.globalAlpha=.15*(1-j/5);txt(word[i],0,d*j*40,size,c,700,'center',true);g.restore()}txt(word[i],0,0,size,c);g.restore();x+=w}g.restore()}
function orbit(t,c,r=340,alpha=1,cx=960,cy=540){g.save();g.strokeStyle=c;g.lineWidth=1.7;g.globalAlpha=alpha;for(let n=0;n<3;n++){g.beginPath();for(let i=0;i<=160;i++){const a=i/160*TAU,tilt=n*Math.PI/3+t*.22;let x=Math.cos(a)*r,y=Math.sin(a)*r;const z=y*Math.sin(tilt);y*=Math.cos(tilt);const xx=x*Math.cos(t*.18)-z*Math.sin(t*.18),zz=x*Math.sin(t*.18)+z*Math.cos(t*.18),p=1100/(1100+zz),px=cx+xx*p,py=cy+y*p;i?g.lineTo(px,py):g.moveTo(px,py)}g.stroke()}g.restore()}
function moon(x,y,r,phase,c=C.paper,b=C.ink){if(r<=0)return;disk(x,y,r,c);g.save();g.beginPath();g.arc(x,y,r,0,TAU);g.clip();disk(x+r*phase,y-r*.09,r*.99,b);g.restore()}
function origin(t){bg(C.paper);const p=expo(seg(t,0,.7));if(t<1){g.save();g.translate(960,520);g.scale(1,Math.max(.015,p));txt('THINK',0,0,490,C.ink);g.restore();small('A NEW CONSTELLATION',960,832,C.ink,'center')}
else if(t<2){bg(C.blue);const q=t-1;kinetic('BEYOND.',540,430,1750,q+.12,C.paper);line(100,835,100+1720*out(seg(q,.1,.7)),835,C.paper,5)}
else{bg(C.ink);const q=t-2;field(t,.25);const assemble=expo(seg(q,.12,1.6)),pts=clouds.astra;g.fillStyle=C.paper;for(let i=0;i<pts.length;i++){const pt=pts[i],s=stars[i%stars.length],a=s.a+q*(1-assemble)*.35,r=s.r*(1-assemble),x=mix(960+Math.cos(a)*r*1.4,pt.x,assemble),y=mix(540+Math.sin(a)*r,pt.y,assemble),z=mix(1+s.z*3,2.6,assemble);g.globalAlpha=.5+.5*assemble;g.fillRect(x,y,z,z)}g.globalAlpha=1;small('01     /     FROM THE STARS',960,825,C.paper,'center');if(q>1.6){g.save();g.globalAlpha=seg(q,1.6,1.9);fit('ASTRA',535,1780,490);g.restore()}}meta(t,'00   /   IGNITION',t<1?C.ink:C.paper)}
function astra(t){const q=t-4;bg(C.blue);if(q<2){g.save();g.globalAlpha=.22;txt('ASTRA',960+(q-.5)*140,135,420,C.paper,700,'center',true);txt('ASTRA',960-(q-.5)*140,970,420,C.paper,700,'center',true);g.restore();const push=expo(seg(q,1.45,2));g.save();g.translate(960,540);g.scale(1+push*4,1+push*4);g.translate(-960,-540);kinetic('ASTRA',535,490,1780,q+.6,C.paper);g.restore();if(q<1.5){star(116,825,26,q*.3);small('EXPAND YOUR HORIZON',171,826);small('01 / ASTRA',1780,826,C.paper,'right')}}
else{bg(C.ink);const travel=q-2,exit=expo(seg(travel,1.4,2));for(let i=0;i<stars.length;i++){const s=stars[i],z=.12+((s.z+travel*.5)%1)*2.4,p=1/z,a=s.a+travel*.11,x=960+Math.cos(a)*s.r*p,y=540+Math.sin(a)*s.r*p,stretch=1+.11/z;line(x,y,960+(x-960)*stretch,540+(y-540)*stretch,i%11===0?C.orange:C.paper,1+(1/z)*.8,clamp(1-z/2.6))}for(let i=0;i<8;i++){const p=((i/8+travel*.32)%1);ring(960,540,80+1600*p*p,C.blue,2,.6*(1-p))}disk(960,540,14+exit*180,C.orange);star(960,540,26+exit*170,travel,C.orange);if(exit>.2){g.save();g.globalAlpha=exit;ring(960,540,230+exit*900,C.orange,35);g.restore()}}meta(t,'01   /   ASTRA')}
function sunRays(t,r,outer,c,alpha=1,count=96){for(let i=0;i<count;i++){const a=i/count*TAU+t*.16,rr=r+Math.sin(i*.8+t*3)*8;line(960+Math.cos(a)*rr,540+Math.sin(a)*rr,960+Math.cos(a)*outer,540+Math.sin(a)*outer,c,i%4?1.5:4,alpha)}}
function sol(t){const q=t-8;bg(C.orange);if(q<2){const enter=spring(q*2);sunRays(t,245,1100,C.ink,.17);g.save();g.translate(960,540);g.rotate(q*.12);for(let i=0;i<3;i++)ring(0,0,300+i*80,C.ink,1,.22);g.restore();const d=1-enter;g.save();g.translate(960,540);g.scale(1,Math.max(.1,enter));txt('S',-510-d*450,0,580,C.ink);txt('L',490+d*450,0,580,C.ink);disk(0,0,207,C.ink);disk(0,0,131,C.orange);g.restore();sunRays(t,224,250+12*Math.exp(-(q*2%1)*8),C.ink,1,64);small('02   /   SOL',110,840,C.ink);small('SET IDEAS IN MOTION',1810,840,C.ink,'right')}
else if(q<4){const u=q-2,zoom=expo(seg(u,1.1,2));g.save();g.translate(960,540);g.scale(1+zoom*2.7,1+zoom*2.7);g.translate(-960,-540);for(let k=0;k<7;k++){const r=155+k*48+22*Math.sin(u*3-k*.65);ring(960,540,r,k%2?C.ink:C.paper,k%2?17:5,.9)}disk(960,540,140,C.ink);star(960,540,90,u*.35,C.paper);sunRays(t,465,720,C.ink,.9,48);g.restore();small('ENERGY',110,185,C.ink);small('IN MOTION.',1810,895,C.ink,'right')}
else{const u=q-4,blue=ease(seg(u,1.5,2)),back=colorMix(C.ink,C.blue,blue),sun=colorMix(C.orange,C.paper,blue);bg(back);const r=340;disk(960,540,r,sun);for(let j=0;j<5;j++)ring(960,540,r+10+j*15,sun,2,(1-blue)*.35/(j+1));const p=ease(seg(u,0,2));disk(mix(1740,960-340*.58,p),mix(320,540-340*.09,p),r*.99,back);g.save();g.globalAlpha=1-blue;small('EVERY LIGHT',960,145,C.paper,'center');small('FINDS A NEW PHASE.',960,905,C.paper,'center');g.restore()}meta(t,q<4?'02   /   SOL':'02 → 03   /   ECLIPSE',q<4?C.ink:C.paper)}
function luna(t){const q=t-14;bg(C.blue);if(q<2){const p=expo(seg(q,0,.7));g.save();g.globalAlpha=1-p;moon(960,540,340,-.58,C.paper,C.blue);g.restore();const letters='LUNA',total=width(letters,525),scale=1750/total;g.save();g.translate(960,535);g.scale(scale,1);for(let band=0;band<12;band++){const a=spring(Math.max(0,q-.18-band*.026)*2.5);g.save();g.beginPath();g.rect(-1100,-300+band*50,2200,51);g.clip();g.translate((1-a)*(band%2?650:-650),0);g.globalAlpha=clamp(a);txt(letters,0,0,525);g.restore()}g.restore();for(let i=0;i<9;i++)moon(290+i*167,850,30,Math.sin(q*1.2+i*.5)*1.5,C.paper,C.blue);small('03   /   LUNA',110,186);small('FIND YOUR PHASE',1810,186,C.paper,'right')}
else{const u=q-2;bg(C.ink);field(t,.3);g.save();g.globalAlpha=.12;fit('LUNA',560,2200,720,C.paper);g.restore();orbit(u+2,C.silver,360+25*Math.sin(u*2),.75);const p=expo(seg(u,1.4,2));moon(960,540,180*(1-p),-.6-.5*Math.sin(u),C.paper,C.ink);for(let i=0;i<3;i++){const a=u*1.8+i*TAU/3,x=960+Math.cos(a)*420,y=540+Math.sin(a)*170;if(i===0)star(x,y,27,u);if(i===1)disk(x,y,24,C.orange);if(i===2)moon(x,y,28,-.8)}small('LIGHT. IN A DIFFERENT ORBIT.',960,877,C.paper,'center')}meta(t,'03   /   LUNA')}
function triptych(t){const q=t-18;bg(C.ink);const names=['ASTRA','SOL','LUNA'],colors=[C.blue,C.orange,C.paper];for(let i=0;i<3;i++){const p=out(seg(q,i*.13,i*.13+.65)),x=i*640;g.save();g.beginPath();g.rect(x,0,640,H);g.clip();g.translate(0,(1-p)*(i%2?-H:H));g.fillStyle=colors[i];g.fillRect(x,0,640,H);const ink=i===0?C.paper:C.ink,cx=x+320;small(`0${i+1}`,x+58,161,ink);g.save();g.translate(cx,720);g.scale(Math.min(1,535/width(names[i],150)),1);txt(names[i],0,0,150,ink);g.restore();if(i===0){star(cx,435,165,q*.45,ink);ring(cx,435,200,ink,1,.4)}if(i===1){disk(cx,435,120,ink);for(let j=0;j<32;j++){const a=j/32*TAU+q*.2;line(cx+Math.cos(a)*144,435+Math.sin(a)*144,cx+Math.cos(a)*180,435+Math.sin(a)*180,ink,4)}}if(i===2)moon(cx,435,164,-.85,ink,colors[i]);small(['THE STARS','THE SUN','THE MOON'][i],cx,837,ink,'center');g.restore()}if(q>1.5){const p=expo(seg(q,1.5,2));g.save();g.translate(960,540);g.rotate(p*Math.PI*.5);g.fillStyle=C.ink;g.fillRect(-1500,-1000*p,3000,2000*p);g.restore()}}
function finale(t){
  const q=t-20;bg(C.ink);
  if(q<2){
    const p=expo(seg(q,.15,1.45)),pull=expo(seg(q,1.45,2)),pts=clouds.six;
    const total=[...'GPT–6'].reduce((n,ch)=>n+width(ch,470),0),scale=Math.min(1,1715/total),targetX=960+(total/2-width('6',470)/2)*scale;
    const cx=mix(960,targetX,pull),cy=mix(535,505,pull),size=mix(740,470,pull);
    g.save();g.translate(cx,cy);g.scale(mix(1,scale,pull)*size/740,size/740);g.translate(-960,-535);
    for(let i=0;i<pts.length;i++){const pt=pts[i],a=i/pts.length*TAU*5+q*.6,r=330+80*Math.sin(i*.1),x=960+Math.cos(a)*r,y=540+Math.sin(a)*r*.7;g.globalAlpha=1-pull;g.fillStyle=i%8===0?C.orange:C.paper;g.fillRect(mix(x,pt.x,p),mix(y,pt.y,p),3,3)}
    if(p>.75){g.globalAlpha=seg(p,.75,1);txt('6',960,535,740)}g.restore();
    small('THREE BODIES. ONE UNIVERSE.',960,910,C.paper,'center');
  }else{
    const u=q-2;orbit(u+4,C.silver,415,.1);
    kinetic('GPT–6',505,470,1715,u+.12,C.paper,true);
    const p=out(seg(u,.15,.7));line(105,775,105+1710*p,775,C.paper,2,.8);
    const names=['ASTRA','SOL','LUNA'];for(let i=0;i<3;i++){g.save();g.globalAlpha=out(seg(u,.3+i*.1,.8+i*.1));small(names[i],380+i*580,865,i===1?C.orange:C.paper,'center');g.restore()}
    small('A NEW CONSTELLATION.',960,190,C.paper,'center');
  }
  meta(t,'04   /   ALIGNMENT');
}
function draw(canvas,time){g=canvas.getContext('2d',{alpha:false});ensureClouds();const t=clamp(Number.isFinite(time)?time:0,0,24);g.setTransform(canvas.width/W,0,0,canvas.height/H,0,0);g.globalAlpha=1;g.globalCompositeOperation='source-over';if(t<4)origin(t);else if(t<8)astra(t);else if(t<14)sol(t);else if(t<18)luna(t);else if(t<20)triptych(t);else finale(t);g.setTransform(1,0,0,1,0,0)}
window.CelestialFilm={draw,duration:24,width:W,height:H,chapters:[0,4,8,14,20]};
})();
