Shader "Kinsei/Canal water"
{
    Properties { _Dawn ("Daylight", Range(0,1))=0 }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #include "UnityCG.cginc"
            float _Dawn;
            struct vary { float4 pos:SV_POSITION;float3 world:TEXCOORD0;float3 normal:TEXCOORD1;UNITY_FOG_COORDS(2) };
            vary vert(appdata_base v) {
                vary o;o.pos=UnityObjectToClipPos(v.vertex);o.world=mul(unity_ObjectToWorld,v.vertex).xyz;
                o.normal=UnityObjectToWorldNormal(v.normal);UNITY_TRANSFER_FOG(o,o.pos);return o;
            }
            // Reflection centre follows the mirrored post image as the observer moves along the bank.
            float pool(float2 centre,float2 p,float3 eye,float wave) {
                float surfaceY=-1.34,postY=1.285;
                float ratio=saturate((eye.y-surfaceY)/max(.10,eye.y+postY-2*surfaceY));
                float2 mirrored=lerp(eye.xz,centre,ratio);
                float2 d=p-mirrored;return exp2(-dot(d*d,float2(3.4,1.65)))*wave;
            }
            fixed4 frag(vary i):SV_Target {
                float2 p=i.world.xz;float3 eye=_WorldSpaceCameraPos;
                float phase=12*p.y+1.7*sin(2.1*p.x+_Time.y*.53)+_Time.y*.88;
                float band=saturate(.5+.5*cos(phase));band=band*band;
                float sheen=pow(1-saturate(dot(normalize(eye-i.world),float3(0,1,0))),3);
                float3 base=lerp(float3(.031,.068,.082),float3(.128,.206,.218),_Dawn);
                float pools=pool(float2(-33.77,-12.93),p,eye,band)+pool(float2(-33.77,-7.47),p,eye,band)
                          +pool(float2(-27.92,-12.93),p,eye,band)+pool(float2(-27.92,-7.47),p,eye,band);
                float3 c=base*(.78+.22*band)+sheen*lerp(float3(.033,.043,.059),float3(.16,.17,.17),_Dawn);
                c+=pools*float3(.45,.246,.088)*(1-_Dawn);
                // A broad amber wash lies along the waterline below the four luminaires.
                float edgeX=min(abs(p.x+33.77),abs(p.x+27.92));
                float edgeZ=min(abs(p.y+12.93),abs(p.y+7.47));
                c+=float3(.16,.09,.028)*exp2(-.9*edgeX*edgeX-.55*edgeZ*edgeZ)*(.28+.72*band)*(1-_Dawn);
                fixed4 result=fixed4(c*lerp(.47,1,saturate(i.normal.y)),1);UNITY_APPLY_FOG(i.fogCoord,result);return result;
            }
            ENDCG
        }
    }
}
