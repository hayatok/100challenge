Shader "Evac/StreetSurface" {
Properties {
 _SurfaceScan("Asphalt, plaster, steel and canvas",2D)="gray" {}
 _FieldFaces("Faces",2D)="white" {}
 _Materials("Material studies",2D)="gray" {}
 _ShopFronts("Market shopfronts",2D)="white" {}
 _DepotFronts("Rail and freight",2D)="white" {}
 _StreetLight("Baked light",2D)="white" {} _Evening("Evening",Range(0,1))=0 _Pose("Pose",Vector)=(0,0,0,0) _Form("Form",Vector)=(0,0,0,0) }
SubShader {
 Tags { "RenderType"="Opaque" }
 Pass {
 Cull Off
 CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #pragma target 3.0
 #pragma multi_compile_instancing
 #pragma instancing_options forcemaxcount:100
 #pragma multi_compile_local __ EVAC_MOBILE
 #include "UnityCG.cginc"
 UNITY_INSTANCING_BUFFER_START(Agents)
 UNITY_DEFINE_INSTANCED_PROP(float4,_Pose)
 UNITY_DEFINE_INSTANCED_PROP(float4,_Form)
 UNITY_DEFINE_INSTANCED_PROP(float4,_PlantLeft)
 UNITY_DEFINE_INSTANCED_PROP(float4,_PlantRight)
 UNITY_DEFINE_INSTANCED_PROP(float4,_AidPosition)
 UNITY_INSTANCING_BUFFER_END(Agents)
 float _Evening, _WetTime, _Station, _WorldDistrict;
 float4 _FieldSignal, _FieldSignalTint;
 sampler2D _SunOccluder;
 float _SunPacked;
 sampler2D _StreetLight, _Materials, _ShopFronts, _DepotFronts, _SurfaceScan, _FieldFaces;
 struct V { float4 pos:POSITION; fixed4 col:COLOR; float2 joint:TEXCOORD0; float2 panel:TEXCOORD1; float3 normal:NORMAL; UNITY_VERTEX_INPUT_INSTANCE_ID };
 struct F { float4 pos:SV_POSITION; float4 color:COLOR; float3 world:TEXCOORD0; float3 local:TEXCOORD1; float2 type:TEXCOORD2; float3 rest:TEXCOORD3; float3 print:TEXCOORD4; float3 normal:TEXCOORD5; };
 #include "ActorMotion.cginc"
 float3 deform(float3 p,float joint,float4 a,float4 f,float4 left,float4 right,float4 aid){
     if(f.x>0 && f.x<4)p=actorMotion(p,joint,a,f,left,right,aid);
     if(f.x==4)p=actorViewModel(p,joint,a,f);
     return p;
 }
 F vert(V v){
     UNITY_SETUP_INSTANCE_ID(v);
     float4 a=UNITY_ACCESS_INSTANCED_PROP(Agents,_Pose);
     float4 f=UNITY_ACCESS_INSTANCED_PROP(Agents,_Form);
     float4 left=UNITY_ACCESS_INSTANCED_PROP(Agents,_PlantLeft);
     float4 right=UNITY_ACCESS_INSTANCED_PROP(Agents,_PlantRight);
     float4 aid=UNITY_ACCESS_INSTANCED_PROP(Agents,_AidPosition);
     float3 p=deform(v.pos.xyz,v.joint.x,a,f,left,right,aid);
     F o; o.pos=UnityObjectToClipPos(float4(p,1));
     o.world=mul(unity_ObjectToWorld,float4(p,1)).xyz;
     o.normal=float3(0,0,0);
     if(f.x>0 && f.x<=4){
        float3 moved=deform(v.pos.xyz+v.normal*.01,v.joint.x,a,f,left,right,aid)-p;
        o.normal=mul((float3x3)unity_ObjectToWorld,moved);
     }
     o.local=p;o.rest=v.pos.xyz;o.print=float3(v.panel,v.joint.y);o.color=v.col;o.type=float2(f.x,f.z);return o;
 }
 float hash(float2 a){return frac(sin(dot(a,float2(19.13,37.73)))*1257.324);}
 float3 study(float tile,float2 uv){
     float2 cell=float2(fmod(tile,4),3-floor(tile*.25));
     float2 atlas=(cell+.015+frac(uv)*.97)*.25;
     return tex2Dgrad(_Materials,atlas,ddx(uv)*.2425,ddy(uv)*.2425).rgb;
 }
 float3 scan(float id,float2 uv){
     float2 cell=float2(fmod(id,2),1-floor(id*.5));
     return tex2Dgrad(_SurfaceScan,(cell+.008+frac(uv)*.984)*.5,ddx(uv)*.492,ddy(uv)*.492).rgb;
 }
 float sunshine(float2 uv,float receiver){
     float2 value=tex2D(_SunOccluder,uv).rg;
     float depth=lerp(value.r,dot(value,float2(256.0/257.0,1.0/257.0)),_SunPacked)*64;
     return smoothstep(depth-.16,depth+.015,receiver);
 }
 float nearestOfThree(float z,float a,float b,float c){
     float first=abs(z-a)<abs(z-b)?a:b;
     return abs(z-first)<abs(z-c)?first:c;
 }
 float3 practicalHead(float2 p){
     float side=p.x<0?-1:1;
     if(abs(p.y)>38){
         float row=nearestOfThree(abs(p.y),47,73,89)*sign(p.y);
         return float3(side*15.5,5.07,row);
     }
     if(_WorldDistrict<.5){
         float row=clamp(round(p.y/6.2)*6.2,-31,31);
         float3 arcade=float3(side*12.15,5.48,row);
         float3 signLight=float3(0,5.06,nearestOfThree(p.y,-23,6.8,28));
         return dot(arcade.xz-p,arcade.xz-p)<dot(signLight.xz-p,signLight.xz-p)?arcade:signLight;
     }
     if(_WorldDistrict<1.5){
         float3 pole=float3(side*15.1,5.59,nearestOfThree(p.y,-21,7,33));
         float3 dock=float3(clamp(round(p.x/5.8)*5.8,-5.8,5.8),6.19,-4.4);
         return dot(pole.xz-p,pole.xz-p)<dot(dock.xz-p,dock.xz-p)?pole:dock;
     }
     if(_WorldDistrict<2.5){
         float x=p.x<-9.1?-13:p.x<-1.3?-5.2:p.x<6.6?2.7:10.5;
         float row=clamp(round((p.y+36)/8)*8-36,-36,36);
         return float3(x,4.49,row);
     }
     float3 yard=float3(side*15.2,5.59,nearestOfThree(p.y,-28,-4,20));
     float index=clamp(round((p.y+15.7)/2.45),0,3);
     float3 shelter=float3(side*10.31,4.38,-15.7+index*2.45);
     return dot(yard.xz-p,yard.xz-p)<dot(shelter.xz-p,shelter.xz-p)?yard:shelter;
 }
 fixed4 frag(F i):SV_Target {
     float3 n=normalize(cross(ddy(i.world),ddx(i.world)));
     if(dot(i.normal,i.normal)>.000001)n=normalize(i.normal);
     float3 view=normalize(_WorldSpaceCameraPos.xyz-i.world);
     n*=dot(n,view)<0?-1:1;
     float sun=saturate(dot(n,normalize(float3(-.48,.88,-.36))));
     float hemi=.60+.13*n.y;
     float3 c=i.color.rgb*(hemi+float3(.53,.47,.35)*sun);
     if(i.print.z>11.5 && i.print.z<12.5){
         c=tex2D(_FieldFaces,i.print.xy).rgb*(.68+.32*sun);
     }else if(i.print.z>=9.5 && i.print.z<=11.5){
         float3 art=i.print.z<10.5?tex2D(_ShopFronts,i.print.xy).rgb:tex2D(_DepotFronts,i.print.xy).rgb;
         c=art*(.86+.14*sun);
     }else if(i.type.x<.5){
        float3 absN=abs(n);float2 uv=absN.y>.7?i.world.xz:(absN.x>absN.z?i.world.zy:i.world.xy);
        bool floorSurface=i.world.y<.17 && absN.y>.74;
        bool glass=abs(i.color.r-.188)<.025 && abs(i.color.b-.353)<.03;
        bool metal=abs(i.color.r-i.color.g)<.061 && i.color.g>.33 && i.color.g<.68;
        float tile=floorSurface?0:glass?3:metal?2:(i.color.r>.42 && i.color.g>.38?1:4);
        float2 repeatUV=floorSurface?uv*.31:glass?uv*float2(.46,.36):uv*.48;
        #ifdef EVAC_MOBILE
        float3 detail=.5;
        #else
        float3 detail=study(tile,repeatUV);
        #endif
        float strength=floorSurface?.15:glass?.27:metal?.18:.13;
        c*=1+(detail-.50)*strength*2;
        float surfaceId=floorSurface?(_Station>.5?1:0):metal?2:1;
        float3 sampled=scan(surfaceId,uv*(floorSurface?.49:.56));
        float3 mean=surfaceId==0?float3(.19,.18,.17):surfaceId==2?float3(.45,.44,.43):float3(.69,.66,.61);
        if(!glass)c*=lerp(1,clamp(sampled/mean,.53,1.55),floorSurface?.65:.55);
        // Recover the surface gradient from the photographed material in screen space.
        // The projected basis keeps the bump strength stable across UV seams and camera distance.
        float3 dx=ddx(i.world), dy=ddy(i.world);
        float3 tx=cross(dy,n), ty=cross(n,dx);
        float det=dot(dx,tx);
        float height=dot(sampled,float3(.24,.61,.15));
        float3 grad=(tx*ddx(height)+ty*ddy(height))*sign(det)/max(abs(det),.000001);
        float3 bumped=normalize(n-grad*(floorSurface?.052:metal?.026:.046));
        float3 key=normalize(float3(-.48,.88,-.36));
        c*=1+(dot(bumped,key)-dot(n,key))*.62;
        float rough=metal?.36:.79;
        float3 finish=bumped;
        if(glass){
           finish=n;
           rough=.14;
           float3 ray=reflect(-view,n);
           float horizon=smoothstep(-.12,.46,ray.y);
           float fresnel=pow(1-saturate(dot(view,n)),4);
           float3 environment=lerp(float3(.11,.15,.16),float3(.50,.64,.68),horizon);
           c=lerp(c*.60,environment,.32+.59*fresnel);
        }
        if(floorSurface){
           float2 street=i.world.xz;
           float pools=.45+.19*sin(street.x*.53+sin(street.y*.41))+.18*sin(street.y*.36+street.x*.51)+.10*sin(street.y*1.87+street.x)+.05*sin(street.x*3.6);
           float wet=smoothstep(.53,.73,pools+height*.09);
           rough=lerp(.80,.12,wet);
           finish=normalize(lerp(bumped,n,wet*.92));
           float3 ray=reflect(-view,finish);
           float wallX=ray.x<0?-19.4:19.4;
           float wallT=(wallX-street.x)/(abs(ray.x)>.001?ray.x:.001);
           float facadeY=ray.y*wallT;
           float facadeZ=street.y+ray.z*wallT;
           float roof=6.6+1.15*sin(floor(facadeZ/8.8)*2.14);
           float silhouette=(1-smoothstep(roof-.35,roof+.35,facadeY))*step(.01,wallT)*(1-smoothstep(35,42,abs(facadeZ)));
           float3 environment=lerp(float3(.48,.58,.62),float3(.17,.21,.22),silhouette);
           float grazing=pow(1-saturate(dot(view,finish)),3);
           c=lerp(c*(1-.28*wet),environment,wet*(.05+.50*grazing)*(1-.77*_Station));
        }
        float nh=saturate(dot(finish,normalize(key+view)));
        float exponent=lerp(96,5,rough*rough);
        c+=pow(nh,exponent)*(.018+.16*(1-rough))*float3(1,.89,.72);
        if(i.world.y>.08)c*=lerp(.80,1,saturate(i.world.y*.70));
     }else{
        float3 q=i.rest,orient=abs(cross(ddx(q),ddy(q)));
        float2 tex=orient.y>max(orient.z,orient.x)?q.xz:orient.x>orient.z?q.zy:q.xy;
        float skin=saturate((i.color.r-i.color.b-.10)*7);
        if(i.type.x<4 && i.print.z>5.5 && i.print.z<7.5)
            skin=step(6.5,i.print.z);
        float dark=saturate((.32-i.color.g)*9);
        float tile=i.type.x==4?(dark>.45?12:6):(skin>.5?14:dark>.65?6:5);
        #ifdef EVAC_MOBILE
        float3 detail=.5;
        #else
        float3 detail=study(tile,tex*(i.type.x==4?8.3:4.8));
        #endif
        c*=1+(detail-.5)*.26;
        float3 cloth=scan(3,tex*(i.type.x==4?2.6:1.4));
        #ifdef EVAC_MOBILE
        float3 metalStudy=.46;
        #else
        float3 metalStudy=scan(2,tex*1.8);
        #endif
        float textile=1-saturate(skin+dark*.77);
        c*=lerp(1,clamp(cloth/float3(.31,.30,.23),.70,1.32),textile*.69);
        c*=lerp(1,clamp(metalStudy/.46,.76,1.30),dark*.47);
        c+=pow(saturate(dot(reflect(-normalize(float3(-.48,.88,-.36)),n),view)),18)*(.027+dark*.09);
        if(i.type.x<4)c*=.91+.09*saturate(i.local.y);
     }
     if(_Station>.5 && i.type.x!=4){
         float2 p=i.world.xz;
         float under=(1-smoothstep(15,19,abs(p.x)))*(1-smoothstep(38,42,abs(p.y)));
         float track=abs(frac((p.x+13)/7.9+.5)-.5)*7.9;
         float span=abs(frac(p.y/8+.5)-.5)*8;
         float pool=exp2(-.10*(track*track+span*span));
         float hall=under*(1-smoothstep(4.8,6.2,i.world.y));
         c*=lerp(float3(1,1,1),float3(.67,.71,.75)+pool*float3(.30,.25,.17),hall);
         // Daylight entering through the ridge monitor falls across columns, actors and terrazzo.
         float rise=max(0,5.60-i.world.y);
         float2 roofHit=p+float2(-.48,-.36)*rise/.88;
         float opening=(1-smoothstep(2.9,3.75,abs(roofHit.x)));
         float beamDistance=abs(frac(roofHit.y/8+.5)-.5)*8;
         float daylight=opening*smoothstep(.14,.54,beamDistance)*hall;
         c*=1+daylight*float3(.31,.24,.14)*(.22+.78*sun);
         if(i.type.x<.5 && n.y>.78 && i.world.y<.12 && abs(p.y)<40){
             float2 tile=frac(p/float2(.69,1.14));
             float2 dist=min(tile,1-tile);
             float seam=1-smoothstep(.003,.037,min(dist.x,dist.y));
             c*=float3(.81,.85,.89)*(1-seam*.17);
             c*=lerp(float3(1,1,1),float3(.78,.83,.91),_Evening);
             float3 ray=reflect(-view,float3(0,1,0));
             float2 ceil=p+ray.xz*((4.48-i.world.y)/max(.065,ray.y));
             float dx=abs(frac((ceil.x+13)/7.9+.50)-.5)*7.9;
             float dz=abs(frac(ceil.y/8+.5)-.5)*8;
             float mask=(1-smoothstep(14.3,17.5,abs(ceil.x)))*(1-smoothstep(36,43,abs(ceil.y)));
             float shimmer=.76+.20*sin(p.x*23+p.y*16)+.04*sin(p.y*39);
             float reflections=exp2(-dx*dx*4)*exp2(-max(0,dz-1.37)*max(0,dz-1.37)*1.2);
             float grazing=.26+.74*pow(1-saturate(view.y),1.7);
             c+=float3(.53,.42,.25)*reflections*grazing*mask*shimmer*under;
             float safety=exp2(-abs(p.x-12.5)*1.05);
             c+=float3(.12,.069,.012)*safety*grazing;
         }
     }
     if(i.print.z>8.5 && i.print.z<9.5){
         // Translucent wire glass transmits light on the underside of the raised station canopy.
         float facing=abs(n.y);
         float soil=scan(1,i.world.xz*.21+i.world.zy*.13).g;
         c=lerp(float3(.54,.65,.64),float3(.72,.78,.72),facing)*(.86+.18*soil);
         c*=lerp(float3(1,1,1),float3(.74,.74,.78),_Evening);
     }
     if(i.print.z>14.5)c=float3(1,.955,.80);
     if(i.print.z>13.5 && i.print.z<14.5){
         float ripple=sin(i.world.z*2.3+i.world.x*.78+_WetTime*.66)+sin(i.world.z*3.7-i.world.x*2.3-_WetTime*.83);
         c=lerp(float3(.19,.32,.31),float3(.41,.53,.51),.43+ripple*.08+pow(1-saturate(view.y),3)*.19);
     }
     if(i.print.z>12.5 && i.print.z<13.5){
         float3 reflected=reflect(-view,n);
         float fresnel=pow(saturate(1-dot(view,n)),3);
         float sky=smoothstep(-.39,.85,reflected.y);
         float strip=pow(saturate(dot(reflected,normalize(float3(-.46,.79,-.41)))),8);
         float2 uv=i.rest.zy*4;
         float grain=scan(2,uv).r;
         c=c*float3(.45,.51,.59)+sky*float3(.031,.042,.060)+fresnel*float3(.07,.095,.12);
         c+=strip*(.05+grain*.20);
     }
     if(i.type.x!=4){
         float baked=tex2D(_StreetLight,(i.world.xz+float2(24,40))/float2(48,80)).r;
         float influence=i.type.x==0?saturate((.54-i.world.y)*2.2):.55;
         float insideBake=1-smoothstep(38,40,abs(i.world.z));
         c*=lerp(1,baked,influence*.78*insideBake);
     }
     float warmLamp=saturate((i.color.r-.82)*8)*saturate((i.color.g-.72)*7)*saturate((i.color.r-i.color.b-.12)*9);
     float2 solarUV=(i.world.xz+float2(.48,.36)*i.world.y/.88)/float2(80,224)+.5;
     float night=smoothstep(.12,.91,_Evening);
     if(night<.97 && all(solarUV>0) && all(solarUV<1)){
         float h=i.world.y+.075+.09*(1-abs(n.y));
         float2 stepUV=float2(1.0/896,1.0/1792);
         float lit=sunshine(solarUV+stepUV*float2(-.57,-.24),h);
         lit+=sunshine(solarUV+stepUV*float2(.48,.53),h);
         #ifdef EVAC_MOBILE
         lit*=.5;
         #else
         lit+=sunshine(solarUV+stepUV*float2(-.48,.63),h);
         lit+=sunshine(solarUV+stepUV*float2(.63,-.67),h);
         lit*=.25;
         #endif
         float shade=(1-lit)*.85*(1-.50*night)*(1-.65*warmLamp);
         c*=lerp(float3(1,1,1),float3(.60,.69,.79),shade);
     }
     if(night>.001){
         float3 lamp=practicalHead(i.world.xz);
         float3 delta=lamp-i.world;
         float spread=dot(delta.xz,delta.xz);
         float diffuse=saturate(dot(n,delta)*rsqrt(max(.15,dot(delta,delta))));
         float pool=exp2(-spread*.019)*(.39+.61*diffuse)*step(-.13,delta.y);
         float people=step(.5,i.type.x)*(1-step(3.5,i.type.x));
         float3 ambient=lerp(float3(.38,.50,.72),float3(.62,.73,.88),people);
         if(i.type.x==4)ambient=lerp(ambient,float3(.65,.73,.86),.9);
         float3 tint=_WorldDistrict>1.5&&_WorldDistrict<2.5?float3(.79,.88,.92):float3(1,.79,.53);
         float3 scene=c*ambient + pool*tint*(c*.49+.103);
         bool belowRoof=i.world.y<.19 && n.y>.74;
         if(i.type.x<.5 && belowRoof){
             float3 mirrored=reflect(-view,n);
             float rayHeight=max(.075,mirrored.y);
             float2 probe=i.world.xz+mirrored.xz*((lamp.y-i.world.y)/rayHeight);
             float3 reflectionLamp=practicalHead(probe);
             float rayDistance=(reflectionLamp.y-i.world.y)/rayHeight;
             float2 ghost=(i.world.xz+mirrored.xz*rayDistance-reflectionLamp.xz)*float2(.92,.51);
             float streak=exp2(-dot(ghost,ghost)*.69)*smoothstep(.01,.16,mirrored.y);
             float2 road=i.world.xz;
             float wetField=.50+.18*sin(road.x*.61+sin(road.y*.41))
                                 +.18*sin(road.y*.71-road.x*.37)+.08*sin(road.x*2.19+road.y);
             float damp=smoothstep(.35,.72,wetField);
             scene+=tint*streak*(.076+.37*damp);
             scene+=tint*pool*damp*(.024+.042*pow(1-saturate(dot(view,n)),3));
         }
         if(i.print.z>=9.5 && i.print.z<=11.5){
             float warmTexture=saturate((c.r-c.b)*3.1)*smoothstep(.22,.59,c.r);
             scene+=warmTexture*(c*.63+float3(.18,.093,.030));
         }
         float fixture=max(step(14.5,i.print.z),warmLamp*smoothstep(2.7,5.1,i.world.y));
         scene=lerp(scene,float3(1,.86,.61),fixture*.91);
         c=lerp(c,scene,night);
     }
     if(_FieldSignal.w>0){
        float3 lightVector=_FieldSignal.xyz-i.world;
        float lens=dot(lightVector,lightVector);
        float reach=saturate(1-lens/58);
        float diffuse=saturate(dot(n,lightVector*rsqrt(max(.02,lens))));
        c+=_FieldSignalTint.rgb*(_FieldSignal.w*reach*reach/(1+.32*lens))*(.16+diffuse*.74);
     }
     if(i.type.x!=4){
        float fog=smoothstep(28,115,distance(i.world,_WorldSpaceCameraPos))*.52;
        c=lerp(c,lerp(float3(.59,.65,.64),float3(.23,.31,.43),night),fog);
     }
     return fixed4(c,1);
 }
 ENDCG
 }
}
}
