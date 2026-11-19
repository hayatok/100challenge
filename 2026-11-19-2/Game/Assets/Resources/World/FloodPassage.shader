Shader "Evac/FloodPassage" {
SubShader {
 Tags { "Queue"="Transparent-12" "RenderType"="Transparent" }
 Pass {
  ZWrite Off Cull Off Blend SrcAlpha OneMinusSrcAlpha
  CGPROGRAM
  #pragma vertex vert
  #pragma fragment frag
  #include "UnityCG.cginc"
  float4 _Flood,_Boot;
  struct Surface { float4 clip:SV_POSITION;float3 world:TEXCOORD0;float2 uv:TEXCOORD1; };
  Surface vert(appdata_base a) {
      Surface o;o.clip=UnityObjectToClipPos(a.vertex);
      o.world=mul(unity_ObjectToWorld,a.vertex).xyz;o.uv=a.texcoord.xy;return o;
  }
  fixed4 frag(Surface s):SV_Target {
      float2 p=s.world.xz;
      float flow=_Flood.x*(.35+.52*_Flood.z);
      float crossWave=sin(3.13*p.y+.56*p.x-flow)*.39+sin(p.x*4.82+p.y*1.24+flow*.77)*.23;
      float3 v=normalize(_WorldSpaceCameraPos.xyz-s.world);
      float range=length(p-_Boot.xy);
      float boot=sin(range*17-_Flood.x*8)*exp2(-range*1.9)*_Boot.z;
      float3 n=normalize(float3(.026*cos(p.x*4.82+p.y*1.24+flow*.77),1,
                               .06*crossWave+boot*.14));
      float3 reflected=reflect(-v,n);
      float fresnel=.1+.73*pow(1-saturate(dot(n,v)),3);
      float3 water=lerp(float3(.045,.089,.093),float3(.16,.27,.31),saturate(reflected.y*1.7));
      float2 atLamp=p+reflected.xz*(4.48-s.world.y)/max(.09,reflected.y);
      float2 lamp=float2(atLamp.x<6.6?2.7:10.5,clamp(round((atLamp.y+36)/8),0.,9.)*8-36);
      float2 r=max(abs(atLamp-lamp)-float2(.16,1.27),0);
      float shine=exp2(-dot(r,r)*2.1);
      water+=float3(.72,.85,.81)*shine*(.27+fresnel*.65);
      float2 edge=min(s.uv,1-s.uv);
      float coast=saturate(min(edge.x*27,edge.y*70)+crossWave*.9-.12);
      float foam=1-smoothstep(.05,.57,coast);
      water+=float3(.20,.27,.25)*(foam*.64+saturate(boot)*.13);
      return fixed4(water,coast*(.32+_Flood.y*.23+fresnel*.23));
  }
  ENDCG
 }
}
}
