# Type Motion Studio 検証結果

2026-09-26。対象はこのフォルダのローカルアプリ。公開済みCELESTIALは比較のためブラウザで実際に再生し、`film.js`・`score.js`・`player.js`を読んだ。公開済みのファイル、`apps.json`、リリースタグは変更していない。

## 環境とコマンド

- macOS 27.0 (26A428)、Apple M5、32 GiB RAM、Node.js 24.14.1。
- Playwright Chromium 153.0.8010.12。実操作の表示幅は375、768、1024、1440px、高さ900px。
- `npm run check`: oxlint成功、Vitest 7件成功、TypeScript/Vite build成功、Playwright 10件成功。Viteは約2.7 MBのJS chunkについてサイズ警告を出す。同梱日本語フォントとエディタ/書き出しコードを含む。build失敗ではない。
- `git diff --check`: 成功。rootの共有テストは本アプリの証拠として用いていない。

## 実操作と映像

| 対象 | 実施内容と結果 |
| --- | --- |
| CELESTIAL | 編集可能な24秒・6場面の作例を再生。元作品の導入、粒子文字、放射、日食/円、帯と軌道、三分割、終止と比較。シークで場面を往復し同一時刻のCanvasデータが一致。画像は[横型の接触シート](artifacts/celestial-contact.png)。元作品との画素一致は狙わない新レンダラー。 |
| 日本語別コピー | 「ひらめきを／動かそう／光が生まれる／影がめぐる／星 太陽 月／言葉が映像になる」を組み、24秒の`artifacts/japanese-720p.mp4`と`artifacts/japanese-standalone.html`を実出力。日本語の改行と6場面を[画像](artifacts/japanese-contact.png)で確認。`file://`でHTMLを開き、再生/停止、外部HTTPリクエスト0件を確認。 |
| 三つの構成 | 同じ文章で3レシピを生成。2場面目がそれぞれ粒子、帯と軌道、三分割になり、再生中のCanvas画像が3種類とも異なる。[天体](artifacts/recipe-celestial.png)、[宣言](artifacts/recipe-manifesto.png)、[リズム](artifacts/recipe-rhythm.png)。 |
| 縦型 | CELESTIAL 9:16を描画して720×1280のMP4を実出力。三分割が縦に積まれることを[画像](artifacts/portrait-contact.png)で確認。 |
| 場面とデータ | 文・順番・長さ・演出・circle-match変更、合計尺の変化、Undo/Redo、IndexedDB自動保存後の再読込、JSON退避と別作品としての復元、不正JSON後の現状維持を操作。circle-matchはSOL/LUNA間を1拍重ねて24→23.5秒に更新。[開始](artifacts/circle-match-start.png)、[中間](artifacts/circle-match-middle.png)。 |
| UI | [375](artifacts/ui-375.png)、[768](artifacts/ui-768.png)、[1024](artifacts/ui-1024.png)、[1440](artifacts/ui-1440.png)のスクリーンショットを取得・目視。横スクロールなし。375pxでは文章/場面/調整タブを操作。出力ボタンはヘッダーから到達可能。 |
| キャンセル | 24秒MP4の書き出し中に中止し、中止メッセージを確認。同じ画面から再出力して正常なMP4を保存・復号。 |
| HTML安全性 | 作品名に`</script><script>window.pwned=1</script>`を入れたHTMLを出し、`file://`で開いてコードが実行されないことを確認。 |

## 実ファイルの検査

以下はE2Eで出力された実ファイルを`ffprobe`で調べ、`ffmpeg`で映像・音声の全パケットを復号した結果。全ファイルで復号エラーなし。MP4の先頭音声・映像PTSはともに0秒。AACの終端はencoderのパディングで映像より約64〜75ms長い。音声と映像は同一の編成タイムラインから生成している。`artifacts/celestial-1080p.mp4`はブラウザでも開き、再生終端と最終画面を確認した。動画とHTMLはGit管理対象外で、ローカルの同ディレクトリに残してある。

| ファイル | 映像 | 音声 | 総尺 | サイズ |
| --- | --- | --- | ---: | ---: |
| `celestial-1080p.mp4` | H.264、1920×1080、30fps、720フレーム、24.000秒 | AAC、先頭0秒、24.064秒 | 24.064秒 | 19.8 MB |
| `japanese-720p.mp4` | H.264、1280×720、30fps、720フレーム、24.000秒 | AAC、先頭0秒、24.064秒 | 24.064秒 | 11.9 MB |
| `celestial-portrait-720p.mp4` | H.264、720×1280、30fps、720フレーム、24.000秒 | AAC、先頭0秒、24.064秒 | 24.064秒 | 9.1 MB |
| `sixty-1080p.mp4` | H.264、1920×1080、30fps、1800フレーム、60.000秒 | AAC、先頭0秒、60.075秒 | 60.075秒 | 42.8 MB |
| `short-retry.mp4` | H.264、1280×720、30fps、720フレーム、24.000秒 | AAC、先頭0秒、24.064秒 | 24.064秒 | 10.8 MB |

E2Eでの1080p書き出し時間は24秒作品3.357秒、60秒作品6.399秒。[計測JSON](artifacts/export-1080p-metrics.json)、[60秒の計測JSON](artifacts/export-sixty-metrics.json)。これはこの機器のheadless Chromiumでの一回の値であり、他端末の性能保証ではない。

## 未確認・制約

- 音声トラックの存在、PTS、PCMピークと全編復号は検証した。モデルには実際の聴感入力がないため、冒頭・場面境界・終端のクリック、音量感、聴覚上の同期は人間の試聴を未確認として残す。
- ピークメモリ、Safari/Firefox、実機モバイル、非表示タブ中の長尺出力、finalize直前のキャンセル競合は未測定。60秒1080pは上記の基準機で実際に成功した。
- WebMはコード上で対応判定とVP9/Opus出力経路を用意したが、実ファイルのE2E・全編復号は未実施。MP4非対応環境ではWebMまたはHTMLを選択する。
- 元作品との演出比較は目視であり、画素完全一致ではない。最終的な作品としての聴感とコピーの編集判断は人間の確認が必要。
- HTML/動画はファイルが大きいためGitから除外。ローカルの`docs/verification/artifacts/`に置き、E2Eから再生成できる。スクリーンショット、計測JSON、復元用project JSONはGitに含める。
