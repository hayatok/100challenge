Shader "Kinsei/BathCurtain"
{
    Properties
    {
        _MainTex ("Dyed cotton",2D)="white" {}
        _Color ("Dye",Color)=(1,1,1,1)
        _Glyph ("Resist stencil",2D)="black" {}
        _GlyphBL ("Lower left",Vector)=(0,0,0,0)
        _GlyphBR ("Lower right",Vector)=(0,0,0,0)
        _GlyphTL ("Upper left",Vector)=(0,0,0,0)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        CGPROGRAM
        #pragma surface surf Standard vertex:vert addshadow
        #pragma target 3.0
        struct Input { float2 uv_MainTex; float2 letter; };
        sampler2D _MainTex,_Glyph;
        fixed4 _Color;
        float4 _GlyphBL,_GlyphBR,_GlyphTL;
        void vert(inout appdata_full v,out Input data)
        {
            UNITY_INITIALIZE_OUTPUT(Input,data);
            data.letter=v.texcoord1.xy;
        }
        void surf(Input data,inout SurfaceOutputStandard outp)
        {
            float2 p=data.letter;
            float2 glyphUV=_GlyphBL.xy+(_GlyphBR.xy-_GlyphBL.xy)*p.x+(_GlyphTL.xy-_GlyphBL.xy)*p.y;
            half resist=tex2D(_Glyph,glyphUV).a*step(0,p.x)*step(p.x,1)*step(0,p.y)*step(p.y,1);
            fixed3 weave=tex2D(_MainTex,data.uv_MainTex).rgb*_Color.rgb;
            outp.Albedo=lerp(weave,fixed3(.91,.79,.57)*(.86+.14*dot(weave,fixed3(.3,.59,.11))),resist);
            outp.Smoothness=.22;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
