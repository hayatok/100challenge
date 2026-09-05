import { useEffect, useRef } from "react";
import {
  GRID,
  pointAt,
  STATION,
  floorIndex,
  type Floor,
} from "./game/cleaning";
export function CleaningMap({
  floor,
  before = false,
}: {
  floor: Floor;
  before?: boolean;
}) {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const c = ref.current?.getContext("2d");
    if (!c) return;
    c.clearRect(0, 0, GRID, GRID);
    for (let i = 0; i < floor.cells.length; i++) {
      const p = pointAt(i);
      if (Math.hypot(p.x, p.z) > 28) continue;
      c.fillStyle = !before && floor.cells[i] ? "#f5eddc" : "#9282ae";
      c.fillRect(i % GRID, Math.floor(i / GRID), 1, 1);
    }
    const i = floorIndex(STATION);
    c.fillStyle = "#ed713b";
    c.fillRect((i % GRID) - 2, Math.floor(i / GRID) - 2, 4, 4);
  }, [floor, floor.version, before]);
  return (
    <canvas
      ref={ref}
      width={GRID}
      height={GRID}
      aria-label={
        before
          ? "出動前：汚れた床"
          : "今回掃除した場所の地図。クリーム色が清掃済み"
      }
      role="img"
    />
  );
}
