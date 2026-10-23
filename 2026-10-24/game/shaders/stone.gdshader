shader_type spatial;
render_mode diffuse_burley;
uniform vec4 stone_color : source_color = vec4(0.68,0.66,0.59,1.0);
varying vec3 world_vertex;
varying vec3 world_normal;
void vertex() {
 world_vertex = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
 vec2 p = world_vertex.xz;
 float row = floor(p.y/2.4);
 vec2 cell = vec2((p.x + mod(row,2.0)*1.65)/3.3,p.y/2.4);
 vec2 edge = min(fract(cell),1.0-fract(cell));
 float joint = 1.0-smoothstep(0.004,0.013,min(edge.x,edge.y));
 float panel = hash(floor(cell));
 float grain = hash(floor(p*170.0));
 float top = smoothstep(0.65,0.95,world_normal.y);
 vec3 base = stone_color.rgb * (0.94 + panel*0.09 + grain*0.025);
 ALBEDO = mix(base,vec3(0.29,0.34,0.36),joint*top*0.55);
 ROUGHNESS = 0.87;
}
