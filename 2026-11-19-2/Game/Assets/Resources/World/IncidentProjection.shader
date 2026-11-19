Shader "Evac/IncidentProjection" {
 Properties { _Water("Water",Float)=0 _Strength("Strength",Float)=0.5 _Clock("Clock",Float)=0 }
 SubShader {
  Tags { "Queue"="Transparent-12" "RenderType"="Transparent" }
  Pass { Cull Off ZWrite Off Blend SrcAlpha OneMinusSrcAlpha Offset -1,-1
   CGPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #include "UnityCG.cginc"
   struct V {float4 vertex:POSITION;float2 uv:TEXCOORD0;};
   struct F {float4 position:SV_POSITION;float2 uv:TEXCOORD0;float3 world:TEXCOORD1;};
   float _Strength,_Clock,_Water;
   F vert(V v){ F o;o.position=UnityObjectToClipPos(v.vertex);o.uv=v.uv;o.world=mul(unity_ObjectToWorld,v.vertex).xyz;return o; }
   fixed4 frag(F i):SV_Target{
     float2 uv=i.uv*2-1;
     if(_Water>.5){
        float waves=sin(i.world.z*4+i.world.x*.9+_Clock*1.35)*.5+sin(i.world.x*3.5-i.world.z*2-_Clock*.8)*.5;
        float edge=1-smoothstep(.65,1,length(uv)+waves*.09);
        return fixed4(.18+.06*waves,.34+.07*waves,.36+.08*waves,edge*(.26+.40*_Strength));
     }
     float width=lerp(.09,1,i.uv.y);
     float edge=1-smoothstep(width*.65,width,abs(uv.x));
     float feather=smoothstep(0,.12,i.uv.y)*(1-smoothstep(.62,1,i.uv.y));
     return fixed4(1,.86,.55,edge*feather*(.09+.31*_Strength));
   }
   ENDCG
  }
 }
}
