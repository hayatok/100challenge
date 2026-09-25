# Type Motion Studio

文章と場面構成から文字中心のモーショングラフィックを作るローカルWebアプリ。最初にCELESTIALの編集可能な作例を開き、再生、文章の差し替え、場面調整、単体HTML・音声付きMP4の書き出しができます。公開済み[CELESTIAL / CUT 02](https://hayatok.github.io/100challenge/2026-09-26/)は比較対象として使用し、変更していません。HyperFramesは使用していません。

## 起動

Node.js 24でこのフォルダに入り、以下を実行します。Chromium系のブラウザを推奨します。動画出力はWebCodecsの対応状況に依存し、書き出す形式と解像度で機能を判定します。

```sh
npm ci
npm run dev
```

表示された `http://127.0.0.1:5173/` を開きます。ローカル保存はIndexedDBです。「文章」に一行一場面で2〜12行を入力し、3種類の構成レシピを選んで「映像を組む」を押します。作例の場面を直接編集しても構いません。再構成は現在の編集を置き換えますが、Undoで戻せます。音は既定でOFFです。

## 編集と出力

- 場面の文章、補足文、演出、順番、長さ、動きの強さ、文字サイズ、カットまたは円の連続変形を調整できます。全体のBPM、アクセント色、横型/縦型、音源の有無も設定できます。
- プレビューと動画・PNG・単体HTMLは同じCanvas 2Dの描画関数と確定したproject JSONを使います。単体HTMLはプレイヤー、フォント、作品データを内包し、編集アプリなしで開けます。
- 動画は720p/1080p、30fps、MP4（H.264/AAC）または対応ブラウザのWebM（VP9/Opus）。音声合成はWeb Audioプレビューと動画出力で同じPCMを使います。出力中の中止と再試行に対応します。
- JSONは別作品として読み込まれ、現在の編集を直接上書きしません。自動保存は500ms後に開始し、revision競合を検出します。保存失敗時も画面上の編集内容を保持し、JSONで退避できます。

入力範囲は全体4〜60秒、BPM 60〜180、2〜12場面です。長い文字や同梱フォントにない字形は警告または出力停止にします。外部BGM、自由なキーフレーム編集、アカウント、公開機能はありません。

## 検証

```sh
npm run typecheck
npm run lint
npm test
npm run test:e2e
npm run build
npm run check
```

Playwright Chromiumが未導入なら `npx playwright install chromium` を先に実行してください。`npm run check` は上記のlint、単体テスト、型チェックとbuild、ブラウザ試験をまとめます。E2Eは実際のHTML/MP4を `docs/verification/artifacts/` に出します。大きい動画とHTMLはGit管理対象外です。アプリ固有の試験はこのフォルダで実行します。rootの `npm test` はこのアプリの試験ではありません。

実測結果、再生・復号・画面確認の範囲、未確認事項は[検証結果](docs/verification/RESULTS.md)に記録しています。仕様と当初の判断は[プロダクト仕様](docs/PRODUCT_SPEC.md)、[演出仕様](docs/MOTION_DESIGN.md)、[技術設計](docs/TECHNICAL_DESIGN.md)、[データ契約](docs/DATA_MODEL.md)、[実装計画](IMPLEMENTATION_PLAN.md)、[検証計画](docs/TEST_PLAN.md)を参照してください。

このアプリのPages公開、`apps.json`への登録、リリースタグ作成は今回の作業に含めていません。
