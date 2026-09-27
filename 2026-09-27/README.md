# Reality Sandbox

Webcam の片手で 3D の物体に触れ、上から落ちるボールを手のひらで受け止められるブラウザ内の物理プレイグラウンドです。

## Play

`FRONT CAMERA` または `REAR CAMERA` で始め、`PLAY BALL CATCH` を押すと12球のラウンドになります。光る縦線が落下位置です。3D 空間の水色の手のひらをその線の下へ動かし、落ちるボールを受け止めます。得点とミスを表示し、`RETRY` で再挑戦、`SANDBOX` で自由操作へ戻れます。指の操作はゲーム判定に使いません。手が認識されなくなるとラウンドを一時停止します。

カメラに対する手の見かけの大きさの変化から相対的な奥行きを推定します。最初に映った距離が「中央」です。手を近づけると仮想の手も手前へ動き、離すと奥へ動きます。判定しづらいときは `RECENTER DEPTH` でその距離を中央に合わせ直せます。3D の手は MediaPipe の21点を使って向きと形を描きますが、単眼カメラによる実距離の計測ではありません。

Sandbox では、カメラ小窓ではなく 3D 空間の水色の手を見ます。手をボールに重ねて横に払うとボールが飛びます。人差し指を伸ばすと黄色い点が現れ、その点でも弾けます。

プレイ中はプレビューのボタンでカメラを切り替えられます。カメラが使えない場合は `TRY WITH MOUSE` を選び、ポインターで同じように払います。操作パネルの `+ BALL`・`+ BOX`・`+ DOMINO` で 1 個ずつ追加できます。スマートフォン幅では `EDIT` を押すと操作パネルが開きます。`CLEAR ALL` は空の世界にし、`RESET 20` は初期のボール 20 個へ戻します。`LOAD 100` は 3 種類の混合プリセットを読み込みます。100 個が上限です。

## Run

```sh
npm ci
npm run dev
```

初回ビルドは `npm run prepare:assets` が公式 Hand Landmarker モデルを取得します。ローカルの `localhost` または HTTPS で起動してください。GitHub Pages 用には `npm run build` を実行し、`dist/` を `/100challenge/2026-09-27/` に配置します。`vite.config.ts` の相対 base により、日付サブパスからアセットを読み込みます。

## Architecture

- `src/vision`: MediaPipe の出力を正規化し、前面・背面カメラ取得、座標変換、相対奥行き推定、フリック検出を閉じ込める。
- `src/physics`: Rapier の固定 60 Hz 世界、3 種類の動的物体、手のひらと指先の kinematic collider、フリックと画面上の接触からの bounded impulse。
- `src/rendering`: Three.js のシーン、画面と奥行き平面の座標変換、3D 手モデル、落下ガイド。
- `src/game`: 12球の落下・キャッチ判定・得点・終了管理。
- `src/main.ts`: 開始状態、操作、平滑化、各更新周期、表示。

Tracking は約 30 Hz、physics は固定 60 Hz、render は `requestAnimationFrame`。手の位置は指数平滑化し、collider の 1 step の最大移動距離を制限します。前面カメラのみプレビューと x 座標を左右反転し、背面カメラは自然な向きで表示します。フリックは短いクールダウンと速度上限を使い、物理の固定 step に力を渡します。見た目では重なっていても奥行きの異なる物体に触れない問題を減らすため、描画された手と物体の画面上の交差も判定し、対象の物体へ補助 impulse を渡します。

## Privacy and assets

カメラフレームとランドマークはアプリの通信処理へ渡しません。MediaPipe Tasks 公式通知は SDK の利用メトリクス送信を記載しているため、通信ゼロとは表記しません。モデルと WASM は初回ビルドで固定し、アプリから同一オリジンで配信します。モデル約 7.8 MB、選択される WASM 約 11 MB に加えて JS と 3D ライブラリが必要で、初回ロード時間は回線と端末に依存します。GitHub Pages 側の HTTP キャッシュは配信設定に依存します。

MediaPipe Tasks package は Apache-2.0、Rapier は Apache-2.0、Three.js は MIT。Hand Landmarker モデルは [公式モデルカード](https://storage.googleapis.com/mediapipe-assets/Model%20Card%20Hand%20Tracking%20(Lite_Full)%20with%20Fairness%20Oct%202021.pdf)に Apache-2.0 の記載があります。取得元と実ファイル hash はビルドログに出力します。

`tests/hand-landmark-sample.jpg` は [Juan Pablo Serrano / Pexels](https://www.pexels.com/photo/person-s-right-hand-1257770/) の検証用画像です。製品画面や配信成果物には含めません。

## Current limits

対象は Desktop Chrome。iPhone の前面・背面カメラ操作は実機検証対象です。奥行きは手の見かけの幅から推定した相対値で、カメラからの実距離や正確な3D位置ではありません。21点の形は描画に使いますが、指ごとの物理 collider や掴む操作は未実装です。MediaPipe の同期推論による描画停止は性能検証対象です。背面カメラの選択には対応端末と HTTPS が必要です。
