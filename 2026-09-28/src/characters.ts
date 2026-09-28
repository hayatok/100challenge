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

type Color = [number, number, number];
type Palette = { shirt: Color; trousers: Color; skin: Color };

// The source has separate skinned outfit and body surfaces, but its albedo is
// predominantly red. The outfit includes both the shirt and trousers, so the
// rest-pose vertex height separates those garments without adding a new rig.
const palettes: Record<"clerk" | "nightClerk" | "worker" | "boss" | "lucky", Palette> = {
  clerk: { shirt: [0.44, 0.45, 0.39], trousers: [0.085, 0.105, 0.12], skin: [0.34, 0.36, 0.30] },
  nightClerk: { shirt: [0.27, 0.33, 0.36], trousers: [0.075, 0.09, 0.11], skin: [0.32, 0.35, 0.29] },
  worker: { shirt: [0.39, 0.32, 0.20], trousers: [0.11, 0.12, 0.12], skin: [0.33, 0.35, 0.28] },
  boss: { shirt: [0.20, 0.23, 0.24], trousers: [0.055, 0.065, 0.075], skin: [0.31, 0.34, 0.28] },
  lucky: { shirt: [0.37, 0.16, 0.43], trousers: [0.17, 0.07, 0.22], skin: [0.36, 0.34, 0.27] },
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
      if (material instanceof T.MeshPhysicalMaterial) {
        // The imported KHR_materials_specular requests 2x white specular.
        material.specularColor.setRGB(0.28, 0.28, 0.28);
        material.specularIntensity = 0.35;
      }
      const isOutfit = /Outfit/i.test(material.name);
      const isBody = /Body/i.test(material.name);
      // The third material is the actual eye and teeth geometry. Keep it
      // lighter than the skin so the face remains legible at game distance.
      if (!isOutfit && !isBody) {
        material.color.setRGB(0.52, 0.49, 0.40);
        material.metalness = 0;
        material.roughness = 0.9;
        return material;
      }
      // Green/blue carry the source's black grime. Excess red marks wounds;
      // maxRGB had promoted every red wound to bright gray noise.
      const color = isOutfit ? palette.shirt : palette.skin;
      const fragment = isOutfit ? `
        float grime = smoothstep(0.015, 0.16, (diffuseColor.g + diffuseColor.b) * 0.5);
        float wound = smoothstep(0.18, 0.40, diffuseColor.r - diffuseColor.g);
        float trousers = 1.0 - smoothstep(87.0, 103.0, vRestHeight);
        vec3 uniformColor = mix(vec3(${color.join(",")}), vec3(${palette.trousers.join(",")}), trousers);
        diffuseColor.rgb = mix(uniformColor * (0.52 + 0.46 * grime), vec3(0.21, 0.085, 0.070), wound * 0.42);
      ` : `
        float grime = smoothstep(0.04, 0.26, (diffuseColor.g + diffuseColor.b) * 0.5);
        float wound = smoothstep(0.18, 0.42, diffuseColor.r - diffuseColor.g);
        diffuseColor.rgb = mix(vec3(${color.join(",")}) * (0.43 + 0.52 * grime), vec3(0.24, 0.082, 0.067), wound * 0.52);
      `;
      material.color.setRGB(1, 1, 1);
      material.metalness = 0;
      material.roughnessMap = null;
      material.roughness = isOutfit ? 0.94 : 0.82;
      material.normalScale.set(0.32, 0.32);
      material.onBeforeCompile = (shader) => {
        if (isOutfit) {
          shader.vertexShader = shader.vertexShader
            .replace("#include <common>", "#include <common>\nvarying float vRestHeight;")
            .replace("#include <begin_vertex>", "#include <begin_vertex>\nvRestHeight = position.y;");
          shader.fragmentShader = shader.fragmentShader.replace(
            "#include <common>", "#include <common>\nvarying float vRestHeight;",
          );
        }
        shader.fragmentShader = shader.fragmentShader.replace(
          "#include <color_fragment>", `#include <color_fragment>${fragment}`,
        );
      };
      material.customProgramCacheKey = () => `v07-${paletteName}-${isOutfit ? "cloth" : "skin"}`;
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
