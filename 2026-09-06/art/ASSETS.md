# 素材と制作記録

## 人物

`game/assets/images/neighbors.png` はこのゲーム用にbuilt-in ImageGenで制作したオリジナル人物アトラス。4系統の見た目を、住人IDに対応した色・帽子・持ち物・年齢の表現と組み合わせる。ゲーム内およびプロフィールで同じ人物素材を使用。

- 最終生成ファイル: `exec-53f21a92-c1b1-450b-8ff6-8d64a96bcbed.png`
- 寸法: 1536×1024。実際の生成結果は7列×4行。
- SHA-256: `4a1b74cef5c73ef596e4460edcf8f1077d923b3cc9c66c16badb847e08a3aa1f`
- 生成原稿は8列/透明背景を指定したが、出力は7列かつ市松背景だった。画像を確認し、透過修正の再生成後も市松模様が残ったため、背景を単色マゼンタにする編集をImageGenで行った。
- 採用画像は生成物をそのままコピー。オフラインで画像加工せず、GodotのCanvasItemシェーダーでマゼンタを抜く。ゲーム内表示と縮尺を目視確認。
- 実際の切り出し: 列ごとの開始Xは `40+211*column`、行開始Yは `26+237*row`、157×215領域。表示は36×49を基準にNearestフィルター。
- 初期の市松背景画像と不採用の修正版は出荷しない。

### 初回生成プロンプト

```text
Use case: stylized-concept. Asset type: production pixel-art character sprite atlas for an original Japanese convenience-store management game, 2D isometric 2:1 view. Create one 1536x1024 transparent PNG, exact regular 8 columns by 4 rows grid, each cell 192x256. There are 4 distinct adult Japanese neighborhood characters, one per row. Row1 short chestnut bob woman wearing cream blouse mint skirt and coral bag. Row2 young man in navy school-style casual jacket with red sneakers and backpack. Row3 elderly man with grey hair, round glasses, tan vest dark trousers carrying newspaper. Row4 female store clerk with dark tied hair green apron cream shirt. Every row: cols1-2 facing southeast walking two different steps, cols3-4 southwest walking two steps, cols5-6 northwest walking two steps, cols7-8 northeast walking two steps. Identical character consistent across each row. Low-head-count chibi bodies, 1.8 heads tall, large expressive faces, cute comic charm, expertly hand-placed chunky pixel clusters, dark teal clean outlines, amber highlights. Game camera looks downward enough to see tops of heads but figures upright. Each sprite fully isolated centered in its exact cell, feet baseline at 224 pixels in each cell, max width120px height190px, generous TRANSPARENT gutters. NO ground, NO shadows, NO grid, NO text or labels, NO frame, NO checkerboard drawn. No antialiasing, no blurry paint, no gradients. This is actual game atlas to cut into cells, not presentation concept.
```

## 店舗・商品・UI

等角投影の床、壁、棚、レジ、看板、植栽、自転車、窓、商品のピクセルアイコン、雨、吹き出しはGDScriptで制作。`store_view.gd` / `product_icon.gd` / `main.gd` を正本とする。実在店舗や既存ゲームのロゴ・キャラクター・素材は使用していない。

## 音

`scripts/compose_audio.py` にメロディ・和声・音色の制作元を保持。Python標準ライブラリのみでPCM WAVを生成する。アプリ実行時にPythonは不要。

| ファイル | 内容 | 長さ | SHA-256 |
| --- | --- | --- | --- |
| day.wav | 日中のベルとベース、8フレーズ | 40.96秒 | af823c7965eebc958465e3bd13a54984199f436e4a3cd8fb0c692ffb5792346c |
| night.wav | 同じ和声の静かな夜間編曲 | 40.96秒 | faa47d0c52bfc942e51be69a6c26326a8305145c6ea8087932d274c45f80c80f |
| room.wav | 冷蔵設備の低い環境音 | 2秒ループ | 16f75e1d50f3e03f1156cd55fdf6f83a52958d4238147bc0f230ecdcca0898b2 |

音楽は昼夜で4秒かけて切り替え。操作・会計・成功音は `audio.gd` で合成する。外部の録音・楽曲は使用していない。

## フォントとスクリーンショット

Noto Sans CJK JP Mediumと同梱のSIL Open Font Licenseを使用。検証画像は実ゲームをCUAで撮影し、`docs/screenshots/` に保存。カバーは実画面から作る。
