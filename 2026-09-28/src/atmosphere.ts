import * as T from 'three';
import { Reflector } from 'three/addons/objects/Reflector.js';
import type { RailPose } from './rail.ts';
import type { DistrictArea } from './stages.ts';

/** A single low-resolution planar reflection and a fixed rain pool. */
export class StreetAtmosphere {
  private surface: Reflector;
  private rain: T.LineSegments;
  private drops: Float32Array;
  private clock=0;
  constructor(scene:T.Scene) {
    const shader={
      uniforms:{color:{value:null},tDiffuse:{value:null},textureMatrix:{value:null},wetness:{value:.25}},
      vertexShader:`uniform mat4 textureMatrix;varying vec4 reflectionUv;varying vec2 ground;
        void main(){vec4 world=modelMatrix*vec4(position,1.);ground=world.xz;
        reflectionUv=textureMatrix*vec4(position,1.);gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}`,
      fragmentShader:`uniform sampler2D tDiffuse;uniform float wetness;varying vec4 reflectionUv;varying vec2 ground;
        void main(){
          float grain=sin(ground.x*1.7+sin(ground.y*.91))*sin(ground.y*1.12+sin(ground.x*.72));
          float mask=smoothstep(-.15,.65,grain);
          vec4 uv=reflectionUv;uv.xy+=vec2(sin(ground.y*71.),cos(ground.x*53.))*.0003*uv.w;
          vec3 reflected=texture2DProj(tDiffuse,uv).rgb;
          gl_FragColor=vec4(reflected,mask*wetness);
          #include <tonemapping_fragment>
          #include <colorspace_fragment>
        }`,
    };
    this.surface=new Reflector(new T.PlaneGeometry(100,140),{textureWidth:512,textureHeight:512,multisample:0,clipBias:.005,shader});
    this.surface.name='Wet ground reflections';
    this.surface.rotation.x=-Math.PI/2;
    this.surface.position.set(12,.017,-35);
    const material=this.surface.material as T.ShaderMaterial;
    material.transparent=true;material.depthWrite=false;material.toneMapped=true;
    const renderReflection=this.surface.onBeforeRender;
    this.surface.onBeforeRender=(renderer,world,camera,geometry,mat,group)=>{
      // AO's normal prepass must not recursively render the reflected scene.
      if(!world.overrideMaterial)renderReflection.call(this.surface,renderer,world,camera,geometry,mat,group);
    };
    scene.add(this.surface);
    this.drops=new Float32Array(180*6);
    const geometry=new T.BufferGeometry();geometry.setAttribute('position',new T.BufferAttribute(this.drops,3));
    this.rain=new T.LineSegments(geometry,new T.LineBasicMaterial({color:0xa7c8d4,transparent:true,opacity:.15,depthWrite:false}));
    this.rain.name='Rain around player';this.rain.frustumCulled=false;scene.add(this.rain);
  }
  update(dt:number,area:DistrictArea,view:RailPose,motion:boolean){
    this.clock+=dt;
    const station = area === 'forecourt' || area === 'concourse' || area === 'waiting' ||
      area === 'maintenance' || area === 'platform' || area === 'dawn';
    const indoor = area === 'store' || area === 'concourse' || area === 'waiting' ||
      area === 'maintenance';
    // The station reflector only covers the forecourt, never the lower track.
    this.surface.visible = !station || area === 'forecourt';
    this.surface.position.x = station ? 100 : 12;
    this.surface.position.z = station ? 12 : -35;
    this.surface.scale.set(station ? .2 : 1, station ? .18 : 1, 1);
    this.surface.position.y=area==='roof'?7.04:.017;
    (this.surface.material as T.ShaderMaterial).uniforms.wetness.value=
      area === 'store' ? .1 : indoor ? .08 : area === 'roof' ? .22 : area === 'forecourt' ? .22 : .3;
    this.rain.visible=motion&&!indoor&&area!=='roof'&&area!=='platform'&&area!=='dawn';
    if(!this.rain.visible)return;
    for(let i=0;i<180;i++){
      const x=view.x+Math.sin(i*127.1)*11,z=view.z-8+Math.sin(i*311.7)*11;
      const y=view.y+((i*.173-this.clock*5)%6+6)%6;
      const o=i*6;this.drops[o]=x;this.drops[o+1]=y;this.drops[o+2]=z;
      this.drops[o+3]=x-.035;this.drops[o+4]=y-.23;this.drops[o+5]=z+.02;
    }
    this.rain.geometry.attributes.position.needsUpdate=true;
  }
}
