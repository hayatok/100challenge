import * as T from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

/** Camera-local weapon. Its parent sits at (.29, -.32, -.65); muzzle is (0, .03, -.28). */
export async function createWeapon(): Promise<T.Group> {
  const loader = new GLTFLoader();
  const [pistolAsset, armsAsset] = await Promise.all([
    loader.loadAsync(`${import.meta.env.BASE_URL}assets/weapons/pistol.glb`),
    loader.loadAsync(`${import.meta.env.BASE_URL}assets/weapons/fps-arms.glb`),
  ]);

  const weapon = new T.Group();
  weapon.name = 'first-person-weapon';

  // The author's barrel runs along +X. After this turn the barrel faces camera -Z.
  // The loose spare magazine in the source preview is not part of the held weapon.
  const pistol = pistolAsset.scene;
  pistol.name = 'pistol';
  const spareMagazine = pistol.getObjectByName('Pistol_Magazine');
  if (spareMagazine) spareMagazine.visible = false;
  pistol.rotation.y = Math.PI / 2;
  pistol.scale.setScalar(1.2);
  pistol.position.set(0, -0.15, -0.10);
  pistol.traverse((object) => {
    if (object instanceof T.Mesh) {
      object.castShadow = true;
      object.frustumCulled = false;
    }
  });
  weapon.add(pistol);

  // Keep the detailed right arm and hand from the FPS rig. Its source mesh has
  // both arms in one symmetric skin; left-half triangles belong to the right arm.
  const arms = armsAsset.scene;
  arms.name = 'right-gloved-arm';
  const armMesh = arms.getObjectByName('caucasian_male_1Body');
  if (armMesh instanceof T.SkinnedMesh) {
    const geometry = armMesh.geometry.clone();
    const index = geometry.getIndex();
    const positions = geometry.getAttribute('position');
    if (index && positions) {
      const rightTriangles: number[] = [];
      for (let i = 0; i < index.count; i += 3) {
        const a = index.getX(i);
        const b = index.getX(i + 1);
        const c = index.getX(i + 2);
        if (positions.getX(a) + positions.getX(b) + positions.getX(c) < 0) {
          rightTriangles.push(a, b, c);
        }
      }
      geometry.setIndex(rightTriangles);
      geometry.computeBoundingSphere();
    }
    armMesh.geometry = geometry;
    const sourceMaterial = armMesh.material;
    if (sourceMaterial instanceof T.MeshStandardMaterial) {
      const glove = sourceMaterial.clone();
      glove.name = 'worn-dark-glove-and-sleeve';
      glove.color.set(0x30383a);
      glove.roughness = 0.9;
      glove.metalness = 0;
      armMesh.material = glove;
    }
    armMesh.castShadow = true;
    armMesh.frustumCulled = false;
  }

  // Bring the right forearm up from the lower-right edge. The original skin is
  // kept, so wrist and fingers still follow its authored skeleton and weights.
  const lowerRight = new T.Group();
  lowerRight.position.set(0.375, -0.33, 0.17);
  lowerRight.rotation.z = Math.PI;
  const faceCamera = new T.Group();
  faceCamera.rotation.y = Math.PI;
  arms.scale.setScalar(0.75);
  faceCamera.add(arms);
  lowerRight.add(faceCamera);
  weapon.add(lowerRight);

  return weapon;
}
