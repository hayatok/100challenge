import * as T from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { clone } from "three/addons/utils/SkeletonUtils.js";
import type { EnemyKind } from "./game.ts";

type CharacterAsset = "city" | "thin" | "granny" | "creature";

export type CharacterInstance = {
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

const assets: Record<CharacterAsset, {
  file: string;
  name: string;
  height: number;
  floor: number;
  walk: string;
  idle?: string;
  attack?: string;
  hit?: string;
  death?: string;
}> = {
  city: {
    file: "zombie.glb", name: "City zombie", height: 1.795, floor: 0,
    walk: "Zombie_Walk", idle: "Zombie_Idle", attack: "Zombie_Attack",
    hit: "Zombie_Reaction_Hit", death: "Zombie_Dying",
  },
  thin: {
    file: "thin-zombie.glb", name: "Thin zombie", height: 1.799, floor: 0.032,
    walk: "walk", idle: "idle", attack: "attack1_l", hit: "hurt", death: "dead1",
  },
  granny: {
    file: "zombie-granny.glb", name: "Zombie granny", height: 1.763, floor: 0.002,
    walk: "Walk",
  },
  creature: {
    file: "horror-creature.glb", name: "Infected creature", height: 1.850, floor: 0.012,
    walk: "Walk", idle: "Idle",
  },
};

function assetFor(kind: EnemyKind, id: number): CharacterAsset {
  if (kind === "office") return id % 2 === 0 ? "granny" : "city";
  if (kind === "runner") return "thin";
  return "creature";
}

export async function loadCharacterLibrary(): Promise<CharacterLibrary> {
  const loader = new GLTFLoader();
  const loaded = {} as Record<CharacterAsset, Awaited<ReturnType<GLTFLoader["loadAsync"]>>>;
  await Promise.all((Object.keys(assets) as CharacterAsset[]).map(async (asset) => {
    loaded[asset] = await loader.loadAsync(
      `${import.meta.env.BASE_URL}assets/characters/${assets[asset].file}`,
    );
    loaded[asset].scene.traverse((object) => {
      if (!(object instanceof T.Mesh)) return;
      object.castShadow = true;
      // Skinning can extend outside the rest-pose bounds used for culling.
      object.frustumCulled = false;
      if (asset !== "city") return;
      for (const material of Array.isArray(object.material) ? object.material : [object.material]) {
        if (!(material instanceof T.MeshStandardMaterial)) continue;
        material.metalness = 0;
        material.roughness = 0.8;
        if (/Body/i.test(material.name)) {
          material.onBeforeCompile = (shader) => {
            shader.fragmentShader = shader.fragmentShader.replace(
              "#include <color_fragment>",
              "#include <color_fragment>\nfloat pallor=dot(diffuseColor.rgb,vec3(.299,.587,.114)); diffuseColor.rgb=mix(diffuseColor.rgb,vec3(pallor*1.15,pallor*1.28,pallor*1.17),.78);",
            );
          };
          material.customProgramCacheKey = () => "infected-skin-pallor-v1";
        }
      }
    });
  }));

  return {
    create(kind, id) {
      const asset = assetFor(kind, id);
      const spec = assets[asset];
      const source = loaded[asset];
      const model = new T.Group();
      const character = clone(source.scene);
      character.position.y = -spec.floor;
      model.add(character);
      const clip = (name?: string) => source.animations.find((item) => item.name === name);
      const walk = clip(spec.walk);
      if (!walk) throw new Error(`Missing walk animation in ${spec.file}`);
      return {
        model,
        clips: source.animations,
        height: spec.height,
        name: spec.name,
        walk,
        idle: clip(spec.idle),
        attack: clip(spec.attack),
        hit: clip(spec.hit),
        death: clip(spec.death),
      };
    },
  };
}
