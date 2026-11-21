Shader "Kinsei/Street television"
{
    Properties { _MainTex ("Programme", 2D) = "black" {} }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            sampler2D _MainTex;
            struct varyings { float4 vertex:SV_POSITION; float2 uv:TEXCOORD0; };
            varyings vert(appdata_base v)
            {
                varyings o; o.vertex=UnityObjectToClipPos(v.vertex); o.uv=v.texcoord.xy; return o;
            }
            half4 frag(varyings i):SV_Target
            {
                float2 p=2*i.uv-1;
                float lines=i.uv.y*235;
                float grille=.018*(1-saturate(fwidth(lines)))*(1-cos(6.283185*lines));
                float falloff=1-.09*saturate(dot(p,p));
                half3 picture=tex2D(_MainTex,i.uv).rgb*falloff*(1-grille);
                return half4(picture*half3(1.02,1,.97)+half3(.004,.005,.005),1);
            }
            ENDCG
        }
    }
}
