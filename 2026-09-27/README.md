# Reality Sandbox

Webcam の片手で 3D の物体を押せる、ブラウザ内の物理プレイグラウンドです。手のひら 1 点の collider でボール・箱・ドミノに触れます。

## Play

Camera で始めるか Mouse Mode を選び、手またはポインターを物体へ動かします。操作パネルの `+ BALL`・`+ BOX`・`+ DOMINO` で 1 個ずつ追加できます。`CLEAR ALL` は空の世界にし、`RESET 20` は初期のボール 20 個へ戻します。`LOAD 100` は 3 種類の混合プリセットを読み込みます。100 個が上限です。

## Run

```sh
npm ci
npm run dev
```

初回ビルドは `npm run prepare:assets` が公式 Hand Landmarker モデルを取得します。ローカルの `localhost` または HTTPS で起動してください。GitHub Pages 用には `npm run build` を実行し、`dist/` を `/100challenge/2026-09-27/` に配置します。`vite.config.ts` の相対 base により、日付サブパスからアセットを読み込みます。

## Architecture

- `src/vision`: MediaPipe の出力を手のひら中心へ縮約。カメラ取得と検出はここに閉じ込める。
- `src/physics`: Rapier の固定 60 Hz 世界、3 種類の動的物体、単一の kinematic hand collider。
- `src/rendering`: Three.js のシーンと、画面座標から衝突平面への投影。
- `src/main.ts`: 開始状態、操作、平滑化、各更新周期、表示。

Tracking は約 30 Hz、physics は固定 60 Hz、render は `requestAnimationFrame`。手の位置は指数平滑化し、collider の 1 step の最大移動距離を制限します。カメラ像は鏡像プレビューにし、x 座標も反転させます。

## Privacy and assets

カメラフレームとランドマークはアプリの通信処理へ渡しません。MediaPipe Tasks 公式通知は SDK の利用メトリクス送信を記載しているため、通信ゼロとは表記しません。モデルと WASM は初回ビルドで固定し、アプリから同一オリジンで配信します。モデル約 7.8 MB、選択される WASM 約 11 MB に加えて JS と 3D ライブラリが必要で、初回ロード時間は回線と端末に依存します。GitHub Pages 側の HTTP キャッシュは配信設定に依存します。

MediaPipe Tasks package は Apache-2.0、Rapier は Apache-2.0、Three.js は MIT。Hand Landmarker モデルは [公式モデルカード](https://storage.googleapis.com/mediapipe-assets/Model%20Card%20Hand%20Tracking%20(Lite_Full)%20with%20Fairness%20Oct%202021.pdf)に Apache-2.0 の記載があります。取得元と実ファイル hash はビルドログに出力します。

`tests/hand-landmark-sample.jpg` は [Juan Pablo Serrano / Pexels](https://www.pexels.com/photo/person-s-right-hand-1257770/) の検証用画像です。製品画面や配信成果物には含めません。

## Current limits

対象は Desktop Chrome。奥行きは固定の衝突平面を使い、現実の手の距離は推定しません。掴む、指先、ジェスチャー、スマートフォン最適化は未実装です。MediaPipe の同期推論による描画停止は性能検証対象です。
