# 6つのゲーム企画

スマホWeb向けの本編ゲーム6案を、ジャンルの組み合わせ、ヒロインとの交流、制作量から比較する資料。

まず[index.html](index.html)で全案を見渡し、[比較PDF](output/pdf/00-comparison.pdf)から興味のある企画へ進める。

| 企画 | PDF | 編集元 |
| --- | --- | --- |
| 線路の砦 | [6ページ](output/pdf/01-rail.pdf) | [Markdown](concepts/01-rail.md) |
| 忍び獣の飼い方 | [6ページ](output/pdf/02-beast.pdf) | [Markdown](concepts/02-beast.md) |
| 枝を刈る冒険者 | [6ページ](output/pdf/03-garden.pdf) | [Markdown](concepts/03-garden.md) |
| 六部屋の約束 | [6ページ](output/pdf/04-inn.pdf) | [Markdown](concepts/04-inn.md) |
| 値札の裏の探偵 | [6ページ](output/pdf/05-detective.pdf) | [Markdown](concepts/05-detective.md) |
| 競売国家 | [6ページ](output/pdf/06-auction.pdf) | [Markdown](concepts/06-auction.md) |

## 資料の読み方

全案とも未実装。掲載画像は企画検討用に生成したイメージであり、実装済み画面、完成アセット、量産品質の証明ではない。画面モックのボタンは選択表示だけを切り替える。実際のゲーム処理や保存処理はない。

3〜6時間の本編と4〜6か月規模の開発期間は、範囲を比較するための設計目標と仮見積。工数、遊びやすさ、面白さ、端末性能の実測値ではない。金額は架空のゲーム内通貨である。

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
