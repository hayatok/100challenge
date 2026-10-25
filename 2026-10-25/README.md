# 6つのゲーム企画

スマートフォンのブラウザで遊ぶゲームを6案紹介します。各企画書では、プレイヤーの役割、目的、操作、選択した結果を順に説明しています。ヒロインとの関わり方や、開発に必要な作業も案ごとにまとめました。

最初に[比較PDF](output/pdf/00-comparison.pdf)を読むと、各ゲームで何をするのかが分かります。[一覧ページ](index.html)には、個別の企画書と画面見本へのリンクがあります。

| 企画 | PDF | 編集元 |
| --- | --- | --- |
| 線路の砦 | [企画書](output/pdf/01-rail.pdf) | [Markdown](concepts/01-rail.md) |
| 忍び獣の飼い方 | [企画書](output/pdf/02-beast.pdf) | [Markdown](concepts/02-beast.md) |
| 枝を刈る冒険者 | [企画書](output/pdf/03-garden.pdf) | [Markdown](concepts/03-garden.md) |
| 六部屋の約束 | [企画書](output/pdf/04-inn.pdf) | [Markdown](concepts/04-inn.md) |
| 値札の裏の探偵 | [企画書](output/pdf/05-detective.pdf) | [Markdown](concepts/05-detective.md) |
| 競売国家 | [企画書](output/pdf/06-auction.pdf) | [Markdown](concepts/06-auction.md) |

## 資料の読み方

ゲーム本体はまだ実装していません。掲載画像は、完成後の画面を想像するために作成したものです。「画面モック」は画面構成を確認する見本を指し、ボタンを押すと説明が切り替わります。ゲームを進めたり、進行状況を保存したりする機能はありません。

本編の長さは3〜6時間、開発期間は4〜6か月を目標として記載しています。実際に制作して測った数値ではありません。ゲームの面白さや実機での操作性も、今後の試作で確認します。本文の金額はゲーム内の架空通貨です。

企画書は6章構成です。説明を省略したり文字を小さくしたりして6ページへ収めることをやめ、内容に応じて改ページするようにしました。比較資料は2ページのまま、1ページに3案ずつ紹介します。

## 原本と再生成

本文の原本は`concepts/*.json`。画像原本と生成時の指示は`art/`に置く。各PNGは左からキーアート、プレイ場面、交流場面の3面で構成される。PDFとHTMLは同じ原本を参照し、画像の表示範囲を指定して使う。

PDF制作にはPythonのreportlabとpypdf、画面確認にはNode.jsのPlaywrightを使う。今回の環境ではCodexのバンドル済み依存を使い、リポジトリ共通の依存は変更していない。日本語PDFの生成にはTrueTypeフォントが必要。今回使うArial UnicodeはOS上のフォントであり、フォント本体を同梱しない。別環境では利用許諾を確認した日本語TrueTypeフォントを`--font`で指定する。

```sh
python3 scripts/build.py --prepare-only
node scripts/capture.mjs
python3 scripts/build.py --font /path/to/JapaneseFont.ttf
```

`capture.mjs`はこの環境のバンドル済みPlaywrightを参照する。異なる環境では`PLAYWRIGHT_MODULE`にPlaywrightのインポート先を指定する。

## アセットと公開範囲

素材のURL、ライセンスの確認範囲、加工方法、比較作は各企画書に記載した。素材本体のダウンロード、採用、再配布、ゲーム用アセット生成は今回行っていない。Tripoはブラウザ経由の候補として記載した。画像生成には組み込みimage_genを使った。

この資料は企画選定用であり、アプリ一覧への登録、Pages公開、リリースタグ作成は行わない。

## 確認記録

[検証記録](docs/verification/RESULTS.md)に、PDF、画面モック、日本語検査、独立レビューと未確認範囲を記録する。
