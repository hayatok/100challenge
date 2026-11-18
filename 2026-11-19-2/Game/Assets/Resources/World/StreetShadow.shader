Shader "Evac/StreetShadow" {
 SubShader { Tags {"Queue"="Transparent-10" "RenderType"="Transparent"}
 Pass { Blend SrcAlpha OneMinusSrcAlpha ZWrite Off Cull Off
 CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #pragma multi_compile_instancing
 #include "UnityCG.cginc"
 struct V{ float4 pos:POSITION; float2 uv:TEXCOORD0; UNITY_VERTEX_INPUT_INSTANCE_ID };
 struct O{ float4 pos:SV_POSITION; float2 uv:TEXCOORD0; };
 O vert(V v){ UNITY_SETUP_INSTANCE_ID(v); O o; o.pos=UnityObjectToClipPos(v.pos);o.uv=v.uv*2-1;return o;}
 fixed4 frag(O f):SV_Target{return fixed4(.11,.15,.15,saturate(1-dot(f.uv,f.uv))*.39);}
 ENDCG
 } }
}
