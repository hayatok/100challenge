import * as T from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

/** Camera-local weapon. The scene owns aim/recoil; this group owns the moving slide. */
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

  // The source rig has straight, spread fingers. Curl its existing phalanges
  // around the grip; all skin stays bound to the original hand and forearm.
  for (const [name, baseCurl, middleCurl] of [
    ['index', 0.62, 0.2],
    ['middle', 1.02, 0.38],
    ['ring', 1.08, 0.42],
    ['pinky', 1.12, 0.43],
  ] as const) {
    const base = arms.getObjectByName(`f_${name}.01.R`);
    const middle = arms.getObjectByName(`f_${name}.02.R`);
    if (base) base.rotation.z -= baseCurl;
    if (middle) middle.rotation.z -= middleCurl;
  }

  // Bring the palm below the slide and beside the grip, so the curled fingers
  // sit behind the trigger guard instead of reaching over the barrel.
  const lowerRight = new T.Group();
  lowerRight.position.set(0.415, -0.35, 0.11);
  lowerRight.rotation.z = Math.PI;
  const faceCamera = new T.Group();
  faceCamera.rotation.y = Math.PI;
  arms.scale.setScalar(0.75);
  faceCamera.add(arms);
  lowerRight.add(faceCamera);
  weapon.add(lowerRight);

  return weapon;
}

/** Slide travels along source -X (toward the camera after the pistol's Y turn). */
export function animateWeapon(weapon: T.Group, recoil: number, finishing = false, motion = true): void {
  const pistol = weapon.getObjectByName('pistol');
  if (!pistol) return;
  const amount = T.MathUtils.clamp(recoil, 0, 1);
  const travel = amount * (motion ? finishing ? 0.067 : 0.052 : 0.012);
  for (const name of ['Pistol_Slide', 'Pistol_Slide4']) {
    const slide = pistol.getObjectByName(name);
    if (!slide) continue;
    if (typeof slide.userData.restX !== 'number') slide.userData.restX = slide.position.x;
    slide.position.x = slide.userData.restX - travel;
  }
}
