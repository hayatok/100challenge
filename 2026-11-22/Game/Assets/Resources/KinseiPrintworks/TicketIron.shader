Shader "Kinsei/Printing/Ticket Iron"
{
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200
        CGPROGRAM
        #pragma surface surf Standard fullforwardshadows addshadow vertex:hardware
        #pragma target 4.5
        struct Input { float3 part; float2 response; fixed4 paint; half lip; };
        void hardware(inout appdata_full v,out Input o)
        {
            UNITY_INITIALIZE_OUTPUT(Input,o);
            o.part=v.vertex.xyz;
            o.response=v.texcoord.xy;
            o.paint=v.color;
            #ifndef UNITY_COLORSPACE_GAMMA
            o.paint.rgb=GammaToLinearSpace(o.paint.rgb);
            #endif
            float3 axis=abs(v.normal);
            o.lip=saturate((1-max(axis.x,max(axis.y,axis.z)))*5.7);
        }
        float hashCell(float3 p)
        {
            p=frac(p*float3(.1031,.11369,.13787));
            p+=dot(p,p.yxz+19.19);
            return frac((p.x+p.y)*p.z);
        }
        float mottling(float3 p)
        {
            float3 c=floor(p),u=frac(p);
            u=u*u*(3-2*u);
            float4 low=float4(hashCell(c),hashCell(c+float3(1,0,0)),hashCell(c+float3(0,1,0)),hashCell(c+float3(1,1,0)));
            c.z++;
            float4 high=float4(hashCell(c),hashCell(c+float3(1,0,0)),hashCell(c+float3(0,1,0)),hashCell(c+float3(1,1,0)));
            float4 layer=lerp(low,high,u.z);
            return lerp(lerp(layer.x,layer.y,u.x),lerp(layer.z,layer.w,u.x),u.y);
        }
        void surf(Input i,inout SurfaceOutputStandard o)
        {
            float longWear=mottling(i.part*float3(110,142,85));
            float grain=mottling(i.part*float3(1340,1470,1210));
            float footprint=max(length(ddx(i.part)),length(ddy(i.part)));
            grain=lerp(grain,.5,saturate(footprint*780-.25));
            float chip=i.paint.a*i.lip*smoothstep(.61,.76,longWear*.71+grain*.29);
            fixed3 paint=i.paint.rgb*(.78+.30*longWear+.14*grain);
            fixed3 exposed=fixed3(.36,.30,.21);
            #ifndef UNITY_COLORSPACE_GAMMA
            exposed=GammaToLinearSpace(exposed);
            #endif
            o.Albedo=lerp(paint,exposed,chip*.86);
            o.Metallic=lerp(i.response.x,.75,chip);
            o.Smoothness=saturate(i.response.y+(grain-.5)*.19+(longWear-.5)*.18+chip*.09);
            o.Alpha=1;
        }
        ENDCG
    }
    FallBack Off
}
