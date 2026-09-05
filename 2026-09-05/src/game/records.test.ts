import { expect, it } from "vitest";
import { bestRecord, saveRecord } from "./records";
it("treats missing, corrupt, unavailable and out-of-range records as safe defaults", () => {
  for (const data of [
    null,
    "broken",
    '{"kills":-1}',
    '{"kills":1e100}',
    '{"kills":"30"}',
  ])
    expect(bestRecord(() => data).kills).toBe(0);
  expect(
    bestRecord(() => {
      throw new Error("disabled");
    }),
  ).toEqual({ kills: 0, cleared: false });
  expect(bestRecord(() => '{"kills":1234,"cleared":true}')).toEqual({
    kills: 1234,
    cleared: true,
  });
});
it("round-trips records and reports write failures without crashing a run", () => {
  let saved = "";
  expect(
    saveRecord({ kills: 42, cleared: true }, (s) => {
      saved = s;
    }),
  ).toBe(true);
  expect(bestRecord(() => saved)).toEqual({ kills: 42, cleared: true });
  expect(
    saveRecord({ kills: 42, cleared: true }, () => {
      throw new Error("quota");
    }),
  ).toBe(false);
});
