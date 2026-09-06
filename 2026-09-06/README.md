# まちあかりマート

**あの人が、今日も来た。**

現在はアルファ版を土台にベータ版を開発中です。未完了の品質項目と検証は [BETA_PLAN.md](docs/BETA_PLAN.md) に記録します。

120人の住人が暮らす街で、56日間に五つ星と「冬の約束」の達成を目指すコンビニ経営ゲーム。Godot 4.7.2 / GDScript。品揃え、発注、価格、売り場、シフトを組み合わせて、廃棄・欠品・行列を改善します。

## 遊び方

- 1日6分。停止と1・2・4倍速で、考える時間を確保できます。
- お客さんを選ぶと、名前・性別・職業・好み・予算・価格感応度・来店時間・履歴が分かります。
- 注文は通常14時/翌6時に倉庫へ到着。遅延日はカレンダーで予告。スタッフが棚へ運び、レジで会計して売上になります。
- 3日連続黒字 → 常連8人 → 繁忙日の購買率 → 増床と2季節の週次黒字 → 14日間の五つ星審査。
- 星とともに80商品・20設備が解放。12人の雇用候補、12人の小さな物語、四季の催事と配送事情があります。
- 29〜42日目に朝食・夜勤・おやつの約束を選び、冬の4日間に目的の商品を届けます。五つ星を取った後も本編は56日間続きます。
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
npm run test:circulation        # 入口・列・会計位置・旧配置の回帰検証
npm run test:flow               # 棚の順番待ち・追加購入・店員の退避
npm run test:campaign           # 冬の約束・会計集計・56日目の結末
npm run balance                # 10seed × 8方針（ベータの全件監査は進行中）
node scripts/godot.mjs balance --quick
npm run check
```

- コアの保存則・発注便・FIFO・会計・経路・勤務・期限・審査・再建・再開を検証。
- UI寸法検証は実描画確認と併用します。
- 攻略は通常のプレイヤー用コマンドのみ。`--record-replays` 指定時だけ成功した操作列を保存します。既存の `docs/replay-*.json` はアルファ版の履歴で、ベータ版の成立証拠ではありません。
- 初期seedのベータ8方針比較は `docs/beta-winter-probes.json`。3つの約束すべての達成例がありますが、複数seed・本編品質の全監査は未完了です。
- 現在の通常営業からQAを作る場合は `Godot --headless --path game --script res://tools/prepare_city_qa.gd -- 57 sweets`。`29 staples` で選択可能な秋、`res://tools/prepare_flow_qa.gd` で棚の列を確認できます。準備は順番に実行し、`Godot --path game -- --qa` で起動します。
- 開発用の終盤確認は `Godot --headless --path game --script res://tests/prepare_qa.gd` で再生データを準備し、`Godot --path game -- --qa` で起動。通常の保存とは別のQAファイルを使用し、リリース出力にはテストコードを含めません。

企画・仕様・変更理由は [docs/PROPOSAL.md](docs/PROPOSAL.md)、[docs/SPEC.md](docs/SPEC.md)、[docs/SPEC_REVIEW.md](docs/SPEC_REVIEW.md)、検証の証拠は [docs/VERIFICATION.md](docs/VERIFICATION.md) に記録します。

Steamは目標品質の譬えであり、ストア提出・第三者試遊・クラウドセーブ等の手続きを対象にはしません。
