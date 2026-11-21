Shader "Kinsei/StageGlint" {
SubShader { Tags {"Queue"="Transparent" "RenderType"="Transparent"} Blend SrcAlpha One ZWrite Off Cull Off
Pass {
CGPROGRAM
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
struct V {float4 pos:POSITION; fixed4 color:COLOR;};
struct O {float4 pos:SV_POSITION; fixed4 color:COLOR;};
O vert(V v){O o;o.pos=UnityObjectToClipPos(v.pos);o.color=v.color;return o;}
fixed4 frag(O i):SV_Target{return i.color;}
ENDCG
}}
}
