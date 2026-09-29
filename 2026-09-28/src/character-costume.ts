import * as T from 'three';

/** Tailoring is made from the actual rig's rest-pose surface and retains every
 * joint index/weight. No garment is a rigid board parented to a moving bone. */
export function tailorCityCharacter(character:T.Object3D):void {
  const meshes:T.SkinnedMesh[]=[];
  character.traverse(o=>{if(o instanceof T.SkinnedMesh)meshes.push(o);});
  const cloth=new T.MeshStandardMaterial({name:'Nightshift rolled work shirt',color:0xb4b19a,roughness:.95,side:T.DoubleSide});
  const hair=new T.MeshStandardMaterial({name:'Nightshift cropped hair',color:0x423d32,roughness:.96,side:T.DoubleSide});
  // Fine fragment-level hairlines avoid a polygonal helmet edge on the source scalp.
  hair.onBeforeCompile=shader=>{
    shader.vertexShader=shader.vertexShader.replace('#include <common>','#include <common>\nvarying vec3 hairRest;').replace('#include <begin_vertex>','#include <begin_vertex>\nhairRest=position;');
    shader.fragmentShader=shader.fragmentShader.replace('#include <common>','#include <common>\nvarying vec3 hairRest;').replace('#include <color_fragment>',`#include <color_fragment>
      float front=smoothstep(0.005,0.065,hairRest.z);
      float edge=mix(1.665,1.746,front)+sin(hairRest.x*57.0)*0.004;
      float strand=sin(hairRest.x*840.0+hairRest.z*420.0+hairRest.y*77.0);
      if(hairRest.y<edge+strand*0.003) discard;
      diffuseColor.rgb*=0.88+0.12*smoothstep(-0.7,0.85,strand);
    `);
  };
  cloth.onBeforeCompile=shader=>{
    shader.vertexShader=shader.vertexShader.replace('#include <common>','#include <common>\nvarying vec3 clothRest;').replace('#include <begin_vertex>','#include <begin_vertex>\nclothRest=position;');
    shader.fragmentShader=shader.fragmentShader.replace('#include <common>','#include <common>\nvarying vec3 clothRest;').replace('#include <color_fragment>',`#include <color_fragment>
      float neckline=1.415+smoothstep(0.045,0.14,abs(clothRest.x))*0.11;
      if(clothRest.y>neckline || abs(clothRest.x)>0.465 || clothRest.y<1.02) discard;
      float weave=sin(clothRest.x*2100.0)*sin(clothRest.y*1900.0);
      float wear=sin(clothRest.x*27.0+clothRest.y*31.0)*sin(clothRest.z*63.0+clothRest.y*13.0);
      diffuseColor.rgb*=0.76+weave*0.045+wear*0.15;
      if(clothRest.z>0.05 && abs(clothRest.x)<0.004) diffuseColor.rgb*=0.73;
    `);
  };
  const canvas=document.createElement('canvas');canvas.width=512;canvas.height=1024;
  const c=canvas.getContext('2d')!;
  c.clearRect(0,0,512,1024);
  // Bib, narrow shoulder straps, waist skirt. The print follows the deformed UVs.
  c.fillStyle='#34443a';c.fillRect(108,300,296,710);c.fillRect(145,65,37,290);c.fillRect(330,65,37,290);
  c.fillRect(28,590,456,420);
  c.strokeStyle='#8b8b6c';c.lineWidth=3;c.strokeRect(115,308,282,283);c.strokeRect(143,637,225,166);
  c.beginPath();c.moveTo(151,658);c.lineTo(357,658);c.stroke();
  c.fillStyle='#d5ccb1';c.textAlign='center';c.font='bold 30px serif';c.fillText('やまさか商店',256,426,260);
  c.font='19px serif';c.fillText('新鮮な食材を、毎日。',256,468,258);
  // Deterministic cloth weave and work stains, not solid flat color.
  for(let i=0;i<6000;i++){const x=(i*71.37)%512,y=(i*137.23)%1024;c.fillStyle=i%3?'rgba(11,20,14,.05)':'rgba(224,213,182,.05)';c.fillRect(x,y,1,4);}
  for(let i=0;i<20;i++){const x=100+(i*79.3)%300,y=340+(i*117.1)%630,g=c.createRadialGradient(x,y,0,x,y,45);g.addColorStop(0,'rgba(49,26,15,.28)');g.addColorStop(1,'rgba(49,26,15,0)');c.fillStyle=g;c.fillRect(x-45,y-45,90,90);}
  const map=new T.CanvasTexture(canvas);map.colorSpace=T.SRGBColorSpace;map.anisotropy=4;
  const apron=new T.MeshStandardMaterial({name:'Nightshift skinned shop apron',map,roughness:.97,alphaTest:.5,side:T.DoubleSide});
  function layer(source:T.SkinnedMesh,name:string,material:T.Material,select:(x:number,y:number,z:number)=>boolean,offset:(x:number,y:number,z:number)=>number,apronUV=false){
    const g=source.geometry.clone(),position=g.getAttribute('position'),normal=g.getAttribute('normal'),indices=g.index;
    if(!indices)return;
    const triangles:number[]=[];
    for(let i=0;i<indices.count;i+=3){
      const a=indices.getX(i),b=indices.getX(i+1),d=indices.getX(i+2);
      if(select((position.getX(a)+position.getX(b)+position.getX(d))/3,(position.getY(a)+position.getY(b)+position.getY(d))/3,(position.getZ(a)+position.getZ(b)+position.getZ(d))/3))triangles.push(a,b,d);
    }
    if(!triangles.length){g.dispose();return;}
    g.setIndex(triangles);g.clearGroups();
    const colors:number[]=[];const uv:number[]=[];
    for(let i=0;i<position.count;i++){
      const x=position.getX(i),y=position.getY(i),z=position.getZ(i),out=offset(x,y,z);
      position.setXYZ(i,x+normal.getX(i)*out,y+normal.getY(i)*out,z+normal.getZ(i)*out);
      const shade=.6+.4*(.5+.5*Math.sin(x*183+y*151+z*139));colors.push(shade,shade*.97,shade*.87);
      uv.push(.5+x/.58,(y-.55)/1.04);
    }
    if(material===hair)g.setAttribute('color',new T.Float32BufferAttribute(colors,3));
    if(apronUV)g.setAttribute('uv',new T.Float32BufferAttribute(uv,2));
    g.computeBoundingSphere();
    const added=new T.SkinnedMesh(g,material);added.name=name;added.position.copy(source.position);added.quaternion.copy(source.quaternion);added.scale.copy(source.scale);
    added.bindMode=source.bindMode;added.bind(source.skeleton,source.bindMatrix);added.frustumCulled=false;added.castShadow=true;
    source.parent!.add(added);
  }
  for(const source of meshes){
    const m=Array.isArray(source.material)?source.material[0]:source.material;
    if(/Body/i.test(m.name)){
      layer(source,'Skinned continuous work shirt',cloth,(x,y)=>Math.abs(x)<.49&&y>1.0&&y<1.55,(x,y)=>.011+Math.sin(x*105+y*42)*.0018);
      layer(source,'Skinned apron bib',apron,(x,y,z)=>Math.abs(x)<.3&&y>.995&&y<1.54&&z>-.045,()=>.023,true);
      layer(source,'Skinned uneven cropped hair',hair,(_x,y)=>y>1.645,(x,y,z)=>.003+(.5+.5*Math.sin(x*151+z*101+y*51))*.003);
    }
    if(/Outfit/i.test(m.name)) {
      layer(source,'Skinned apron skirt',apron,(x,y,z)=>Math.abs(x)<.3&&y>.56&&y<1.012&&z>.018,()=>.008,true);
      // The imported torn tunic sits outside the body. Remove its upper faces
      // now that a continuous shirt replaces them, preventing surface intersections.
      const g=source.geometry.clone(),p=g.getAttribute('position'),index=g.index!;
      const kept:number[]=[];
      for(let i=0;i<index.count;i+=3){const a=index.getX(i),b=index.getX(i+1),c=index.getX(i+2);if((p.getY(a)+p.getY(b)+p.getY(c))/3<1.025)kept.push(a,b,c);}
      g.setIndex(kept);g.computeBoundingSphere();source.geometry=g;
    }
  }
}
