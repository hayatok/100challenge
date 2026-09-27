# Verification — 2026-09-27

## Build and package

- `npm run ci:apps -- --apps-json '["2026-09-27"]'`: passed, clean `npm ci`.
- `npm run check:apps -- --apps-json '["2026-09-27"]'`: passed (`oxlint`, TypeScript, Vite build).
- Root `npm test`: 38/38 passed after updating the catalog count for the new app.
- `npm run build:site -- --prebuilt --apps-json '["2026-09-27"]' --reuse-from <existing .site>`: passed. `.site/2026-09-27/` contains HTML, JS/CSS, the model, and MediaPipe WASM.
- The official model download was 7,819,105 bytes, SHA-256 `fbc2a30080c3c557093b5ddfc334698132eb341044ccee322ccf8bcf3607cde1`.

## Browser interaction

- Chrome at 1200px: START screen and Mouse Mode rendered. A pointer sweep through the stack visibly moved multiple balls; the virtual hand followed the pointer.
- Packaged route `http://127.0.0.1:4173/2026-09-27/`: loaded from the site build; Mouse Mode again scattered the balls through collider contact.
- Debug panel showed render 60 FPS, physics step 0.5 ms, detected hands 0, object count 20 in this local run. These are observed values, not performance guarantees.
- 375, 768, and 1440px: start/playground layouts were checked in Chrome. No horizontal overflow was measured; primary controls remained visible.
- `tests/vision-smoke.html`: local WASM + model initialized, then a local sample image passed through `detectForVideo` via a canvas video stream. It returned one hand and 21 landmarks. `PerformanceResourceTiming` showed only `http://127.0.0.1:5173` as a resource origin during this smoke run.
- The native camera request remained pending even after Chrome permission was granted. A separate minimal `getUserMedia({video:true})` diagnostic also remained pending in this environment. The app's 12-second timeout displayed a clear camera failure and Mouse Mode remained available. **A physical hand moving live balls remains unverified**. Test this on a responsive webcam before treating Issue #121 as complete.

## Unverified

- Live webcam hand → virtual hand → moving balls, and camera preview quality.
- Safari, Firefox, mobile device input and performance.
- Whether MediaPipe SDK sends any delayed usage telemetry beyond the resource entries observed in this smoke test; the [official privacy notice](https://developers.google.com/edge/mediapipe/solutions/tasks) allows SDK metrics. Camera frames and landmarks have no application network path in the source.
