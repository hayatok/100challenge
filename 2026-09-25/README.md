# 動く表紙の試着室

制作開始日: 2026-09-25（Asia/Tokyo）

短い言葉から4枚の動く表紙を作る、ブラウザ内完結の制作アプリ。12表現・36構図から見本を見て選べる。選んだ表紙の色・文字組み・形・動きを固定して近い別案を試せる。新しい「迫る・干渉・散る」の造形と参照事例は[追加表現計画](docs/EDITORIAL_MOTION_EXPANSION.md)を参照。

公開版: [動く表紙の試着室](https://hayatok.github.io/100challenge/2026-09-25/)

## 起動

```sh
cd /Users/hayatok/Documents/dev/100challenge/2026-09-25
npm ci
npm run dev
```

表示されたローカルURLを開く。初回はフォントを読み込むため少し待つ。静止画PNG、6秒・30fpsの動画、再編集用JSONを「書き出す」から保存できる。動画は端末のコーデック対応を調べ、MP4/AVC、WebM/VP9、WebM/VP8の順に選ぶ。作品と履歴、お気に入りはIndexedDBに保存される。

## 検証

```sh
npm run setup
npm run check
```

`check` はlint、unit、型チェックとbuild、Playwrightのブラウザ統合テストを実行する。実動画はブラウザのWebCodecsで生成し、ffprobeを使って再検査する。実測、スクリーンショット、実動画の確認記録は[RESULTS](docs/verification/RESULTS.md)にまとめる。
`setup` はChromiumと動画検証用のffmpeg・ffprobeを準備する。Ubuntuでは不足していればaptで導入し、macOSでは両ツールを事前にインストールする。アプリの閲覧や書き出しにffmpegは不要。

## 仕様

1. [製品仕様](docs/PRODUCT_SPEC.md)
2. [表現・UI仕様](docs/VISUAL_SPEC.md)
3. [技術設計](docs/TECHNICAL_DESIGN.md)
4. [テスト方針](docs/TEST_PLAN.md)
5. [実装手順](IMPLEMENTATION_PLAN.md)

操作と保存の意味は製品仕様、見た目は表現仕様、内部契約は技術設計を基準にする。
