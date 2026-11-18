Shader "Evac/Afterglow" {
 SubShader { Tags { "Queue"="Transparent+15" "RenderType"="Transparent" }
   Cull Off ZWrite Off Blend SrcAlpha One
   Pass {
    CGPROGRAM
    #pragma vertex vert
    #pragma fragment frag
    #include "UnityCG.cginc"
    struct V {float4 pos:POSITION; fixed4 col:COLOR; float2 uv:TEXCOORD0;};
    struct F {float4 pos:SV_POSITION; fixed4 col:COLOR; float2 uv:TEXCOORD0;};
    F vert(V i){F o;o.pos=UnityObjectToClipPos(i.pos);o.col=i.col;o.uv=i.uv;return o;}
    fixed4 frag(F i):SV_Target{float d=saturate(1-dot(i.uv,i.uv));return fixed4(i.col.rgb,i.col.a*d*d);}
    ENDCG
   }
 }
}
