Shader "Kinsei/Carriage window"
{
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Back
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            struct varyings { float4 pos:SV_POSITION; float3 world:TEXCOORD0; float3 normal:TEXCOORD1; };
            varyings vert(appdata_base v)
            {
                varyings o; o.pos=UnityObjectToClipPos(v.vertex);
                o.world=mul(unity_ObjectToWorld,v.vertex).xyz;
                o.normal=UnityObjectToWorldNormal(v.normal);return o;
            }
            half4 frag(varyings i):SV_Target
            {
                half edge=1-saturate(abs(dot(normalize(_WorldSpaceCameraPos-i.world),normalize(i.normal))));
                half reflectance=.014+.055*edge*edge*edge;
                return half4(.16,.23,.22,reflectance);
            }
            ENDCG
        }
    }
}
