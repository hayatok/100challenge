Shader "Kinsei/Makabe combed hair"
{
    Properties
    {
        _FiberColor ("Black chestnut fibre", Color) = (.235,.207,.192,1)
        _SilverColor ("Temple silver", Color) = (.57,.55,.52,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        CGINCLUDE
        #include "UnityCG.cginc"
        #include "Lighting.cginc"
        #include "AutoLight.cginc"
        fixed4 _FiberColor, _SilverColor;
        struct Vertex {
            float4 vertex:POSITION;
            float3 normal:NORMAL;
            float4 tangent:TANGENT;
            float2 uv:TEXCOORD0;
        };
        struct Varying {
            float4 pos:SV_POSITION;
            float3 world:TEXCOORD0;
            half3 normal:TEXCOORD1;
            half3 fibre:TEXCOORD2;
            float2 uv:TEXCOORD3;
            LIGHTING_COORDS(4,5)
            UNITY_FOG_COORDS(6)
            half3 fill:TEXCOORD7;
        };
        Varying vert(Vertex v)
        {
            Varying o;
            o.pos=UnityObjectToClipPos(v.vertex);
            o.world=mul(unity_ObjectToWorld,v.vertex).xyz;
            o.normal=UnityObjectToWorldNormal(v.normal);
            float3 tangent=UnityObjectToWorldDir(v.tangent.xyz);
            o.fibre=cross(o.normal,tangent)*v.tangent.w*unity_WorldTransformParams.w;
            o.uv=v.uv;
            o.fill=max(0,ShadeSH9(half4(o.normal,1)));
            #ifdef VERTEXLIGHT_ON
            o.fill+=Shade4PointLights(unity_4LightPosX0,unity_4LightPosY0,unity_4LightPosZ0,
                unity_LightColor[0].rgb,unity_LightColor[1].rgb,unity_LightColor[2].rgb,unity_LightColor[3].rgb,
                unity_4LightAtten0,o.world,o.normal);
            #endif
            TRANSFER_VERTEX_TO_FRAGMENT(o);
            UNITY_TRANSFER_FOG(o,o.pos);
            return o;
        }
        float wave(float cycle)
        {
            return cos(cycle*6.2831853)*(1-smoothstep(.12,.5,fwidth(cycle)));
        }
        half4 frag(Varying i):SV_Target
        {
            half3 n=normalize(i.normal);
            half3 along=normalize(i.fibre-dot(i.fibre,n)*n);
            half3 lightDir=normalize(UnityWorldSpaceLightDir(i.world));
            half3 viewDir=normalize(UnityWorldSpaceViewDir(i.world));
            half3 halfDir=normalize(lightDir+viewDir);
            float u=i.uv.x,v=i.uv.y;
            float comb=u*26+.13*sin(u*18.84956+v*4);
            float group=wave(comb),fine=wave(comb*5+.21*sin(12*comb));
            float angle=u*6.2831853-3.14159265;
            float temple=smoothstep(.67,.98,v)*smoothstep(.61,.92,abs(sin(angle)));
            float grey=temple*max(0,wave(u*113+.21*sin(v*6)))*.31;
            float seam=atan2(sin(angle+.39),cos(angle+.39))/.062;
            float part=exp(-seam*seam)
                       *smoothstep(.13,.32,v)*(1-smoothstep(.90,1,v));
            half3 pigment=lerp(_FiberColor.rgb,_SilverColor.rgb,grey)*(.86+.12*group+.07*fine);
            pigment*=1+.18*part;
            half facing=saturate(dot(n,lightDir));
            half longitudinal=dot(normalize(along+n*.13),halfDir);
            half sheen=pow(saturate(1-longitudinal*longitudinal),27);
            half grazing=saturate(dot(n,halfDir));
            UNITY_LIGHT_ATTENUATION(atten,i,i.world);
            half3 direct=pigment*(.10+.90*facing)+(.105+.026*group)*sheen*grazing*grazing*facing;
            half3 colour=direct*_LightColor0.rgb*atten;
            #ifdef UNITY_PASS_FORWARDADD
            UNITY_APPLY_FOG_COLOR(i.fogCoord,colour,half4(0,0,0,0));
            #else
            colour+=pigment*(i.fill*.86+.062);
            UNITY_APPLY_FOG(i.fogCoord,colour);
            #endif
            return half4(colour,1);
        }
        ENDCG
        Pass {
            Tags { "LightMode"="ForwardBase" }
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap
            #pragma multi_compile_fog
            ENDCG
        }
        Pass {
            Tags { "LightMode"="ForwardAdd" }
            Blend One One
            ZWrite Off
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog
            ENDCG
        }
        UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
    }
    Fallback Off
}
