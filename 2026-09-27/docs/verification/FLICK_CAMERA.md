# 操作ガイド・フリック・カメラ切り替えの検証（2026-09-27）

## 自動チェック

- `npm run check`: 操作テスト 6 件、lint、型検査、Vite build が成功。
- 6 件には前面・背面の x 座標、手のひらフリックのノイズとクールダウン、人差し指の相対移動、伸ばした指の判定、切り替え失敗時の前カメラ復帰、固定物理 step の impulse を含む。
- ルート `npm test`: 共通スクリプト 38 件が成功。
- `git diff --check`: 成功。
- Pages 用の `.site/2026-09-27/` を組み立て、HTML と同一オリジンの Hand Landmarker モデル（7,819,105 bytes）がローカル HTTP 200。

## ブラウザ操作

- Chrome で開始画面の PALM / FINGER の 2 ステップと、FRONT CAMERA / REAR CAMERA / TRY WITH MOUSE を確認。
- Mouse Mode で横方向へ速くポインターを払うと `PALM SWIPE!` が表示され、近くの物体が動く。
- `LOAD 100` で 100/100 を確認し、追加ボタンが無効になる。
- 背面カメラのない Desktop 環境で `REAR CAMERA` を選ぶと、代替操作を案内するエラーが表示される。
- 375×812 の開始画面とプレイ画面で、案内・主操作の欠落や横スクロールはない。通常の Desktop 幅でも開始・プレイ画面を確認。
- 配信用の静的ビルドを Chrome で開き、Mouse Mode と 100 物体の操作を確認。
- 同梱の手の画像を使うローカルの smoke ページで、MediaPipe の 21 ランドマークと人差し指座標を確認。

## 未確認

- 実際の手による前面・背面カメラの切り替え、指フリックの操作感は、iPhone 実機で未確認。
- iPhone Safari の推論速度、熱、横画面、長時間使用は未確認。
- カメラ入力が拒否された場合の Mouse Mode は UI の復帰経路を実装したが、実際の権限ダイアログを使う操作確認は行っていない。

背面カメラの選択には `facingMode: { exact: 'environment' }` を使い、切り替え前に旧 track を止める。これは [MDN のカメラ選択ガイド](https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia)に沿う。機器が報告する向きは [MediaTrackSettings.facingMode](https://developer.mozilla.org/en-US/docs/Web/API/MediaTrackSettings/facingMode) でも確認する。
