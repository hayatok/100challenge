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
  attacks: T.AnimationClip[];
  hits: T.AnimationClip[];
  deaths: T.AnimationClip[];
};

export type CharacterLibrary = {
  create(kind: EnemyKind, id: number, lucky?: boolean): CharacterInstance;
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

/** The supplied city dying clip is authored from the floor back to standing. */
export function reverseClip(source: T.AnimationClip, name: string): T.AnimationClip {
  const tracks = source.tracks.map((sourceTrack) => {
    const track = sourceTrack.clone();
    const originalTimes = Array.from(track.times);
    const originalValues = Array.from(track.values);
    const width = track.getValueSize();
    for (let i = 0; i < originalTimes.length; i++) {
      const from = originalTimes.length - 1 - i;
      track.times[i] = source.duration - originalTimes[from];
      for (let k = 0; k < width; k++) track.values[i * width + k] = originalValues[from * width + k];
    }
    return track;
  });
  return new T.AnimationClip(name, source.duration, tracks);
}

function cityDeathFall(source: T.AnimationClip): T.AnimationClip {
  const fall = reverseClip(source, "Zombie_Dying_Fall");
  const speed = 1.55 / fall.duration;
  for (const track of fall.tracks) {
    for (let i = 0; i < track.times.length; i++) track.times[i] *= speed;
    // The source's final pelvis is 29 cm underground. The floor at the
    // scene root remains fixed, so keep the fallen torso above pavement.
    if (track.name.endsWith("Hips.position") && track.getValueSize() === 3) {
      for (let i = 1; i < track.values.length; i += 3) track.values[i] = Math.max(20, track.values[i]);
    }
  }
  fall.duration = 1.55;
  return fall;
}

type Palette = { outfit: [number, number, number]; skin: [number, number, number] };

// All three uniforms use Rikindle3D's actual skinned shirt/trousers mesh.
// Remapping its blood-red albedo keeps seams, folds and wounds while giving
// each enemy a readable civilian/worker identity under the arcade lights.
const palettes: Record<"clerk" | "nightClerk" | "worker" | "boss" | "lucky", Palette> = {
  clerk: { outfit: [0.18, 0.22, 0.23], skin: [0.24, 0.29, 0.25] },
  nightClerk: { outfit: [0.23, 0.18, 0.17], skin: [0.23, 0.27, 0.24] },
  worker: { outfit: [0.27, 0.22, 0.13], skin: [0.23, 0.28, 0.23] },
  boss: { outfit: [0.14, 0.15, 0.17], skin: [0.22, 0.24, 0.22] },
  lucky: { outfit: [0.46, 0.18, 0.57], skin: [0.30, 0.29, 0.21] },
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
  let cityFall: T.AnimationClip | undefined;
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
  const originalFall = loaded.city.animations.find((item) => item.name === "Zombie_Dying");
  if (originalFall) cityFall = cityDeathFall(originalFall);

  return {
    create(kind, id, lucky = false) {
      const asset: CharacterAsset = lucky ? "city" : kind === "runner" ? "thin" : "city";
      const spec = assets[asset];
      const source = loaded[asset];
      const model = new T.Group();
      const character = clone(source.scene);
      character.position.y = -spec.floor;
      model.add(character);
      if (asset === "city") {
        const palette = lucky ? "lucky" : kind === "boss" ? "boss" : kind === "worker" ? "worker" : id % 2 ? "nightClerk" : "clerk";
        shadeCity(character, palette, cityMaterials);
        if (kind === "worker") character.scale.set(1.13, 1, 1.08);
        if (kind === "boss") character.scale.set(1.22, 1, 1.14);
      }
      const clip = (name?: string) => source.animations.find((item) => item.name === name);
      const walks = asset === "city"
        ? ["Zombie_Walk"]
        : ["walk", "walk2", "run"];
      const walk = clip(walks[(id + (kind === "worker" ? 1 : 0)) % walks.length]);
      if (!walk) throw new Error(`Missing walk animation in ${spec.file}`);
      // The scene chooses death actions from this list. The boss needs enough
      // time for his procedural kneel and collapse instead of the quick fall.
      const clips = kind === "boss"
        ? source.animations.filter((item) => !/death|dead|dying/i.test(item.name))
        : asset === "city" && cityFall
          ? [...source.animations.filter((item) => item.name !== "Zombie_Dying"), cityFall]
          : source.animations;
      const attacks = source.animations.filter((item) => /attack/i.test(item.name) && (asset !== "city" || item.name !== "Zombie_Attack2"));
      const hits = source.animations.filter((item) => /hit|hurt/i.test(item.name));
      const deaths = kind === "boss" ? [] : asset === "city" && cityFall
        ? [cityFall] : source.animations.filter((item) => /death|dead|dying/i.test(item.name));
      return {
        asset,
        model,
        clips,
        height: spec.height,
        name: lucky ? "Lucky dancer" : kind === "boss" ? "Infected shop owner" : kind === "worker" ? "Infected worker" : asset === "thin" ? "Thin zombie" : "City zombie",
        walk,
        idle: lucky ? clip("Zombie_Idle2") ?? clip(spec.idle) : clip(spec.idle),
        attack: attacks[(id + (kind === "worker" ? 1 : 0)) % attacks.length] ?? clip(spec.attack),
        hit: hits[0] ?? clip(spec.hit),
        death: deaths[0] ?? undefined,
        attacks,
        hits,
        deaths,
      };
    },
  };
}

export function chooseAttackClip(character: CharacterInstance, id: number, serial = 0): T.AnimationClip | undefined {
  return character.attacks[(id + serial) % character.attacks.length] ?? character.attack;
}

export function chooseDeathClip(character: CharacterInstance, id: number, variant = 0): T.AnimationClip | undefined {
  return character.deaths[(id + variant) % character.deaths.length] ?? character.death;
}
