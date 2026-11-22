Shader "Kinsei/Hall Clear Lens"
{
    Properties { _EdgeTint ("Bounded edge tint", Color) = (0.32,0.30,0.25,0.028) }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
        Pass
        {
            Tags { "LightMode"="Always" }
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            ZTest LEqual
            Cull Off
            ColorMask RGB
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0
            #include "UnityCG.cginc"
            struct appdata { float4 vertex : POSITION; float2 uv : TEXCOORD0; };
            struct v2f { float4 vertex : SV_POSITION; float2 uv : TEXCOORD0; };
            fixed4 _EdgeTint;
            v2f vert(appdata v) { v2f o; o.vertex=UnityObjectToClipPos(v.vertex); o.uv=v.uv; return o; }
            fixed4 frag(v2f i) : SV_Target
            {
                // Lens UVs describe a round-square (superellipse exponent 2.74).
                // The iris region contributes exactly zero at every camera/light angle.
                float2 q=abs(i.uv*2.0-1.0);
                float radius=pow(pow(q.x,2.74)+pow(q.y,2.74),1.0/2.74);
                float edge=smoothstep(0.88,1.01,radius);
                clip(edge-0.00001);
                // No light, specular, reflection probe, fog or Standard variants can
                // amplify this pass. Even the outer border stays below 3.5% opacity.
                return fixed4(clamp(_EdgeTint.rgb,0.0,0.40),min(saturate(_EdgeTint.a),0.035)*edge);
            }
            ENDCG
        }
    }
    // An unsupported shader must not fall back to an opaque/Standard lens.
    Fallback Off
}
