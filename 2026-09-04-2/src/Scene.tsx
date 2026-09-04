import { useEffect, useRef } from "react";
import type { Art } from "./art";
import type { Game } from "./game/simulation";
export default function Scene({
  art,
  game,
  reduced,
}: {
  art: Art;
  game: Game;
  reduced: boolean;
}) {
  const canvas = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const ctx = canvas.current?.getContext("2d");
    if (!ctx) return;
    const w = 1000,
      h = 640,
      stop = game.route[game.leg],
      distance = stop.length - game.x;
    ctx.clearRect(0, 0, w, h);
    ctx.fillStyle = "#f7e5b9";
    ctx.fillRect(0, 0, w, h);
    const background = art[`background-${stop.scenery}`];
    ctx.save();
    ctx.beginPath();
    ctx.rect(140, 100, 760, 300);
    ctx.clip();
    const shift = reduced ? 0 : (game.x * 2) % 760;
    ctx.drawImage(background, 0, 260, 1536, 764, 140 - shift, 100, 760, 340);
    ctx.drawImage(background, 0, 260, 1536, 764, 900 - shift, 100, 760, 340);
    if (distance < 150) {
      const x = reduced
        ? 140
        : 140 + Math.max(-760, Math.min(760, distance * 5));
      ctx.drawImage(
        art["background-station"],
        0,
        250,
        1536,
        774,
        x,
        100,
        760,
        340,
      );
      ctx.fillStyle = "#362719";
      ctx.font = "bold 19px sans-serif";
      ctx.textAlign = "center";
      ctx.fillText(stop.name, x + 526, 245, 135);
    }
    ctx.restore();
    ctx.drawImage(art["train-interior"], 0, 0, w, h);
    // All game-critical movement remains represented by the stability meter in reduced-motion mode.
    ctx.drawImage(art.plate, 265, 375, 470, 235);
    const lost = game.status === "lost",
      lean = reduced ? 0 : game.lean,
      slipping = game.slip * (game.lean > 0 ? 1 : -1);
    let frame = 0;
    if (game.status === "won" || game.status === "station") frame = 3;
    else if (game.slip > 0.45 || lost) frame = 2;
    else if (Math.abs(game.lean) > 0.4) frame = 1;
    const atlas = art["pudding-expressions"],
      scale = atlas.width / 1254;
    const frames = [
      [88, 80],
      [690, 80],
      [88, 665],
      [690, 665],
    ];
    ctx.save();
    ctx.translate(500 + (reduced ? 0 : slipping * 100), lost ? 560 : 492);
    ctx.rotate(lost && !reduced ? 0.95 : lean * 0.58);
    ctx.transform(1, 0, -lean * 0.22, 1, 0, 0);
    ctx.drawImage(
      atlas,
      frames[frame][0] * scale,
      frames[frame][1] * scale,
      480 * scale,
      510 * scale,
      -165,
      -330,
      330,
      330,
    );
    ctx.restore();
    if (Math.abs(game.lean) > 0.55 && !reduced) {
      ctx.strokeStyle = "#ae522b";
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.arc(
        490,
        310,
        190,
        game.lean > 0 ? -0.5 : 2.8,
        game.lean > 0 ? 0.05 : 3.4,
      );
      ctx.stroke();
    }
  }, [art, game, reduced]);
  return (
    <canvas
      ref={canvas}
      width={1000}
      height={640}
      role="img"
      aria-label={`車内のプリン。${game.slip > 0.45 ? "落下注意" : Math.abs(game.lean) > 0.4 ? "揺れています" : "安定しています"}。${game.route[game.leg].name}まで${Math.max(0, Math.round(game.route[game.leg].length - game.x))}m。`}
    />
  );
}
