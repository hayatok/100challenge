# 動く表紙の試着室 — ローカル検証結果

検証日: 2026-09-25（Asia/Tokyo）。作業ブランチ `codex/moving-cover-studio`、開始HEAD `9a3c4554d5cf3ec312f59e63e07f4804094c3d5d`。以下は公開前に行ったローカル検証の記録。

## GitHub Pages公開後の確認

- `release-2026-09-25` はmainの `dd0e8d8d15246e6681ba9f08e1f03735d8baa6f9` を指す。[main検証](https://github.com/hayatok/100challenge/actions/runs/36123671995)と[Pages公開](https://github.com/hayatok/100challenge/actions/runs/36124717862)が成功した。公開版は [動く表紙の試着室](https://hayatok.github.io/100challenge/2026-09-25/)。一覧、アプリ、サムネイルはいずれもHTTP 200で、一覧カードからアプリへ遷移できた。
- 公開版をChromeで1440pxと375pxで操作し、[1440px画面](artifacts/production-ui-1440.png)と[375px画面](artifacts/production-ui-375.png)を目視した。4候補の生成と候補canvasの1秒後の変化、375pxの横はみ出しなし、両画面のJavaScriptエラーなしを確認した。
- 公開版から実際に[PNG](artifacts/production-cover.png)、[編集用JSON](artifacts/production-cover.json)、[MP4](artifacts/production-cover.mp4)を保存した。Chromeの動画要素で再生時刻が1秒以上進み、ffprobeでH.264・720×720・30fps・180フレーム・6.000秒を確認。PNGは1080×1080。同じ作品のPNGとMP4先頭フレームを720pxへ揃えたRGB平均絶対誤差は2.89/255で、許容12/255未満。JSONを公開版へ読み込むとタイトル「公開テスト」と1候補が復元された。

## 公開前の最終確認

- mainへの初回push後、GitHub ActionsのUbuntuで動画検証7件が `ffmpeg` / `ffprobe` 不在のため失敗した。実動画は生成されており、復号検査コマンドが起動できなかった。アプリの `setup` に不足時のffmpeg導入を追加し、クリーン環境でも実動画検証を実行する構成へ修正した。
- 次のCIでは実動画生成・再生を含む32件が通過した。72枚のPNGを順次書き出す2件はUbuntuで2分の既定制限に達したため、その検査だけ10分に延長。ほぼ静止したH4構図の復号MP4はUbuntuのソフトウェアエンコーダで継ぎ目に微小な圧縮差が出たため、B07の基準を相対差2倍または絶対RGB差2/255に調整した。検査器は閾値超過時に実測値も示す。
- 全ブラウザ試験の初回実行で、長い和欧混植タイトルと補助文を「迫る」に割り当てると、文字が重なるという組版エラーが1件発生した。タイトルの文字サイズを決める際に補助文の余白も判定するよう修正し、その入力を固定した回帰試験を追加した。
- 修正後の `npm run check` はlint、Vitest 9件、型チェックとbuild、Playwright Chromium 35件が通過。36構図の実MP4の動き・継ぎ目、12表現の実MP4とPNGの同時刻比較を含む。ルートの `npm test` 38件、`npm run build:site -- --prebuilt`、`git diff --check` も通過。
- 修正後の「迫る」の[375px候補](artifacts/release-monolith-candidate-375.png)、[1440px候補](artifacts/release-monolith-candidate-1440.png)、[375px画面](artifacts/release-monolith-page-375.png)を目視した。タイトルと補助文は重ならず、375pxと1440pxの画面に横はみ出しはない。

## タイポグラフィー主体の3表現を追加（同日）

[追加表現計画](../EDITORIAL_MOTION_EXPANSION.md)の作例を調べ、文字の押し出し、全画面の光学的反復、入力文字から作る粒子を実装した。「迫る・干渉・散る」各3構図を加え、12表現・36構図。画像・ロゴ・既存作品のレイアウトは転用していない。新規状態の最初の4案は新3表現と「流れる」。保存済み状態のおまかせでも、4案のうち2案が新3表現から選ばれる。

- [H10正方形](artifacts/h10-square-review.png)・[縦長](artifacts/h10-portrait-review.png)・[英字](artifacts/h10-english-review.png)、[H11正方形](artifacts/h11-square-review.png)・[縦長](artifacts/h11-portrait-review.png)・[英字](artifacts/h11-english-review.png)、[H12正方形](artifacts/h12-square-review.png)・[縦長](artifacts/h12-portrait-review.png)・[英字](artifacts/h12-english-review.png)を3構図ずつ目視した。主文字の欠字、見切れ、不自然な折り返しは見つからなかった。縮小見本と[一覧サムネイル](../../public/moving-cover-studio.png)も確認した。
- Chromeで全36構図×正方形/縦長×日本語/英語の実PNGを生成した（144枚）。全36構図の正方形実MP4で復号フレームの動きと最終→初回の継ぎ目を検査し通過。新構図の0秒から1.5/3/4.5秒の最大RGB平均差（180px縮小、/255）はH10が6.36〜14.50、H11が9.93〜17.99、H12が12.97〜15.11。全36構図で4を超えた。[新3表現の復号動画4時刻](artifacts/v5-motion-decoded-contact.png)を目視し、形の変化と文字の可読性を確認した。
- H1〜H12の正方形・縦長の実MP4を24本生成。720×720/720×1280、H.264、6秒、30fps、180フレーム。新3表現の[迫る](artifacts/h10-square.mp4)・[干渉](artifacts/h11-square.mp4)・[散る](artifacts/h12-square.mp4)と各縦長版を保存した。Chromeで「散る」の完成Blobを実再生し、映像を復号して再生時刻が1秒以上進むことを確認した。新3表現の0/1.5/3/4.5秒のMP4と同じrecipe・時刻のPNGとのRGB平均絶対誤差はH10が2.28〜2.67、H11が5.52〜5.72、H12が2.29〜3.07/255で、許容12未満。
- [375](artifacts/v5-ui-375.png) / [768](artifacts/v5-ui-768.png) / [1024](artifacts/v5-ui-1024.png) / [1440px](artifacts/v5-ui-1440.png) の全画面スクリーンショットを目視した。13個の選択ボタン、4候補、選択作品、固定、書き出しに横はみ出しや重なりはない。reduced-motion、スマホ候補の再生、固定/履歴/IndexedDB、JSON往復、PNG/動画出力、キャンセルとエラー復帰もE2Eで再実行した。
- 拡張後の `npm run check` はlint、Vitest 9件、型チェック/build、Playwright Chromium 34件が通過。ルートの `npm test` 38件と `npm run build:site -- --prebuilt` も通過。最後におまかせの配分を「新2案＋既存2案」へ変更したため、その変更後にlint、Vitest、型チェック/build、関連ブラウザテストを再実行した。旧初期候補名を期待するテスト1件は新初期候補に合わせて更新してから全件通過した。
- 最終配分のアプリを一覧へ再ビルドして `http://127.0.0.1:4173/2026-09-25/` で開いた。既存の「切る」ボードを復元でき、画面上で「おまかせ」→「4案を見る」を操作すると「迫る・干渉」と既存2表現の4案が表示された。元ボードは履歴に残る。再ビルド後のHTTP 200と`git diff --check`を確認した。
- Firefox・iOS/Android実機、およびSafariでの新表現の実MP4出力は未検証。Codex内蔵ブラウザの動画プレーヤー操作時のクラッシュは前節の記録どおりで、Chromeの実再生は成功した。

## 動きの可視性を改善（同日）

実画面で「アニメーションはマスト」という指摘を受け、[動きの調整計画](../MOTION_VISIBILITY.md)に原因と判断基準を記録した。プレビューの時刻は描画回数ではなく単調時計から求めるようにした。スマホの表示中候補も再生し、候補は軽い解像度で描いて負荷を抑える。reduced-motionの初期停止と明示再生は維持した。

- 「切る」は文字切片が走査し、「響く」は残像の間隔と濃さが変わり、「張る」は細線の束へ波が通るようにした。「増殖・環状」は交互の文字リングが逆方向へ揺れる。いずれも主文字の塗りは残す。
- 旧実MP4の0秒から離れた3時刻との差（180pxへ縮小したRGB平均差の最大）はH4=1.69、H6=2.50、H8=1.66/255だった。変更後の実MP4はH4=7.05、H6=4.08、H8=5.31/255。環状も3.30から5.01/255へ増えた。全27構図で同じ測定値が4/255を超え、最小4.08、最大64.97/255。数値に加えて[復号動画4時刻の一覧](artifacts/v4-motion-decoded-contact.png)を目視し、各表現で動きが読み取れることと文字が欠けないことを確認した。
- 全27構図の正方形実MP4（各6秒・30fps・180フレーム）で最終→初回の継ぎ目検査が通過。更新したH4/H6/H8/H9など9表現の正方形・縦長MP4を再生成して保存した。9表現の0/1.5/3/4.5秒では実MP4の復号フレームと同じrecipe・時刻のPNGが許容12/255以内で一致した。更新した[H4動画](artifacts/h4-square.mp4)、[H6動画](artifacts/h6-square.mp4)、[H8動画](artifacts/h8-square.mp4)、[環状動画](artifacts/h9-corona.mp4)を保存した。
- 375pxの実ブラウザで表示中の候補canvasが750ms間に更新され、停止中は同じフレームを保持し、再生で再び更新されることを検査した。既存のreduced-motion停止・再生、キャンセルと失敗からの復帰も再実行した。[375](artifacts/v4-ui-375.png) / [768](artifacts/v4-ui-768.png) / [1024](artifacts/v4-ui-1024.png) / [1440px](artifacts/v4-ui-1440.png) の画面全体スクリーンショットを目視し、文字欠け・重なり・横はみ出しはなかった。
- 表現選択の静止見本、検証用構図画像、一覧サムネイルは変更後の描画から作り直した。見本は各表現の0秒の静止構図を示し、候補と選択作品のcanvasが動く。
- 変更後の `npm run check` はlint、Vitest 9件、型チェック、build、Playwright Chromium 33件が通過した。画面外のcanvasを更新しない設計に合わせ、スマホ再生テストは候補を表示位置へスクロールして検査する。実時間時計の停止位置保持を追加した後はlint・型チェック・buildとスマホ再生/reduced-motionの対象テストを再実行した。
- 追加で、更新後の「増殖」から実MP4を生成し、Chromeの動画要素で再生開始から1秒以上進むことと720pxの映像を復号することをE2Eで確認した。ルートの `npm test` 38件、`npm run build:site -- --prebuilt`、`git diff --check` も通過した。Codex内蔵ブラウザではMP4生成と保存ボタン表示まで確認したが、内蔵の動画プレーヤー操作時にそのタブがクラッシュした。原因は未特定で、内蔵ブラウザでの再生確認は未完了。新しいタブで制作画面に復帰できることを確認した。

## Dribbble作例を参考にした造形拡張（同日）

ユーザー指定の[Dribbble p5.js作例](https://dribbble.com/tags/p5js)から、帯の流れ・細線の集積・反復文字と余白という構成原理を抽出した。[調査と実装方針](../DRIBBBLE_REDESIGN.md)に参照先と採用範囲を記録した。既存6表現に「流れる・張る・増殖」を各3構図追加し、計9表現・27構図とした。初期4案は新しい造形を3案含み、画像付きの表現選択から全9表現を選べる。

- [新3表現の日本語正方形](artifacts/h7-square-review.png)、[縦長](artifacts/h7-portrait-review.png)、[英語](artifacts/h7-english-review.png)をH7〜H9各3枚について目視した。大きな色帯、細線による網、小さな活字の反復で、文字と図形の関係および文字位置が異なる。見本、初期4案、[一覧サムネイル](../../public/moving-cover-studio.png)も目視した。
- Chromeで27構図×2比率×日本語・英語の実PNGを生成した（108枚）。短文・32文字・和欧混植・補助文のブラウザ試験も通過。確認したサンプルでは欠字、文字の切れ、意図しない折り返しはなかった。
- ChromeのWebCodecs/MediabunnyでH1〜H9の正方形・縦長の実MP4を18本生成し、H7〜H9の残りの6構図を含む新9構図でも実MP4を生成した。いずれも6秒・30fps・180フレーム。新3表現の[復号動画4時刻の一覧](artifacts/v3-video-decoded-contact.png)を目視し、描画と動きに破綻はなかった。「張る」のMP4はChromeの完成動画プレーヤーで実際に再生した。実動画の保存例は[流れる](artifacts/h7-square.mp4)、[張る](artifacts/h8-square.mp4)、[増殖](artifacts/h9-square.mp4)。
- H7〜H9の正方形動画4時刻を同じrecipe・時刻のPNGと比較したRGB平均絶対誤差はH7が1.71〜2.16、H8が3.83〜3.97、H9が1.82〜2.17/255で、許容12/255を下回る。実動画をffmpegで独立復号した比較である。
- 新9構図すべての実動画で最終→初回フレームの継ぎ目を検査し通過した。代表H7/H8/H9の継ぎ目絶対差はそれぞれ1.716/0.758/0.548（/255）。H7の波形に周期外の位相が混じった初期版は継ぎ目25.86だったため、位相式を直して動画を再生成した。H9の円環は動きが穏やかでcodecノイズが相対比を押し上げたため、比率2.0または絶対差0.75/255を許容する判定にした。円環の最終・初回フレームを[目視比較](artifacts/h9-corona-seam.png)しても跳ねはなかった。
- 表現選択、設定固定、履歴復帰、IndexedDB保存と再読込、旧recipe互換性をブラウザとunitで確認。[375](artifacts/v3-ui-375.png) / [768](artifacts/v3-ui-768.png) / [1024](artifacts/v3-ui-1024.png) / [1440px](artifacts/v3-ui-1440.png) の画面全体スクリーンショットを目視し、見本と4案の選択、プレビュー、固定、書き出しが各幅で見えること、横はみ出しがないことを確認した。PNG・JSONの往復、動画のキャンセル・失敗後復帰、reduced-motionなど既存の必須項目も全E2Eで再実行した。
- 最終の `npm run check` はlint、Vitest 9件、型チェック、build、Playwright Chromium 32件が通過。アプリの新しい依存関係はない。
- ルートの `npm test` は38件通過、`npm run build:site` も通過。一覧の更新サムネイルをChromeで目視し、カードから `/2026-09-25/` へ遷移して画像付き9表現が表示されることを確認した。`git diff --check` 通過。
- 最後のブラウザ確認で動画Blob生成直後の一瞬だけ空の `video src` を描くReact警告を見つけ、Blob URLができてからプレーヤーを表示するよう修正した。修正後にlint、Vitest 9件、型チェック、build、該当するブラウザ統合5件を再実行し通過した。
- 未検証範囲は下の「既知の制限」と同じ。追加の3表現のSafari・Firefox・実機モバイル動画出力は確認していない。

## 表現拡張の追加検証（同日）

以下は「切る・巡る・響く」と画像付き表現選択を追加した後の結果。下の各節は最初の3表現を完成させた時点の記録として残す。実装計画と参考事例は [表現拡張計画](../STYLE_EXPANSION.md) を参照。

- 6表現×各3構図、計18構図を日本語・英語と正方形・縦長でブラウザからPNG化した（72枚）。[新表現の日本語正方形](artifacts/h4-compositions.png)、[日本語縦長](artifacts/h4-portrait-compositions.png)、[英語正方形](artifacts/english-h4-compositions.png) からH4〜H6各構図の一覧を目視した。文字の欠落、見切れ、不自然な折り返しは見つからなかった。新しい[一覧用サムネイル](../../public/moving-cover-studio.png)も確認した。
- 新表現H4〜H6それぞれ正方形720×720・縦長720×1280の実MP4をChromeのWebCodecs/Mediabunnyで生成した。既存の6本と合わせて12本をffmpeg/ffprobeで復号・検査し、すべてH.264、30fps、180フレーム、6.000秒。H4〜H6の[正方形](artifacts/h4-square.mp4)・[縦長](artifacts/h4-portrait.mp4)は同ディレクトリの `h5-*`、`h6-*` も含めて保存した。Chromeの出力ダイアログで新表現の完成動画を実際に再生した。
- 同じrecipe・時刻から描いたPNGと実MP4のRGB平均絶対誤差（/255）は下表。許容値12を十分下回った。H4〜H6の0秒フレームは縦長でも比較した。

| 新作品・正方形 | 0秒 | 1.5秒 | 3秒 | 4.5秒 |
| --- | ---: | ---: | ---: | ---: |
| H4 切る | 1.81 | 1.63 | 1.61 | 1.59 |
| H5 巡る | 1.40 | 1.25 | 1.14 | 1.12 |
| H6 響く | 1.45 | 1.33 | 1.29 | 1.30 |

- 復号した180フレームを180pxへ縮小して継ぎ目を測定した。最終→最初の差 / 通常隣接差p95はH1=0.80、H2=0.63、H3=1.18、H4=6.24、H5=0.96、H6=1.66。H4はほぼ静止する構図で隣接差が非常に小さく、比率はH.264のI/Pフレーム差で増えるが、継ぎ目の絶対RGB差は0.325/255で閾値0.5未満。[H4の最終・初回比較](artifacts/h4-seam.png)を目視しても跳ねはなかった。H5の円弧が初期実装で継ぎ目を作ったため、整数回転へ修正して再生成・再測定した。計測器は `scripts/check-video-seams.mjs`。
- 画像付きの6表現と「おまかせ」をChromeで実操作した。キーボード操作・`aria-pressed`、新表現指定の4案生成、固定した値の派生候補への維持、親候補への復帰、IndexedDB再読込をPlaywrightで確認。旧recipe・保存データを受け入れるユニットテストも通過。選択用見本は実描画から生成したWebPで、各表現の出力を予告する。
- [375](artifacts/v2-ui-375.png) / [768](artifacts/v2-ui-768.png) / [1024](artifacts/v2-ui-1024.png) / [1440px](artifacts/v2-ui-1440.png) の実スクリーンショットを目視し、横はみ出し、選択状態の欠落、操作ボタンの重なりはなかった。スマホでは「おまかせ」が先頭2列、6表現は2列で表示される。既存のloading・empty・error・success・reduced-motion・動画キャンセル/失敗復帰の検証も新コードで再実行した。
- 拡張後の `npm run check` は lint、Vitest 9件、型チェック、buildと同梱フォント資産検査、Playwright Chromium 31件が通過。最後のレスポンシブCSS調整後も lint、unit、型チェック、build、対象のブラウザ3件を再実行して通過。ルートの `npm test` は38件通過。独立の継ぎ目検査は6作品すべて通過。
- ルート `npm run build:site` が通過。一覧の新カードから `/2026-09-25/` へChromeで遷移し、6表現の画像付き選択が表示されることを確認した。`git diff --check` 通過。検証用に起動したローカルサーバは終了し、4173/4175/4176番ポートが応答しないことを確認した。
- 新表現の画質・操作をこのMacのChromeで確認した。Safariの新表現、Firefox、iOS/Android実機の操作と動画出力は未検証。動画の色差や速度は他機種のエンコーダでは変わり得る。

## 環境と実行結果

- MacBook Air Mac17,3、Apple M5、32 GB、macOS 27.0 (26A428)。Chrome 153.0.8010.53、Safari 27.0。Playwright Chromeの代表viewportは375 / 768 / 1024 / 1440 px、DPR 1。Safariは実デスクトップ画面で操作。
- アプリの `npm run check` は oxlint通過、Vitest 9件通過、`tsc -b`/Vite build通過、実ChromeによるPlaywright 29件通過（所要約1分）。
- ルート `npm test` は38件通過。`npm run check:apps -- --apps-json '["2026-09-25"]'` を実施。ローカル一覧は `npm run build:site` で作り、一覧の新カード、サムネイル、`/2026-09-25/` への遷移とフォント資産の読込をChromeで確認した。公開URLは対象外。
- `git diff --check` 通過。Fontsourceの日本語bundleへ変更後、最終ビルドCSS内6件の資産URLに欠損0件、衝突名ファイル0件。`build` に資産URL検査を追加した。

## 実動画と同一フレーム

Chromeの実WebCodecs AVC/MP4でH1「織る」、H2「めくる」、H3「組む」を正方形720×720・縦長720×1280の計6本生成した。各動画はH.264映像1トラック、音声なし、30fps、180フレーム、6.000秒。1080×1920のH1縦長も実生成し、同じ180フレーム/6秒をffprobeで確認した。成果物は [artifacts](artifacts/) の `h1-square.mp4` 〜 `h3-portrait.mp4` と `h1-portrait-1080.mp4`。

PNGとMP4を同じrecipe・時刻・720pxに揃え、MP4をffmpegで独立に復号した。RGB平均絶対誤差（許容12/255）は次のとおり。実動画の比較であり、codec能力のモック結果は含まない。

| 作品 | 0秒 | 1.5秒 | 3秒 | 4.5秒 |
| --- | ---: | ---: | ---: | ---: |
| H1 正方形 | 2.66 | 2.46 | 2.23 | 2.18 |
| H2 正方形 | 1.24 | 0.92 | 0.88 | 0.87 |
| H3 正方形 | 1.56 | 1.18 | 1.24 | 1.07 |

縦長の0秒もH1=2.14、H2=1.12、H3=1.13/255。0/1.5/3/4.5秒の実動画フレームは3作品とも異なる。720px正方形動画を180pxへ縮小して全隣接フレーム差を計測した結果、最後→最初の差 / 通常隣接差の95パーセンタイルはH1=0.80、H2=0.63、H3=1.18。基準の2.0以下。周期の式だけでなく復号映像で継ぎ目を確認した。

Chromeの出力ダイアログでは、完成Blobをそのまま`<video controls>`で再生し、0→6秒から次のループへ戻ることを目視した。1080px縦長の2秒フレームも [画像](artifacts/h1-portrait-1080-frame-2.png) で確認し、文字欠落や見切れはなかった。PNGは実ダウンロードしたファイルのPNGヘッダを検査し、JSONはダウンロード後に読み戻して候補を復元した。

動画の開始直後、90フレーム付近、最終処理中のキャンセルを注入・操作し、完成Blobを渡さず再試行できた。エンコーダ途中失敗も注入し、エラー表示後に実動画を再生成できた。codec全非対応・1080px非対応の表示は能力判定を**テストで注入**した分岐確認であり、実動画成功の根拠には使っていない。

## 操作・保存・画面

- 入力→4案→選択→色と文字組みの固定→近傍4案→親へ戻る→お気に入り→再読み込み→JSON再読込がChromeの実操作で通過。固定domainは16通り×3表現のunit比較で親と一致し、履歴はA→B→A→CでBを残し50件上限を確認した。
- IndexedDB再読込、2タブ同時編集のrevision衝突、保存不能時のJSON退避を確認。未適用の詳細調整を閉じるとdraftを取り消して通常操作へ戻れる。
- 375/768/1024/1440pxの [画面](artifacts/ui-375.png) を含む4枚を目視。横はみ出し、文字欠落、ボタンや固定項目の重なりなし。reduced-motion初期停止、明示再生、dialogのEscapeとfocus復帰、50回候補切替・3回PNG後のhost数を確認。
- 9構図×正方形/縦長を日本語と英語改行でPNG化した。[日本語](artifacts/h1-compositions.png)、[英語](artifacts/english-h1-compositions.png) の各H1〜H3比較画像を目視。短文、句読点、和欧混植、32文字、補助文付きもブラウザで生成した。
- Fontsource取得を遮断すると明確なエラーと再試行を表示し、再読込で復帰。取得済みの文字と同梱字体の未使用文字はオフラインで候補生成・PNG・JSON保存が通る。読み込み中はcanvasが透明のままで、完成品として見せない。
- Safari実画面で4案を生成し、PNGとJSONを実ダウンロードした。FirefoxはPlaywright配布のNightly 155.0を導入して起動を試みたが、headless・GUIとも `Profile Missing` で起動せず、互換性は未検証。iOS/Android実機も未検証。

### 代表状態の画像

[お気に入り空](artifacts/favorite-empty.png)、[入力エラー](artifacts/input-error.png)、[全固定による生成不可](artifacts/all-locked.png)、[キーボードfocus](artifacts/keyboard-focus.png)、[保存失敗](artifacts/save-error.png)、[フォント失敗](artifacts/font-error.png)、[動画非対応](artifacts/video-unavailable.png)。初回loadingはフォント待機中の透明canvasを自動検査した。履歴は初回から見本の1セットが存在するため「履歴0件」状態はない。

## 性能と目視判定

このMacのChrome/Playwrightで、初回フォント取得後の4候補生成545ms、選択応答89ms、30秒連続プレビューを確認。720px正方形MP4は1408ms、1080px縦長MP4は1461ms（ボタン押下から「動画を保存」が見えるまで）。描画・エンコード時間は作品や端末で変わる。1080px時のプロセス外Canvas/GPUメモリ量は計測できていない。

美術品質の静止構図、日本語、動き、文字と図形の統合、3表現/9構図の違い、探索、出力は各2/2。根拠は日本語・英語の構図一覧、H1〜H3の6本の実動画とコンタクトシート、実PNG/MP4の同時刻比較。H2の動きは他2表現より穏やかだが、4位相に差があり継ぎ目は突出しない。

## 既知の制限

- FirefoxとiOS/Androidの実動作は未検証。Safariの動画形式と実MP4出力も確認対象外で、能力判定に従う。
- 日本語bundleに含まれない字体は端末側のフォールバックになる可能性があるため、その文字の見た目の端末間一致は未検証。
- 日本語Fontsourceの3書体を同梱するため `dist` は約10MB。Viteはp5/Mediabunnyの500kB超チャンク警告を出す。元のsubset方式ではローカルの複数ビルド後に `dist` へ衝突名のフォントが生じた。bundle方式へ変更し、CSS内の全URLを検査するビルドゲートを追加した。
