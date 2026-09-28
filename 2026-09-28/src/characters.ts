import * as T from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { clone } from "three/addons/utils/SkeletonUtils.js";
import type { EnemyKind } from "./game.ts";

/** The authored rig used by a character, independent of its outfit variant. */
export type CharacterAsset = "city" | "thin";

export type CharacterInstance = {
  asset: CharacterAsset;
  model: T.Group;
  clips: T.AnimationClip[];
  height: number;
  name: string;
  walk: T.AnimationClip;
  idle?: T.AnimationClip;
  attack?: T.AnimationClip;
  hit?: T.AnimationClip;
  death?: T.AnimationClip;
};

export type CharacterLibrary = {
  create(kind: EnemyKind, id: number): CharacterInstance;
};

const assets = {
  city: {
    file: "zombie.glb", height: 1.795, floor: 0,
    walk: "Zombie_Walk", idle: "Zombie_Idle", attack: "Zombie_Attack",
    hit: "Zombie_Reaction_Hit", death: "Zombie_Dying",
  },
  thin: {
    file: "thin-zombie.glb", height: 1.799, floor: 0.032,
    walk: "walk", idle: "idle", attack: "attack1_l", hit: "hurt", death: "dead1",
  },
} as const;

type Palette = { outfit: [number, number, number]; skin: [number, number, number] };

// All three uniforms use Rikindle3D's actual skinned shirt/trousers mesh.
// Remapping its blood-red albedo keeps seams, folds and wounds while giving
// each enemy a readable civilian/worker identity under the arcade lights.
const palettes: Record<"clerk" | "nightClerk" | "worker" | "boss", Palette> = {
  clerk: { outfit: [0.18, 0.22, 0.23], skin: [0.24, 0.29, 0.25] },
  nightClerk: { outfit: [0.23, 0.18, 0.17], skin: [0.23, 0.27, 0.24] },
  worker: { outfit: [0.27, 0.22, 0.13], skin: [0.23, 0.28, 0.23] },
  boss: { outfit: [0.14, 0.15, 0.17], skin: [0.22, 0.24, 0.22] },
};

function shadeCity(
  model: T.Object3D,
  paletteName: keyof typeof palettes,
  cache: Map<string, T.Material>,
): void {
  const palette = palettes[paletteName];
  model.traverse((object) => {
    if (!(object instanceof T.Mesh)) return;
    const oldMaterials = Array.isArray(object.material) ? object.material : [object.material];
    const materials = oldMaterials.map((original) => {
      const key = `${original.uuid}:${paletteName}`;
      const cached = cache.get(key);
      if (cached) return cached;
      const material = original.clone();
      cache.set(key, material);
      if (!(material instanceof T.MeshStandardMaterial)) return material;
      const isOutfit = /Outfit/i.test(material.name);
      const color = isOutfit ? palette.outfit : palette.skin;
      // The red texture has almost no green or blue. A multiplier cannot turn
      // it into cloth or pallid skin; use its tonal detail instead.
      const fragment = `
        float sourceTone = max(diffuseColor.r, max(diffuseColor.g, diffuseColor.b));
        float surfaceDetail = 0.05 + pow(sourceTone, 0.8) * 1.05;
        diffuseColor.rgb = vec3(${color.join(",")}) * surfaceDetail;
      `;
      material.color.setRGB(1, 1, 1);
      material.metalness = 0;
      material.roughness = isOutfit ? 0.96 : 0.89;
      material.onBeforeCompile = (shader) => {
        shader.fragmentShader = shader.fragmentShader.replace(
          "#include <color_fragment>", `#include <color_fragment>${fragment}`,
        );
      };
      material.customProgramCacheKey = () => `v04-${paletteName}-${isOutfit ? "cloth" : "skin"}`;
      return material;
    });
    object.material = Array.isArray(object.material) ? materials : materials[0];
  });
}

export async function loadCharacterLibrary(): Promise<CharacterLibrary> {
  const loader = new GLTFLoader();
  const loaded = {} as Record<CharacterAsset, Awaited<ReturnType<GLTFLoader["loadAsync"]>>>;
  const cityMaterials = new Map<string, T.Material>();
  await Promise.all((Object.keys(assets) as CharacterAsset[]).map(async (asset) => {
    loaded[asset] = await loader.loadAsync(
      `${import.meta.env.BASE_URL}assets/characters/${assets[asset].file}`,
    );
    loaded[asset].scene.traverse((object) => {
      if (!(object instanceof T.Mesh)) return;
      object.castShadow = true;
      object.frustumCulled = false;
      if (asset === "thin") {
        for (const material of Array.isArray(object.material) ? object.material : [object.material]) {
          if (material instanceof T.MeshStandardMaterial) {
            material.metalness = 0;
            material.roughness = 0.9;
            material.color.multiplyScalar(0.78);
          }
        }
      }
    });
  }));

  return {
    create(kind, id) {
      const asset: CharacterAsset = kind === "runner" ? "thin" : "city";
      const spec = assets[asset];
      const source = loaded[asset];
      const model = new T.Group();
      const character = clone(source.scene);
      character.position.y = -spec.floor;
      model.add(character);
      if (asset === "city") {
        const palette = kind === "boss" ? "boss" : kind === "worker" ? "worker" : id % 2 ? "nightClerk" : "clerk";
        shadeCity(character, palette, cityMaterials);
        if (kind === "worker") character.scale.set(1.13, 1, 1.08);
        if (kind === "boss") character.scale.set(1.22, 1, 1.14);
      }
      const clip = (name?: string) => source.animations.find((item) => item.name === name);
      const walk = clip(spec.walk);
      if (!walk) throw new Error(`Missing walk animation in ${spec.file}`);
      // The scene chooses death actions from this list. The boss needs enough
      // time for his procedural kneel and collapse instead of the quick fall.
      const clips = kind === "boss"
        ? source.animations.filter((item) => !/death|dead|dying/i.test(item.name))
        : source.animations;
      return {
        asset,
        model,
        clips,
        height: spec.height,
        name: kind === "boss" ? "Infected shop owner" : kind === "worker" ? "Infected worker" : asset === "thin" ? "Thin zombie" : "City zombie",
        walk,
        idle: clip(spec.idle),
        attack: clip(spec.attack),
        hit: clip(spec.hit),
        death: kind === "boss" ? undefined : clip(spec.death),
      };
    },
  };
}
