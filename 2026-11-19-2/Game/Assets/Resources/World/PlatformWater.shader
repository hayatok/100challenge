Shader "Evac/PlatformWater" {
 SubShader { Tags { "Queue"="Transparent-15" "RenderType"="Transparent" }
 Pass { Blend SrcAlpha OneMinusSrcAlpha ZWrite Off Cull Off
 CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "UnityCG.cginc"
 float _RippleClock;
 struct V {float4 p:POSITION;};
 struct F {float4 p:SV_POSITION;float3 world:TEXCOORD0;float2 local:TEXCOORD1;};
 F vert(V v) {F o;o.p=UnityObjectToClipPos(v.p);o.world=mul(unity_ObjectToWorld,v.p).xyz;o.local=v.p.xz;return o;}
 fixed4 frag(F i):SV_Target{
     float2 uv=i.world.xz;
     float rip=.5+.22*sin(uv.x*11.7+uv.y*5.2+_RippleClock*1.6)+.16*sin(uv.y*13.1-uv.x*2.2-_RippleClock*1.4);
     float reflection=.5+.5*sin(uv.x*1.76+sin(uv.y*.58)+rip*.25);
     float3 c=lerp(float3(.14,.23,.23),float3(.43,.52,.52),reflection*.66+rip*.19);
     float3 view=normalize(_WorldSpaceCameraPos.xyz-i.world);
     float fresnel=pow(1-saturate(view.y),2);
     c+=fresnel*float3(.15,.17,.16)+pow(saturate(rip),8)*.10;
     float edge=saturate((1.06-length(i.local))*6);
     return fixed4(c,.28*edge+.28*fresnel*edge);
 }
 ENDCG
 } }
}
