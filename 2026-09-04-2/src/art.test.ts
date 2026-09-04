import { expect, it } from "vitest";
import { shouldKey } from "./art";
it("keys painted checkerboard and window without erasing custard, ceramic or outline", () => {
  expect(shouldKey(255, 255, 255, "paper")).toBe(true);
  expect(shouldKey(235, 237, 240, "paper")).toBe(true);
  for (const p of [
    [250, 200, 95],
    [245, 225, 174],
    [54, 39, 25],
    [110, 153, 133],
  ])
    expect(shouldKey(p[0], p[1], p[2], "paper")).toBe(false);
  expect(shouldKey(255, 0, 255, "window")).toBe(true);
  expect(shouldKey(245, 220, 164, "window")).toBe(false);
});
