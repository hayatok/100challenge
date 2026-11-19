Shader "Evac/CoastalSky" {
 Properties { _Evening("Evening", Range(0,1))=0 }
 SubShader {
 Tags { "Queue"="Background" "RenderType"="Background" "PreviewType"="Skybox" }
 Cull Off ZWrite Off
 Pass {
 CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "UnityCG.cginc"
 float _Evening;
 struct V { float4 vertex:POSITION; };
 struct F { float4 vertex:SV_POSITION; float3 ray:TEXCOORD0; };
 F vert(V v){ F o;o.vertex=UnityObjectToClipPos(v.vertex);o.ray=v.vertex.xyz;return o; }
 float hash(float2 p){return frac(sin(dot(p,float2(31.37,71.54)))*1367.2);}
 float cloud(float2 p){
     float2 cell=floor(p),u=frac(p); u=u*u*(3-2*u);
     return lerp(lerp(hash(cell),hash(cell+float2(1,0)),u.x),
                 lerp(hash(cell+float2(0,1)),hash(cell+1),u.x),u.y);
 }
 fixed4 frag(F f):SV_Target {
     float3 ray=normalize(f.ray);
     float height=saturate(ray.y);
     float3 horizon=lerp(float3(.66,.70,.66),float3(.58,.56,.50),_Evening);
     float3 top=lerp(float3(.39,.54,.59),float3(.30,.40,.46),_Evening);
     float3 rgb=lerp(horizon,top,sqrt(height));
     float2 uv=ray.xz/(height+.21);
     float clouds=cloud(uv*1.7)*.52+cloud(uv*4.3)*.29+cloud(uv*10.1)*.14;
     rgb+= (clouds-.40)*.17*smoothstep(.005,.16,height);
     float sun=saturate(dot(ray,normalize(float3(-.48,.24,-.36))));
     rgb+=float3(.16,.12,.06)*pow(sun,19);
     return fixed4(rgb,1);
 }
 ENDCG
 }
 }
}
