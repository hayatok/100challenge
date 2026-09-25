# Sol向け実装手順

## 実装の前提

この手順は実装開始時に作成した。アプリ本体は2026-09-25に実装し、検証記録は `docs/verification/RESULTS.md` に残す。名称は「動く表紙の試着室」。ユーザーはブラウザ内で完結し、簡単な操作から驚きのあるタイポグラフィーとモーションを作れるアプリを希望している。

アプリ固有ファイルは `2026-09-25/` に置く。共有ファイルの変更は、完成後の `apps.json` 登録や既存一覧への統合に必要な最小限とする。過去の日付フォルダをコピーして不要な依存を持ち込まない。

## フェーズ0: 現状確認と土台

1. ルートAGENTSと3つの共有設計文書、本フォルダの仕様を読む。Git状態を確認し、既存変更を保持する。
2. 既存アプリ `2026-09-01/` をブラウザで確認する。今回のアプリが既に実装され始めている場合は、その現在画面も確認する。
3. 専用の `codex/` ブランチを使用。並行作業や実験でworktreeが必要なら、**未コミットの本設計書がworktreeへ自動で付いてこない**点に注意し、設計書を確実に引き継ぐ。
4. Vite/React/TSの最小構成、CSSトークン、p5ホスト、フォント、Vitestを作る。TECHNICAL_DESIGNの依存は用途が確定済み。追加依存が必要なら理由を記録する。
5. この時点ではapps.jsonへ登録しない。ビルド不能のフォルダを全体CIへ流さない。

**通過条件:** 日本語の固定文字と図形をブラウザに描け、同じ時刻を再描画して一致。フォントのローカル配信とサブパスを確認。

## フェーズ1: 1作品を完成させ、実動画を出す

H1「織る・余白の、その先。」を先に実装。正方形と縦長の静止構図を整えてから周期モーションを加える。PNGとMediabunnyによる6秒動画出力まで通す。ここでp5のAPI・フォント・codec・描画性能の不確実性を解消する。

**通過条件:** H1のPNG・実MP4をダウンロードして開き、文字・動き・ループを確認。720pxは必須、1080縦長も実測。解決前に多機能な操作画面へ進まない。

問題が出たときの判断順は、p5 hostの契約修正 → mask/キャッシュ見直し → プレビュー更新数削減。p5固有の障害が残る場合に限り、同じCanvas2D描画APIを直接使用する代替へ設計変更できる。製品の3表現・探索・出力を勝手に削らない。変更理由と実証結果を文書へ残す。

## フェーズ2: 3表現と4候補

H2/H3を作り、各3構図まで広げる。文字layoutを共通化し、9構図の違いを確認する。seed生成、初期4候補、選択プレビュー、入力draft/commit、比率・表現フィルタを実装する。

**通過条件:** 同じ日本語が入った4枚から実際に選べる。配色を取り除いても3表現が区別でき、文字が短い/長いケースも破綻しない。placeholderのカード画像や固定動画で代用しない。

## フェーズ3: 固定して別案、手動調整、履歴

4domainの固定と近傍生成を実装。変更点ラベル、全固定、候補不足を含む。手動編集の適用/取り消し、immutable recipe、候補セットの親子履歴を追加する。

**通過条件:** U04〜U07とB02が通り、AからBを試してAへ戻ってCを作れる。Bが消えない。固定した設定が変わらない。

## フェーズ4: 保存・出力・エラーと狭い画面

IndexedDB、お気に入り、JSON入出力、revision競合、容量エラーを実装。動画の能力表示・進捗・キャンセル・失敗復帰を完成させる。ネイティブdialog、キーボード、reduced-motion、4画面幅を仕上げる。

**通過条件:** リロード後も前の確定作品が戻る。JSONを他のクリーンな保存領域へ読込んで再現できる。動画非対応環境も制作とPNG/JSONを使える。保存失敗を成功扱いしない。

## フェーズ5: 完成検証と一覧への統合

TEST_PLANの必須項目を実施し、代表画像と実動画を目視。未検証項目を記録。完成後、apps.jsonに以下を追加する。

```json
{
  "id": "2026-09-25",
  "date": "2026-09-25",
  "sequence": 1,
  "name": "動く表紙の試着室",
  "description": "言葉を入れて4案から選ぶ。好きな部分を残して試せる、動く表紙の制作室。",
  "category": "モーショングラフィックス",
  "thumbnail": "moving-cover-studio.png",
  "accent": "#C94332"
}
```

サムネイルは完成アプリのH1〜H3から作り、`2026-09-25/public/moving-cover-studio.png` に置く。Viteがdist直下へコピーし、既存の `showcase/showcase.js` はアプリのURLにthumbnailを連結して参照する。アプリの素材原本と生成手順も本フォルダ内に保持する。

### 必須のapp scripts

```json
{
  "dev": "vite",
  "setup": "playwright install --with-deps chromium && node scripts/setup-video-tools.mjs",
  "typecheck": "tsc -b",
  "lint": "oxlint src tests",
  "test": "vitest run",
  "test:e2e": "playwright test --project=chromium",
  "build": "tsc -b && vite build",
  "check": "npm run lint && npm run test && npm run build && npm run test:e2e",
  "preview": "vite preview"
}
```

Vitestはunitのみをincludeし、Playwrightのtestファイルを拾わない。Playwright webServerはビルド済みdistをVite previewで提供し、ポートを固定する。CIではreuseExistingServerをfalse。E2Eの書き出し待機に実測に合う上限を設定し、失敗画像/traceを記録する。setupはルートの `ci:apps` がnpm ci後に呼び出す既存契約を利用できる。

### 実装後に実行するコマンド

アプリフォルダで初回は依存導入後にsetup。以降のクリーン環境ではnpm ciを使う。

```sh
cd /Users/hayatok/Documents/dev/100challenge/2026-09-25
npm ci
npm run setup
npm run check
```

登録後、ルートで対象アプリと共有のレジストリ処理を確認する。

```sh
cd /Users/hayatok/Documents/dev/100challenge
npm test
npm run check:apps -- --apps-json '["2026-09-25"]'
git diff --check
```

上記は同じcheckを2度実行するため、1回の検証報告で両方を機械的に繰り返す必要はない。最終版をルートの対象指定で1回通せばよい。

一覧の差分組み立てはルートREADMEに従う。既存成果物 `.pages-baseline/site` を取得・確認できている場合のみ、次を使用する。

```sh
npm run build:site -- --prebuilt --apps-json '["2026-09-25"]' --reuse-from .pages-baseline/site
```

baselineがない場合はルートの通常 `npm run build:site` を使う。存在しないディレクトリを指定したり、対象以外のアプリを空にして通さない。完成した一覧と `/2026-09-25/` をブラウザで確認する。

## 完了報告

- 実装した機能、ファイル、設計から変更した点。
- lint、unit、型チェック/build、E2Eの結果。
- 実MP4/PNG/JSONの確認結果、codecとサイズ。
- ブラウザ・4画面幅・スクリーンショット・美術品質の確認。
- 性能実測、未検証の実機、既知問題。

公開作業はユーザーから依頼された時点の範囲に従う。このリポジトリは通常pushでは公開されず、対象コミットへの `release-*` タグが起点。公開した場合はActionsだけで完了にせず、本番の一覧・アプリ・資産・書き出しを確認する。
