# yomiyasuの実施記録

Issue [#190](https://github.com/hayatok/100challenge/issues/190)。既存のyomiyasu 2.0.1を使用し、ルートのAGENTS.mdに推敲工程を追加した。アプリへの実行時依存は追加していない。

## 対象と変更

- 書き手・読み手・場面: 開発者から、音声ツールの利用者と今後の開発担当者へ伝える文章。対象ファイルの役割から判断した。
- ルートのAGENTS.mdと共通手順書、日本語の主画面文言（src/App.tsx）、アプリのREADMEを対象にした。過去アプリやライセンス原文は対象に含めていない。
- 冒頭の「必要なところを選んで、聴いて、保存。」を「音声の残したい範囲を選び、試聴して保存できます。」に変更した。
- フッターは送信しないことと編集データを破棄することを二文に分け、ブラウザ内のデータを指すと明記した。
- READMEでは時刻の入力方法と処理の説明を文にし、ファイルと役割の対応を表にした。数値、コマンド、対応範囲、未確認事項は維持した。

## 確認の記録

| 対象 | 立場・種類 | 見直し候補 | 実行した検査 |
|---|---|---|---|
| AGENTS.md | 決まり・formal | 原文13件 → 最終稿13件 | lint、diff、資料との照合、最終稿の照合 |
| README.md | 説明・manual | 原文4件 → 最終稿1件 | lint、diff、最終稿の照合 |
| src/App.tsx | 説明 | 原文0件 → 最終稿0件 | lint、diff、最終稿の照合 |
| docs/JAPANESE_REVIEW.md | 決まり・manual | 最終稿2件（新規作成） | lint、資料との照合、最終稿の照合 |

件数は点数ではなく、増減は読みやすさの良し悪しを示さない。候補を原文と読み比べ、次の理由で残した。

- AGENTS.mdの箇条書きは規則の一覧で、「解像度」は画面の寸法を指す。今回の追加と関係しない既存文の読点も変更していない。
- READMEの「準備完了の後は、」は通信を切れる条件を区切る読点として残した。
- App.tsxの意味が変わる恐れ3件はHTML行の変更。表示文言だけの変更で、処理や条件式は変えていない。
- 新規手順書の名前に関する候補はCLI名やコマンド例のパス・変数。使用できるオプションはCLIのhelpと照合した。
- 硬化の検査・勢いの検査は、差分を検査した3ファイルとも候補なし。
- 実行しなかった検査: READMEとApp.tsxの資料との照合（新しい仕様や数値は補っていない）。verifyのreplayは省略した。

以下はverifyの出力の2行目。各ファイルのハッシュが検査記録と一致した。これは読みやすさの合格判定ではない。

```text
yomiyasu-check: executed via=verify run=20261018T155152Z-211b8fe3 attempt=1 final=sha256:d3e05956f651 mode=rewrite doc_type=formal checks=lint,diff,materials meaning_risk=2 replay=skipped
yomiyasu-check: executed via=verify run=20261018T155152Z-f63dcb17 attempt=1 final=sha256:effdbafddf57 mode=rewrite doc_type=manual checks=lint,diff meaning_risk=0 replay=skipped
yomiyasu-check: executed via=verify run=20261018T155153Z-481b5b87 attempt=1 final=sha256:36c8613754d6 mode=rewrite checks=lint,diff meaning_risk=3 replay=skipped
yomiyasu-check: executed via=verify run=20261018T155153Z-50de349e attempt=1 final=sha256:62ebe3dbafd1 mode=compose doc_type=manual checks=lint,materials meaning_risk=11 replay=skipped
```

原文と最終稿を含むCLIの記録はローカルの作業用フォルダに保管し、リポジトリにはこの実施記録だけを置いた。

## 画面と動作

`npm run check`を再実行し、単体7件、lint、型チェック、build、ブラウザ10件が成功した。1440px・768px・375pxで初期画面と保存結果の画像を確認し、変更した文言の欠落や重なり、横はみ出しは見られなかった。画像は同じ検証フォルダのempty-*.pngとresult-*.pngを更新した。

IABでも生成サンプルを開き、1～3秒を指定してMP3の書き出し完了を確認した。Safari・Firefox・実機スマートフォンは今回も確認していない。音声処理の実装は変更していない。
