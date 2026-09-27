# Reality Sandbox — Vertical Slice v0

## Goal / Done when

Desktop Chrome で START からカメラを許可し、片手を左右へ動かすと、画面の仮想手が追従して20個のボールを実際に弾ける。カメラ不能時は Mouse Mode で同じ物理世界を試せる。静的成果物を GitHub Pages の `/100challenge/2026-09-27/` に配置できる。

## Implementation

1. Three.js の世界と Rapier の固定 60 Hz 物理世界を分離し、ボール描画を物理 body に同期する。
2. MediaPipe Hand Landmarker を VIDEO モードで最大約30 Hz動かし、21点から手のひら中心だけを正規化状態として取り出す。
3. 鏡像カメラの x を反転し、Three.js の投影レイと物理平面の交点へ変換。追跡位置を平滑化し、1 step の移動量を制限して kinematic body の next translation に渡す。
4. 開始・ロード・追跡待ち・失敗状態、カメラプレビュー、FPS 表示、Mouse Mode を接続する。
5. build、実ブラウザ操作、カメラ入力、通信、複数幅を検証する。

## Constraints

- モデルと MediaPipe WASM は同一オリジンの静的ファイルとして配信する。動画フレームと手の座標はアプリの通信処理へ渡さない。
- 追跡推論は同期 API なので 30 Hz に制限する。UI停止が体感される場合は別 Issue で Worker 化を検討する。
- この段階では手のひら Sphere Collider 1個と「押す」のみ。掴む、指、魔法は後続。
- MediaPipe Tasks は入力映像を端末内で処理するが、公式通知は SDK 利用メトリクス送信を記載する。画面では「カメラ映像は端末で処理」と正確に伝える。

## Source decisions

- [MediaPipe Hand Landmarker Web guide](https://developers.google.com/edge/mediapipe/solutions/vision/hand_landmarker/web_js): `@mediapipe/tasks-vision`、VIDEO mode、`detectForVideo`、同一オリジンのモデル指定。
- [MediaPipe Tasks privacy notice](https://developers.google.com/edge/mediapipe/solutions/tasks): 入力映像の端末内処理と SDK メトリクス。
- [Rapier kinematic body guide](https://rapier.rs/docs/user_guides/javascript/rigid_body_type/): 位置制御 kinematic と dynamic body の接触。
- [Rapier RigidBody API](https://rapier.rs/javascript3d/classes/RigidBody.html): `setNextKinematicTranslation`。
- [Vite static deploy](https://vite.dev/guide/static-deploy): GitHub Pages の base path。
