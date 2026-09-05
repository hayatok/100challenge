import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { expect, it } from "vitest";
const root = fileURLToPath(new URL("../../public/models/", import.meta.url));
it("ships all eighteen valid self-contained Blender GLBs at local origin", () => {
  const manifest = JSON.parse(readFileSync(root + "manifest.json", "utf8"));
  expect(manifest.generator).toContain("Blender");
  expect(Object.keys(manifest.assets)).toHaveLength(18);
  for (const asset of Object.values(manifest.assets) as {
    file: string;
    bytes: number;
    triangles: number;
  }[]) {
    const b = readFileSync(root + asset.file);
    expect(b.toString("ascii", 0, 4)).toBe("glTF");
    expect(b.readUInt32LE(4)).toBe(2);
    expect(b.readUInt32LE(8)).toBe(b.length);
    expect(b.length).toBe(asset.bytes);
    const json = JSON.parse(b.toString("utf8", 20, 20 + b.readUInt32LE(12)));
    expect(json.asset.generator).toContain("Blender");
    expect(json.buffers.every((v: { uri?: string }) => !v.uri)).toBe(true);
    expect(json.images ?? []).toHaveLength(0);
    for (const index of json.scenes[json.scene ?? 0].nodes) {
      const node = json.nodes[index];
      expect(node.translation ?? [0, 0, 0]).toEqual([0, 0, 0]);
    }
    expect(asset.triangles).toBeGreaterThan(0);
    expect(asset.triangles).toBeLessThan(10000);
    for (const a of json.accessors) {
      for (const x of [...(a.min ?? []), ...(a.max ?? [])])
        expect(Number.isFinite(x)).toBe(true);
    }
  }
});
