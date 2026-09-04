import { createServer } from "vite";
import { renderToStaticMarkup } from "react-dom/server";
import { createElement } from "react";
import { writeFile } from "node:fs/promises";
const server = await createServer({ server: { middlewareMode: true } });
try {
  const { default: Scene } = await server.ssrLoadModule("/src/Scene.tsx");
  const { createGame, depart, tick } = await server.ssrLoadModule(
    "/src/game/simulation.ts",
  );
  const { recordedInput } = await server.ssrLoadModule(
    "/src/game/recordings.ts",
  );
  let game = depart(createGame(1));
  while (game.status === "running" && game.lean < 0.86)
    game = tick(game, recordedInput(game, "catch"));
  let svg = renderToStaticMarkup(
    createElement(Scene, { game, reduced: true, compact: false }),
  );
  svg = svg.replace("<svg ", '<svg xmlns="http://www.w3.org/2000/svg" ');
  const style =
    "<style>svg{background:#fff4d4;font-family:sans-serif}.window-frame{fill:#fff4d4;stroke:#493526;stroke-width:3}.platform{stroke:#b09e7c}.station-name{fill:#69563c;stroke:none;font-size:20px}.distance{font-size:28px;font-weight:600;fill:#493526}.target-label{font-size:15px;fill:#493526}.shelf{fill:none;stroke:#493526;stroke-width:3}</style>";
  svg = svg.replace(/(<svg[^>]*>)/, "$1" + style);
  await writeFile("public/pudding-cover.svg", svg + "\n");
} finally {
  await server.close();
}
