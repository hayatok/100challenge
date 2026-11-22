Shader "Kinsei/Wet Pavement"
{
    Properties {
        _Reflection ("Reflected street", 2D) = "black" {}
        _Asphalt ("Aggregate", 2D) = "gray" {}
        _Basin ("Basin edges", 2D) = "gray" {}
        _Coverage ("Shared water heights", 2D) = "gray" {}
        _Ripple ("Water grain", 2D) = "gray" {}
    }
    SubShader {
        Tags { "Queue"="Transparent-20" "RenderType"="Transparent" }
        Pass {
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #include "UnityCG.cginc"
            float4 _ReflectionUV;
            sampler2D _Reflection, _Asphalt, _Basin, _Ripple, _Coverage;
            float4 _DepthParams, _HeightScales;
            float4 _Steps[8];
            float _Clock, _Strength;
            struct Input { float4 vertex:POSITION; float2 uv:TEXCOORD0; };
            struct Vary { float4 pos:SV_POSITION; float4 screen:TEXCOORD0; float2 world:TEXCOORD1; float2 local:TEXCOORD2; };
            Vary vert(Input v) {
                Vary o;
                o.pos=UnityObjectToClipPos(v.vertex);
                o.screen=ComputeScreenPos(o.pos);
                o.world=v.vertex.xz;o.local=v.uv;
                return o;
            }
            half4 frag(Vary i):SV_Target {
                float2 p=i.world;
                float grain=tex2D(_Asphalt,p/0.26).r;
                float bank=tex2D(_Basin,p/1.5).r;
                float rim=1-length(i.local);
                float depth=rim*_DepthParams.x + (tex2D(_Coverage,p/_HeightScales.y).g-.5)*_DepthParams.y
                    - tex2D(_Coverage,p/_HeightScales.x).r*_DepthParams.z;
                float opacity=smoothstep(_DepthParams.w,.24,depth);
                float2 normal=(tex2D(_Ripple,p/.12).rg-.5)*.0013*(.75+.28*bank+.22*grain);
                float crest=0;
                [unroll] for(int k=0;k<8;k++) {
                    float age=_Clock-_Steps[k].z;
                    float2 delta=p-_Steps[k].xy;
                    float radius=length(delta);
                    float travel=radius-age*.43;
                    float wave=sin(travel*115)*exp(-abs(travel)*37)*saturate(1-age/1.05)*saturate(age*20)*_Steps[k].w;
                    normal+=delta/max(radius,.01)*wave*.006;
                    crest+=max(wave,0);
                }
                float2 uv=i.screen.xy/i.screen.w;
                half3 reflected=tex2D(_Reflection,saturate((uv+normal)*_ReflectionUV.xy+_ReflectionUV.zw)).rgb;
                float3 view=normalize(_WorldSpaceCameraPos-float3(p.x,-.011,p.y));
                float grazing=pow(1-saturate(view.y),3);
                half3 water=lerp(half3(.012,.014,.014),reflected*half3(.94,.97,1),.55+.45*grazing);
                water+=crest*(.065+.12*saturate(dot(reflected,half3(.21,.72,.07))));
                return half4(water,opacity*_Strength*(.32+.65*grazing));
            }
            ENDCG
        }
    }
}
