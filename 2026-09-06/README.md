# まちあかりマート

**あの人が、今日も来た。**

120人の住人が暮らす街で、56日間の五つ星を目指すコンビニ経営ゲーム。Godot 4.7.2 / GDScript。品揃え、発注、価格、売り場、シフトを組み合わせて、廃棄・欠品・行列を改善します。

## 遊び方

- 1日6分。停止と1・2・4倍速で、考える時間を確保できます。
- お客さんを選ぶと、名前・性別・職業・好み・予算・価格感応度・来店時間・履歴が分かります。
- 注文は14時/翌6時に倉庫へ到着。スタッフが棚へ運び、レジで会計して売上になります。
- 3日連続黒字 → 常連8人 → 繁忙日の購買率 → 増床と2季節の週次黒字 → 14日間の五つ星審査。
- 星とともに80商品・20設備が解放。12人の雇用候補、12人の小さな物語、四季と3種類の繁忙イベントがあります。
- 失敗の原因は経営ノートへ。資金不足は売却や一度だけの融資で再建し、期限後は練習として続けられます。

Space: 停止/再開、1/2/4: 速度、B: 建設、P: 商品、R: 経営、Q: 建設の向き、Esc: 閉じる。店内ドラッグで移動、ホイールで拡大縮小。設定で主要キー・文字サイズ・音量・演出を変更できます。

## 開発・起動

```sh
npm ci
npm run setup       # Godot 4.7.2と公式エクスポートテンプレートを確認/取得
npm run dev         # Godotエディタ
npm run build       # Web版 -> dist/
npm run preview     # http://127.0.0.1:4196/
npm run build:mac   # macOSアプリ -> builds/macos/
```

既存のGodotは `GODOT_BIN` で指定可能です。アプリ本体にNode.jsは使わず、Nodeは起動とビルドの補助だけです。

## 検証

```sh
npm test
npm run test:ui
npm run balance                # 10seed × 6方針、全60通し試験
node scripts/godot.mjs balance --quick
npm run check
```

- コアの保存則・発注便・FIFO・会計・経路・勤務・期限・審査・再建・再開を検証。
- UI寸法検証は実描画確認と併用します。
- 攻略は通常のプレイヤー用コマンドのみ。成功した操作列は `docs/replay-*.json` に記録。
- 開発用の終盤確認は `Godot --headless --path game --script res://tests/prepare_qa.gd` で再生データを準備し、`Godot --path game -- --qa` で起動。通常の保存とは別のQAファイルを使用し、リリース出力にはテストコードを含めません。

企画・仕様・変更理由は [docs/PROPOSAL.md](docs/PROPOSAL.md)、[docs/SPEC.md](docs/SPEC.md)、[docs/SPEC_REVIEW.md](docs/SPEC_REVIEW.md)、検証の証拠は [docs/VERIFICATION.md](docs/VERIFICATION.md) に記録します。

Steamは目標品質の譬えであり、ストア提出・第三者試遊・クラウドセーブ等の手続きを対象にはしません。
