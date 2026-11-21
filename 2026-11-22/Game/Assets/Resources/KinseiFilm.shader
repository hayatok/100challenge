Shader "Kinsei/HouseLights" {
Properties { _MainTex ("Frame", 2D) = "white" {} _Halation ("Light spill", 2D) = "black" {} }
SubShader {
    Cull Off ZWrite Off ZTest Always
    CGINCLUDE
    #include "UnityCG.cginc"
    sampler2D _MainTex, _Halation;
    UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
    float4 _MainTex_TexelSize;
    float _Spread, _Grain;
    float3 finiteColor(float3 c) {
        return float3(c.x>=0?min(c.x,16):0,c.y>=0?min(c.y,16):0,c.z>=0?min(c.z,16):0);
    }
    half4 extract(v2f_img p):SV_Target {
        float3 c=finiteColor(tex2D(_MainTex,p.uv).rgb);
        half lum=max(c.r,max(c.g,c.b));
        return half4(c*smoothstep(.63,1.55,lum),1);
    }
    half4 blur(v2f_img p):SV_Target {
        float2 d=_MainTex_TexelSize.xy*_Spread;
        half3 s = tex2D(_MainTex,p.uv+d).rgb + tex2D(_MainTex,p.uv-d).rgb;
        s+=tex2D(_MainTex,p.uv+float2(d.x,-d.y)).rgb+tex2D(_MainTex,p.uv+float2(-d.x,d.y)).rgb;
        return half4(s*.25,1);
    }
    float eyeDepth(float2 uv) {
        return LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,uv));
    }
    float contact(float2 uv,float depth,float2 slope,float2 pixelOffset) {
        float expected=depth+dot(slope,pixelOffset);
        float closer=expected-eyeDepth(uv+pixelOffset/_ScreenParams.xy);
        return smoothstep(.023,.12,closer)*(1-smoothstep(.18,.60,closer));
    }
    half4 grade(v2f_img p):SV_Target {
        float3 c=finiteColor(tex2D(_MainTex,p.uv).rgb)+finiteColor(tex2D(_Halation,p.uv).rgb)*float3(.13,.10,.085);
        float2 uv=p.uv;
        #if UNITY_UV_STARTS_AT_TOP
        if(_MainTex_TexelSize.y<0)uv.y=1-uv.y;
        #endif
        float z=eyeDepth(uv);
        float2 slope=clamp(float2(ddx(z),ddy(z)),float2(-.012,-.012),float2(.012,.012));
        float radius=clamp(_ScreenParams.y*.065/max(z,.15),2,25);
        float occlusion=0;
        if(unity_OrthoParams.w<.5 && z<28) {
            occlusion+=contact(uv,z,slope,float2(1,.2)*radius);
            occlusion+=contact(uv,z,slope,float2(-1,-.2)*radius);
            occlusion+=contact(uv,z,slope,float2(-.2,1)*radius);
            occlusion+=contact(uv,z,slope,float2(.2,-1)*radius);
            occlusion+=contact(uv,z,slope,float2(.54,.64)*radius);
            occlusion+=contact(uv,z,slope,float2(-.54,-.64)*radius);
            occlusion+=contact(uv,z,slope,float2(.64,-.54)*radius);
            occlusion+=contact(uv,z,slope,float2(-.64,.54)*radius);
        }
        c*=.90*(1-.055*occlusion);
        c=(c*(2.15*c+.05))/(c*(2.06*c+.48)+.143);
        float2 v=(p.uv-.5)*float2(1.1,.9);
        float grain=frac(sin(dot(floor(p.uv*_ScreenParams.xy),float2(12.9898,78.233)))*43758.5453)-.5;
        c=c*(1-.14*dot(v,v))+grain*_Grain;
        return half4(saturate(c),1);
    }
    ENDCG
    Pass {
        CGPROGRAM
        #pragma vertex vert_img
        #pragma fragment extract
        ENDCG
    }
    Pass {
        CGPROGRAM
        #pragma vertex vert_img
        #pragma fragment blur
        ENDCG
    }
    Pass {
        CGPROGRAM
        #pragma vertex vert_img
        #pragma fragment grade
        #pragma target 3.0
        ENDCG
    }
}
Fallback Off
}
