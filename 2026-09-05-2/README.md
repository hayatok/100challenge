# LOOP EATER 2D

「逃げ道を、わたしたちのステージに。」ImageGenの描き込み2Dアートを使ったGodot製の囲みアクション。雨灯横丁の1ステージを、導入からボス・結果・再挑戦まで遊べます。

旧3D実装・仕様書は開発対象から外し、プロジェクトを新規作成しました。旧版の保全場所は[開発計画](docs/PLAN.md)に記載しています。

## 遊び方

- WASD・矢印・パッド左スティック、またはクリックした地点へ移動。ドラッグ・タッチでも移動できます。
- 自分の6秒間の軌跡を横切ると、囲んだ敵を回収して8秒間の攻撃ステージを作ります。5体まとめるごとにHPを3回復（最大9）。
- 攻撃は自動。レベルアップでは戦闘が止まり、クリックまたは1〜3キーで強化を選びます。
- 2分30秒でボス登場。光る端子を囲むとシールドが10秒下がります。3分30秒までに撃破すればクリア。
- Escで停止・再開。別ウィンドウへの切り替えでも停止します。縦長のWeb画面は横向き案内を表示します。

## 起動・ビルド

Node.js 22以上とGodot 4.7.2 stableを使用します。macOSでは既存の`/Applications/Godot.app`を使い、別配置は`GODOT_BIN`で指定できます。Godot 4.7.2のWeb/macOS Export Templatesが必要です。Linux CI用の環境導入は`npm run setup`。

```sh
npm ci
npm run check
npm run preview
```

Webプレビュー: http://127.0.0.1:4185/ 。`file://`でHTMLを直接開かず、HTTPサーバー経由で利用してください。

```sh
npm run dev        # Godotエディタ
npm run build      # dist/index.html とWeb出力
npm run build:mac  # builds/macos/LOOP EATER.app
```

Mac版はローカル実行用のuniversalアプリです。一般配布向けの公証は対象外。Web版はCompatibility・単一スレッドで、WebGL 2対応ブラウザを使用します。

## 設計・素材・検証

- [新しい2D仕様書](docs/SPEC.md)
- [開発計画・旧版の退避先](docs/PLAN.md)
- [検証記録と制約](docs/VERIFICATION.md)
- [アートの品質基準](docs/ART_DIRECTION.md)
- [全ImageGenプロンプト](art/PROMPTS.md) / [生成元とSHA-256](art/manifest.json)

`game/core/`が描画に依存しないゲームルール、`game/main.gd`がUI・入力・保存、`game/stage_view.gd`が2D描画です。背景・キャラクター・敵・ボス・エフェクト・アイコン・キービジュアルはImageGen生成の6枚のPNG。PNGは無加工で保存し、Godotでアトラス参照・背景色の透過を行います。文字・可変バー・判定線はGodot描画、日本語フォントは同梱のNotoライセンスに従います。効果音はGodot内で合成します。

通常のWeb出力で検証用URLパラメータは無効です。`npm run build:debug`の場合のみ`?qa=loop|upgrade|boss|won|lost|stress`で画面や動作を確認できます。QAは左下に明示し、記録を書き込みません。`loop`は通常ルールの移動入力を再生し、強化選択で停止します。テスト本体は`npm test`で4つのseedを通常ルールで完走します。
