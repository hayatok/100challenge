Shader "Kinsei/Blown Glass" {
    Properties { _Tint ("Glass tint", Color) = (.76,.89,.88,1) }
    SubShader {
        Tags {"Queue"="Transparent" "RenderType"="Transparent"}
        Pass {
            Cull Back ZWrite Off Blend SrcAlpha OneMinusSrcAlpha
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            half4 _Tint;
            struct vout {float4 clip:SV_POSITION;float3 n:TEXCOORD0;float3 pos:TEXCOORD1;};
            vout vert(appdata_base v){
                vout o;o.clip=UnityObjectToClipPos(v.vertex);o.n=UnityObjectToWorldNormal(v.normal);
                o.pos=mul(unity_ObjectToWorld,v.vertex).xyz;return o;
            }
            half4 frag(vout i):SV_Target{
                float3 n=normalize(i.n),view=normalize(_WorldSpaceCameraPos-i.pos),r=reflect(-view,n);
                float edge=pow(1-saturate(dot(n,view)),3.4);
                float3 reflected=DecodeHDR(UNITY_SAMPLE_TEXCUBE(unity_SpecCube0,r),unity_SpecCube0_HDR);
                float softbox=pow(saturate(dot(r,normalize(float3(-.57,.71,.49)))),24);
                return half4(_Tint.rgb*(.38+.63*edge)+.7*reflected+softbox, .12+.62*edge+.24*softbox);
            }
            ENDCG
        }
    }
}
