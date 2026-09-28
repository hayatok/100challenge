import * as T from 'three';

/** Install a complete surface atomically; keep the procedural fallback on failure. */
export async function installSurface(material:T.MeshStandardMaterial, name:string, repeat:T.Vector2, own:(t:T.Texture)=>T.Texture, load:(url:string)=>Promise<T.Texture> = url=>new T.TextureLoader().loadAsync(url)):Promise<boolean> {
  const maps=await Promise.allSettled(['diffuse','normal','roughness'].map(part=>load(`${import.meta.env?.BASE_URL ?? './'}assets/materials/${name}/${part}.jpg`)));
  if(maps.some(m=>m.status==='rejected')){for(const m of maps)if(m.status==='fulfilled')m.value.dispose();return false;}
  const textures=maps.map(m=>(m as PromiseFulfilledResult<T.Texture>).value);
  for(const t of textures){t.wrapS=t.wrapT=T.RepeatWrapping;t.repeat.copy(repeat);t.anisotropy=4;own(t);}
  textures[0].colorSpace=T.SRGBColorSpace;
  material.map=textures[0];material.normalMap=textures[1];material.roughnessMap=textures[2];material.normalScale.set(.45,.45);material.needsUpdate=true;
  return true;
}
