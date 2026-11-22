Shader "Kinsei/Water Crown"
{
    Properties { _Reflection ("Street reflection",2D)="black" {} }
    SubShader {
        Tags {"Queue"="Transparent-19" "RenderType"="Transparent"}
        Pass {
            Cull Off ZWrite Off Blend SrcAlpha OneMinusSrcAlpha
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            float4 _ReflectionUV;
            sampler2D _Reflection;
            float _Age;
            struct Input {float4 vertex:POSITION; float4 motion:TEXCOORD0;};
            struct Vary {float4 pos:SV_POSITION; float4 screen:TEXCOORD0; float3 shape:TEXCOORD1;};
            Vary vert(Input v)
            {
                Vary o;
                float t=saturate(_Age/v.motion.z);
                float lift=4*t*(1-t);
                float3 position=v.vertex.xyz;
                position.xz*=lerp(.88,2.03,t);
                position.y+=lift*v.motion.y+.001;
                o.pos=UnityObjectToClipPos(float4(position,1));
                o.screen=ComputeScreenPos(o.pos);
                o.shape=float3(saturate(lift*2.6),v.motion.w,v.motion.x);
                return o;
            }
            half4 frag(Vary i):SV_Target
            {
                float edge=saturate(i.shape.y);
                float2 uv=i.screen.xy/i.screen.w;
                // The upturned lip catches a higher slice of the same reflected storefront.
                half3 lamp=tex2D(_Reflection,saturate((uv+float2(.002*(edge-.5),.014+.018*edge))*_ReflectionUV.xy+_ReflectionUV.zw)).rgb;
                half3 water=half3(.040,.057,.060)+min(lamp,half3(1.2,1.2,1.2))*(.43+.16*edge);
                return half4(water,i.shape.x*(.27+.32*edge+.14*i.shape.z));
            }
            ENDCG
        }
    }
}
