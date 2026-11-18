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
 #pragma multi_compile_local __ EVAC_MOBILE
 #include "UnityCG.cginc"
 UNITY_INSTANCING_BUFFER_START(Agents)
 UNITY_DEFINE_INSTANCED_PROP(float4,_Pose)
 UNITY_DEFINE_INSTANCED_PROP(float4,_Form)
 UNITY_INSTANCING_BUFFER_END(Agents)
 float _Evening, _WetTime, _Station;
 sampler2D _StreetLight, _Materials, _ShopFronts, _DepotFronts, _SurfaceScan, _FieldFaces;
 struct V { float4 pos:POSITION; fixed4 col:COLOR; float2 joint:TEXCOORD0; float2 panel:TEXCOORD1; float3 normal:NORMAL; UNITY_VERTEX_INPUT_INSTANCE_ID };
 struct F { float4 pos:SV_POSITION; float4 color:COLOR; float3 world:TEXCOORD0; float3 local:TEXCOORD1; float2 type:TEXCOORD2; float3 rest:TEXCOORD3; float3 print:TEXCOORD4; float3 normal:TEXCOORD5; };
 #include "ActorMotion.cginc"
 float3 deform(float3 p,float joint,float4 a,float4 f){
     if(f.x>0 && f.x<4)p=actorMotion(p,joint,a,f);
     if(f.x==4){
        float change=sin(saturate(a.x)*3.141593);
        if(joint==11)p+=float3(.048,-.077,-.19)*change;
        if(joint==14)p.y-=.089*change;
     }
     return p;
 }
 F vert(V v){
     UNITY_SETUP_INSTANCE_ID(v);
     float4 a=UNITY_ACCESS_INSTANCED_PROP(Agents,_Pose);
     float4 f=UNITY_ACCESS_INSTANCED_PROP(Agents,_Form);
     float3 p=deform(v.pos.xyz,v.joint.x,a,f);
     F o; o.pos=UnityObjectToClipPos(float4(p,1));
     o.world=mul(unity_ObjectToWorld,float4(p,1)).xyz;
     o.normal=f.x==4?mul((float3x3)unity_ObjectToWorld,v.normal):float3(0,0,0);
     if(f.x>0 && f.x<4){
        float3 moved=deform(v.pos.xyz+v.normal*.01,v.joint.x,a,f)-p;
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
        if(glass){
           float sky=pow(saturate(1-dot(view,n)),2);
           c+=float3(.05,.09,.11)*(detail.r+.28)+sky*float3(.19,.22,.22);
           c+=.027*sin(uv.x*5+uv.y*.58);
        }
        if(floorSurface){
           float2 street=i.world.xz;
           float pools=.45+.19*sin(street.x*.53+sin(street.y*.41))+.18*sin(street.y*.36+street.x*.51)+.10*sin(street.y*1.87+street.x)+.05*sin(street.x*3.6);
           float wet=smoothstep(.52,.75,pools+detail.r*.07);
           c*=1-wet*.22;
           c+=wet*(.035+.12*pow(1-saturate(dot(view,n)),2))*float3(.83,.93,1);
        }
        float grit=hash(floor(uv*14));
        float grain=(grit-.5)*.026*saturate(1-distance(i.world,_WorldSpaceCameraPos)*.012);
        float wear=.014*sin(dot(uv,float2(.31,.83)))+.011*sin(uv.x*4.1+uv.y*.6);
        c+=grain+wear;
        if(i.world.y>.08)c*=lerp(.82,1,saturate(i.world.y*.7));
        c+=pow(saturate(dot(reflect(-normalize(float3(-.48,.88,-.36)),n),view)),20)*.065;
     }else{
        float3 q=i.rest,orient=abs(cross(ddx(q),ddy(q)));
        float2 tex=orient.y>max(orient.z,orient.x)?q.xz:orient.x>orient.z?q.zy:q.xy;
        float skin=saturate((i.color.r-i.color.b-.10)*7);
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
         float under=1-smoothstep(15,19,abs(p.x));
         float track=abs(frac((p.x+13)/7.9+.5)-.5)*7.9;
         float span=abs(frac(p.y/8+.5)-.5)*8;
         float pool=exp2(-.10*(track*track+span*span));
         float hall=under*(1-smoothstep(4.8,6.2,i.world.y));
         c*=lerp(float3(1,1,1),float3(.67,.71,.75)+pool*float3(.30,.25,.17),hall);
         if(i.type.x<.5 && n.y>.78 && i.world.y<.12){
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
         c*=lerp(1,baked,influence*.68);
     }
     float warmLamp=saturate((i.color.r-.82)*8)*saturate((i.color.g-.72)*7)*saturate((i.color.r-i.color.b-.12)*9);
     c=lerp(c,c*float3(.89,.91,.96)+warmLamp*float3(.13,.095,.03),_Evening);
     if(i.type.x!=4){
        float fog=smoothstep(28,115,distance(i.world,_WorldSpaceCameraPos))*.52;
        c=lerp(c,float3(.59,.65,.64),fog);
     }
     return fixed4(c,1);
 }
 ENDCG
 }
}
}
