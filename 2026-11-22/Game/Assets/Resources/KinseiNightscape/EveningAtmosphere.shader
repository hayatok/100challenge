Shader "Kinsei/Night Air"
{
    Properties { _MainTex ("Air", 2D) = "black" {} }
    SubShader
    {
        Tags { "Queue"="Geometry+490" "RenderType"="Opaque" }
        Pass
        {
            Cull Off ZWrite Off ZTest LEqual
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            struct appdata { float4 vertex : POSITION; float2 uv : TEXCOORD0; };
            struct v2f { float4 position : SV_POSITION; float2 uv : TEXCOORD0; };
            sampler2D _MainTex;
            v2f vert(appdata v)
            {
                v2f o;
                o.position=UnityObjectToClipPos(v.vertex);
                o.uv=v.uv;
                return o;
            }
            fixed4 frag(v2f i) : SV_Target { return tex2D(_MainTex,i.uv); }
            ENDCG
        }
    }
}
