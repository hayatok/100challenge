import type { GridHints } from '../types';

/** Detect long, nearly continuous rules, not the total ink in a line of text.
 * Coordinates are in cropped-image pixels; thick rules collapse to their centre.
 */
export function detectGrid(pixels: Uint8ClampedArray, width: number, height: number): GridHints {
  if (!Number.isInteger(width) || !Number.isInteger(height) || width < 1 || height < 1 || pixels.length !== width * height * 4) {
    throw new Error('画像の画素データが不正です。画像を読み込み直してください。');
  }
  const ink = new Uint8Array(width * height);
  for (let i = 0; i < ink.length; i++) {
    const p = i * 4;
    const alpha = pixels[p + 3] / 255;
    const luminance = (pixels[p] * .2126 + pixels[p + 1] * .7152 + pixels[p + 2] * .0722) * alpha + 255 * (1 - alpha);
    ink[i] = luminance < 165 ? 1 : 0;
  }
  function project(horizontal: boolean): number[] {
    const length = horizontal ? width : height;
    const count = horizontal ? height : width;
    const candidates: { position: number; strength: number }[] = [];
    const toleratedGap = Math.max(1, Math.floor(length * .006));
    for (let pos = 0; pos < count; pos++) {
      let total = 0, start = -1, lastInk = -1, longest = 0;
      for (let offset = 0; offset < length; offset++) {
        const dark = horizontal ? ink[pos * width + offset] : ink[offset * width + pos];
        if (dark) {
          total++;
          if (start < 0) start = offset;
          lastInk = offset;
          longest = Math.max(longest, lastInk - start + 1);
        } else if (offset - lastInk > toleratedGap) start = -1;
      }
      if (total >= Math.max(16, length * .48) && longest >= Math.max(18, length * .55)) {
        candidates.push({ position: pos, strength: total });
      }
    }
    const edges: number[] = [];
    for (let i = 0; i < candidates.length;) {
      let weighted = 0, weight = 0, end = i;
      while (end < candidates.length && (end === i || candidates[end].position - candidates[end - 1].position <= 2)) {
        weighted += candidates[end].position * candidates[end].strength;
        weight += candidates[end].strength;
        end++;
      }
      edges.push(Math.round(weighted / weight));
      i = end;
    }
    return edges;
  }
  return { rowEdges: project(true), columnEdges: project(false) };
}
