Shader "Kinsei/Bathhouse pressed glass"
{
    Properties
    {
        _MainTex ("Pressed surface", 2D) = "gray" {}
        _Lamp ("Light through glass", Range(0,1)) = 0.7
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        CGPROGRAM
        #pragma surface surf Standard fullforwardshadows
        #pragma target 3.0
        sampler2D _MainTex;
        half _Lamp;
        struct Input {float3 worldPos;};

        void surf(Input IN,inout SurfaceOutputStandard o)
        {
            float2 metres=IN.worldPos.xy;
            float2 tex=metres/0.12;
            float relief=tex2D(_MainTex,tex).g;
            float dx=tex2D(_MainTex,tex+float2(.003,0)).g-relief;
            float dy=tex2D(_MainTex,tex+float2(0,.003)).g-relief;
            o.Normal=normalize(float3(-dx*.68,-dy*.68,1));
            // The two fine diagonal wires are set in the glass, under the pressed grain.
            float2 lattice=float2(metres.x+metres.y,metres.x-metres.y)/.055;
            float2 wireDistance=abs(frac(lattice+.5)-.5);
            float2 width=max(fwidth(lattice),.003);
            float2 wires=(1-smoothstep(.002,.017+width,wireDistance))*.017/(.017+width);
            float metal=max(wires.x,wires.y);
            half grain=saturate((relief-.14)*1.25);
            half3 base=lerp(half3(.18,.22,.19),half3(.56,.55,.40),grain);
            o.Albedo=lerp(base,half3(.088,.091,.074),metal*.8);
            // Warmth diffuses from the lit room, retaining darker glass at the foot of each door.
            half lit=smoothstep(.55,2.05,metres.y)*(.72+.28*cos((metres.x+39.0)*2.1));
            o.Emission=half3(.28,.20,.105)*_Lamp*(.21+.79*lit)*(.79+.21*grain)*(1-metal*.58);
            o.Smoothness=lerp(.39,.53,grain);
            o.Metallic=0;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
