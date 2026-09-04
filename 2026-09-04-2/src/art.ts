export type Art = Record<string, HTMLCanvasElement>;
const names = [
  "pudding-expressions",
  "plate",
  "train-interior",
  "background-residential",
  "background-bridge",
  "background-station",
];
/** Source files stay untouched. Key the generated backdrop when preparing render textures. */
export function shouldKey(
  r: number,
  g: number,
  b: number,
  mode: "paper" | "window",
) {
  return mode === "window"
    ? r > 170 && b > 150 && g < 130
    : Math.min(r, g, b) > 185 && Math.max(r, g, b) - Math.min(r, g, b) < 24;
}
export async function loadArt(): Promise<Art> {
  const entries = await Promise.all(
    names.map(async (name) => {
      const img = new Image();
      img.src = `./art/${name}.png`;
      await img.decode();
      const canvas = document.createElement("canvas");
      canvas.width = img.width;
      canvas.height = img.height;
      const ctx = canvas.getContext("2d")!;
      ctx.drawImage(img, 0, 0);
      if (["pudding-expressions", "plate", "train-interior"].includes(name)) {
        const pixels = ctx.getImageData(0, 0, canvas.width, canvas.height);
        const mode = name === "train-interior" ? "window" : "paper";
        for (let i = 0; i < pixels.data.length; i += 4)
          if (
            shouldKey(
              pixels.data[i],
              pixels.data[i + 1],
              pixels.data[i + 2],
              mode,
            )
          )
            pixels.data[i + 3] = 0;
        ctx.putImageData(pixels, 0, 0);
      }
      return [name, canvas] as const;
    }),
  );
  return Object.fromEntries(entries);
}
