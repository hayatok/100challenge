Shader "Evac/CoastalSky" {
 Properties {
     _Evening("Evening", Range(0,1))=0
     _Plate("Wrapped coastal sky", 2D)="gray"{}
 }
 SubShader {
 Tags { "Queue"="Background" "RenderType"="Background" "PreviewType"="Skybox" }
 Cull Off ZWrite Off
 Pass {
 CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #pragma target 3.0
 #include "UnityCG.cginc"
 sampler2D _Plate;
 float _Evening;
 struct V { float4 vertex:POSITION; };
 struct F { float4 vertex:SV_POSITION; float3 ray:TEXCOORD0; };
 F vert(V v) {
     F o;
     o.vertex=UnityObjectToClipPos(v.vertex);
     o.ray=v.vertex.xyz;
     return o;
 }
 fixed4 frag(F f):SV_Target {
     float3 ray=normalize(f.ray);
     float2 horizontal=ray.xz;
     const float inverseTurn=.159154943;
     float u=.523+atan2(horizontal.x,horizontal.y)*inverseTurn;
     float elevation=asin(clamp(ray.y,-1,1))*.636619772;
     float v=.048+.949*elevation*(1.63-.63*elevation);
     float2 tangent=float2(horizontal.y,-horizontal.x)*
                   (inverseTurn/max(dot(horizontal,horizontal),.001));
     // Differentiate the angle from the direction. This avoids a wrong mip
     // level when the two sides of atan2's periodic seam meet on screen.
     float2 dx=float2(dot(tangent,ddx(horizontal)),ddx(v));
     float2 dy=float2(dot(tangent,ddy(horizontal)),ddy(v));
     float3 plate=tex2Dgrad(_Plate,float2(u,saturate(v)),dx,dy).rgb;
     // A flat projection through the upper dome keeps cloud forms intact
     // overhead, where longitudinal sampling otherwise converges to a point.
     float2 overhead=float2(.59,.61)+horizontal*float2(.32,-.34);
     float2 overheadDx=ddx(overhead);
     float2 overheadDy=ddy(overhead);
     if(ray.y>.72){
         float3 cap=tex2Dgrad(_Plate,overhead,overheadDx,overheadDy).rgb;
         plate=lerp(plate,cap,smoothstep(.72,.92,ray.y));
     }
     float lower=1-smoothstep(-.064,-.025,ray.y);
     float3 rgb=lerp(plate,float3(.60,.65,.65),lower);
     float eveningGlow=saturate(dot(ray,normalize(float3(-.62,.11,-.62))));
     float dusk=pow(eveningGlow,4.)*(1-smoothstep(.04,.54,ray.y));
     float3 night=rgb*float3(.69,.72,.79)+dusk*float3(.135,.069,.023);
     return fixed4(lerp(rgb,night,_Evening),1);
 }
 ENDCG
 }
 }
}
