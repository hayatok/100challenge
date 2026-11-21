Shader "Kinsei/LetterGlass" {
Properties { _MainTex("Typeface",2D)="white" {} }
SubShader {
  Tags {"Queue"="Transparent" "RenderType"="Transparent"}
  Cull Back ZWrite Off ZTest LEqual Blend SrcAlpha OneMinusSrcAlpha
  Pass {
    CGPROGRAM
    #pragma vertex vert
    #pragma fragment frag
    #include "UnityCG.cginc"
    struct Input { float4 vertex:POSITION; fixed4 color:COLOR; float2 uv:TEXCOORD0; };
    struct Output { float4 vertex:SV_POSITION; fixed4 color:COLOR; float2 uv:TEXCOORD0; };
    sampler2D _MainTex;
    Output vert(Input v){Output o;o.vertex=UnityObjectToClipPos(v.vertex);o.color=v.color;o.uv=v.uv;return o;}
    fixed4 frag(Output i):SV_Target { fixed4 c=i.color; c.a*=tex2D(_MainTex,i.uv).a;return c;}
    ENDCG
  }
}
}
