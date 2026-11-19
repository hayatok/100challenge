Shader "Evac/RoomWing" {
 Properties {
     _SurfaceScan("Moss surface scans", 2D)="gray"{}
     _RoomLight("Baked interior visibility", 2D)="white"{}
     _Wing("District", Float)=0
     _GateSignal("Gate unlocked", Float)=0
 }
 SubShader {
 Tags { "RenderType"="Opaque" }
 Cull Off
 Pass {
 CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #pragma target 3.0
 #include "UnityCG.cginc"

 sampler2D _SurfaceScan,_RoomLight;
 float _Wing,_GateSignal;
 struct Input {
     float4 p:POSITION;
     float3 normal:NORMAL;
     fixed4 color:COLOR;
     float2 style:TEXCOORD0;
 };
 struct Surface {
     float4 p:SV_POSITION;
     float3 world:TEXCOORD0;
     float3 normal:TEXCOORD1;
     float style:TEXCOORD2;
     fixed3 color:COLOR;
 };
 Surface vert(Input v) {
     Surface o;
     o.p=UnityObjectToClipPos(v.p);
     o.world=mul(unity_ObjectToWorld,v.p).xyz;
     o.normal=UnityObjectToWorldNormal(v.normal);
     o.style=v.style.y;
     o.color=v.color.rgb;
     return o;
 }
 float3 scan(float tile,float2 uv) {
     float2 cell=float2(fmod(tile,2),1-floor(tile*.5));
     return tex2Dgrad(_SurfaceScan,(cell+.008+frac(uv)*.984)*.5,ddx(uv)*.492,ddy(uv)*.492).rgb;
 }
 fixed4 frag(Surface i):SV_Target {
     if(i.style>14.5 || (i.style>5.5 && i.style<6.5))return fixed4(i.color,1);
     if(i.style>9.5 && i.style<10.5)
         return fixed4(lerp(float3(.94,.28,.12),float3(.32,.91,.55),_GateSignal),1);

     float3 p=i.world;
     float3 view=normalize(_WorldSpaceCameraPos.xyz-p);
     float3 n=normalize(i.normal);
     n*=dot(n,view)<0?-1:1;
     float3 axis=abs(n);
     float2 u=axis.y>.62?p.xz:axis.x>axis.z?p.zy:p.xy;
     bool floorTile=i.style>.5 && i.style<1.5;
     bool metal=i.style>1.5 && i.style<2.5;
     bool cloth=i.style>2.5 && i.style<3.5;
     bool wood=i.style>3.5 && i.style<4.5;
     bool glass=i.style>4.5 && i.style<5.5;
     float scanTile=cloth?3:metal?2:1;
     float2 q=u*(floorTile?.84:cloth?2.3:.70);
     if(wood)q*=float2(.25,1.9);
     float3 grain=scan(scanTile,q);
     float3 average=cloth?float3(.31,.30,.23):metal?float3(.45,.44,.43):float3(.69,.66,.61);
     float3 c=i.color*lerp(1,clamp(grain/average,.54,1.47),cloth?.79:.52);
     float2 lightUV=(p.xz+n.xz*.14-float2(-16,89))/float2(32,64);
     float4 lighting=tex2D(_RoomLight,lightUV);
     float2 visible=lerp(lighting.rg,lighting.ba,smoothstep(.18,1.55,p.y));
     visible=lerp(visible,float2(1,1),smoothstep(1.55,3.05,p.y)*.84);
     float occlusion=lerp(.46,1.,visible.y);
     float phase=frac((p.z-94.68)/5.6+.5)-.5;
     float xLight=min(abs(p.x),abs(abs(p.x)-10.4));
     float lamp=exp2(-phase*phase*10.-xLight*xLight*.045);
     float entry=1-smoothstep(93,101,p.z);
     float ceiling=_Wing<.5?3.24:_Wing<1.5?5.06:_Wing<2.5?5.30:4.89;
     float3 source=float3(clamp(round(p.x/10.4),-1.,1.)*10.4,ceiling,
                          94.68+clamp(round((p.z-94.68)/5.6),0.,9.)*5.6);
     float3 toLamp=normalize(source-p+float3(0,.001,0));
     float incidence=saturate(dot(n,toLamp));
     float3 warm=_Wing<.5?float3(.94,1.01,.98):_Wing<1.5?float3(1.22,.93,.62):
                 _Wing<2.5?float3(1.05,1.03,.81):float3(1.11,.96,.76);
     float3 lightingColor=float3(.38,.46,.49)*occlusion
           +warm*(.27+.62*lamp)*(.50+.50*incidence)*visible.x
           +entry*float3(.085,.11,.15);
     c*=lightingColor;
     float bumpHeight=dot(grain,float3(.26,.57,.17));
     float3 dx=ddx(p),dy=ddy(p);
     float3 tx=cross(dy,n),ty=cross(n,dx);
     float det=dot(dx,tx);
     float3 grad=(tx*ddx(bumpHeight)+ty*ddy(bumpHeight))*sign(det)/max(abs(det),.00001);
     float3 microNormal=normalize(n-clamp(grad,-4.,4.)*(metal?.027:cloth?.048:.041));
     c*=1+(dot(microNormal,toLamp)-dot(n,toLamp))*.47;
     float grazing=pow(1-saturate(dot(view,n)),3.);
     if(floorTile && axis.y>.68) {
         float2 tileWeight=_Wing<.5?float2(1.4,1.4):_Wing<1.5?float2(.33,.29):
                           _Wing<2.5?float2(.91,.88):float2(.36,.33);
         float2 edge=abs(frac(u*tileWeight+.5)-.5);
         float seam=1-smoothstep(.006,.021,min(edge.x,edge.y));
         c*=1-seam*.17;
         // Reflect the authored ceiling strips into polished tile and sealed concrete.
         float3 bounce=reflect(-view,normalize(lerp(n,microNormal,.36)));
         float2 reflectedAt=p.xz+bounce.xz*(ceiling-p.y)/max(.12,bounce.y);
         float2 nearest=float2(clamp(round(reflectedAt.x/10.4),-1.,1.)*10.4,
                  94.68+clamp(round((reflectedAt.y-94.68)/5.6),0.,9.)*5.6);
         float2 offset=max(abs(reflectedAt-nearest)-float2(_Wing<.5?.90:1.51,.13),0.);
         float roughness=_Wing<.5?.62:_Wing<1.5?1.1:.84;
         float reflection=exp2(-dot(offset,offset)/roughness);
         c+=warm*visible.x*(.05+.25*grazing)*reflection*(1-seam*.65);
         c+=warm*visible.x*lamp*grazing*.052;
     }
     if(glass) {
         float bars=.80+.20*sin(u.x*2.2+u.y*.7);
         c=lerp(c*.75,float3(.27,.40,.43)*bars,.39+.40*grazing);
         c+=lamp*.044;
     }
     if(metal)c+=warm*visible.x*pow(saturate(dot(reflect(-toLamp,microNormal),view)),23)*.25;
     if(i.style>6.5 && i.style<7.5)c=lerp(c,i.color,.37);
     if(i.style>7.5 && i.style<8.5) {
         float2 grid=abs(frac(p.xz*float2(.84,.57)+.5)-.5);
         float seam=1-smoothstep(.004,.018,min(grid.x,grid.y));
         c*=.89-seam*(_Wing<.5?.20:.10);
     }
     return fixed4(c,1);
 }
 ENDCG
 }
 }
}
