# Reality Sandbox

## Goal

Desktop Chrome で、片手の動きに追従する単一の手のひら collider が、3D 空間の物体を押す Sandbox を開発する。

## Scope

- Vite + TypeScript の静的アプリ。Three.js、Rapier、MediaPipe Hand Landmarker を責務別に配置する。
- モデルと WASM は `public/` に固定し、カメラ映像とランドマークは端末内で処理する。
- 20 個のボール、床、カメラプレビュー、状態表示、実測 debug 指標、Mouse Mode を用意する。
- ボール・箱・ドミノの追加、全消去、20 個への復元、100 個の負荷プリセットを扱う。上限は 100 個。
- Grab、指 collider、特殊ジェスチャー、ゲームモードは現在の対象外。

## Design

暗い実験空間と明るい物体で、手と衝突点をすぐ見分けられるようにする。操作部にはルート `docs/DESIGN.md` の意味色とフォーカス規則を使う。カメラ像は小さな鏡像プレビューに留める。

## Verification

`npm run check` で型・lint・build を確認し、実ブラウザで開始、許可拒否、Mouse Mode、カメラ追跡、ボールへの接触、画面幅を確認する。実カメラで未確認の項目は明示する。
