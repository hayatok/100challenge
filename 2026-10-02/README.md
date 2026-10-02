# BLACK RELAY / 黒雨の街

一語、一撃。黒雨商店街を抜けろ。

Godot 4.7.2で制作するオリジナルのゾンビ・タイピング・レールシューター。
今回のマイルストーンは、約47mの商店街を進む75秒のルートと24体の遭遇です。
75秒はカメラ経路の目安であり、制限時間ではありません。出口で残った敵を倒すまで続きます。
旧2026-09-28作品の移植ではありません。ライセンスを確認した一部の素材のみ再利用し、世界・遭遇・UI・ルールを新しく制作しています。

## 遊び方

- 白いローマ字を最後まで入力すると一撃で撃破
- 近い敵には琥珀色の短いCUTも出現。任意の足止めで、必須の装甲解除ではありません
- 攻撃直前のCUTでCOUNTER。近くの全敵を止めて+300点
- 素早い撃破を4秒以内につなぐとCHAIN。群れを一掃すると追加点
- ミスしても入力位置は戻りません。クリーン連続倍率のみ失います
- Tab / 敵をクリック：標的変更。各敵の途中入力を保持
- Backspace：選択した敵の入力をリセット
- Esc：一時停止。Enter / Space：メニュー・出発。F11：全画面

PCと物理キーボード向け。日本語IMEはオフにしてください。
日本語ローマ字・English、ASSIST / STANDARD / OVERDRIVE、音量、揺れ軽減、高コントラストに対応。
shi/si、chi/ti、tsu/tu、fu/hu、sha/sya、拗音・促音・語末n/nnなど、収録語の2,120候補を検査しています。

## 実装内容

- 実際に移動するカメラ、店先・路上・交差点を通る連続ルート
- スキニングされた人間型ゾンビと走る感染者。服・肌の色、歩行位相、体型の小さな個体差
- フルサイズの身体で倒れる修正済み骨格アニメーション。縮小消滅を使用しません
- 接地した銃と両手、反動、短い銃撃、軽い文字入力フィードバック
- 店舗、陳列、看板、車、横断歩道、路地、雨のアスファルト、近距離影
- ルート距離と小型HUD、戦闘中だけ出る単語パネル、リザルトと端末内保存
- 都会の雨・風・滴音、オリジナルの入力音、ライセンス付き銃声と着弾音

## 実行・検証

Node.js20.11+ / Python3.11+ / Godot4.7.2。追加npm依存はありません。`npm ci && npm run setup` で公式Godot・export templatesと音声検査用NumPyを準備します。NumPyがない環境では、このアプリ内の `.cache/python/` 仮想環境へ固定版をインストールします。

```sh
npm ci
npm run setup
GODOT_BIN=/workspace/shared/godot/bin/godot npm run play
GODOT_BIN=/workspace/shared/godot/bin/godot npm run check
GODOT_BIN=/workspace/shared/godot/bin/godot npm run build:linux
GODOT_BIN=/workspace/shared/godot/bin/godot npm run build:mac
GODOT_BIN=/workspace/shared/godot/bin/godot npm run build:windows
npm run preview
```

Web：dist/index.html。Linux / macOS / Windows：builds/urban-*。
旧マイルストーンの出力は別名で保持しています。
Webはsingle-thread WebGL2。ブラウザ実機の起動はこの環境のアクセス制約で未確認。
macOSはUniversal・ad-hoc署名で、Apple notarizationとmacOS実機検証は未実施。

詳細な実測、画像、テスト対象と限界はdocs/URBAN_QA.mdを参照。
このクラウドPCのレンダリングはGPUではなくllvmpipeです。高性能GPUでの品質・フレームレートは検証済みと扱っていません。

## ファイル

- game/scripts/main.gd：遭遇、入力、公平性、スコア、状態、保存
- enemy.gd：人間リグ、移動、CUT、死亡、個体差
- world.gd：商店街、47m経路、PBR材質、照明、描画負荷管理
- hud.gd：小型戦闘HUDとメニュー
- romaji.gd：ローマ字候補と進捗保持
- game/tests/run.gd：独立保存領域での回帰・全6設定クリア検査
- art/source/city/：素材加工・骨格補正・ライセンス検証の記録

## 権利・プライバシー

環境・UI・進行・合成音は本作のオリジナルです。
人間モデル・腕・拳銃・一部音声・PBRマップはCC0またはCC BY3.0の第三者素材です。
制作者、元ページ、ライセンス、変更点はTHIRD_PARTY_NOTICES.mdとdocs/URBAN_ASSETS.mdに記載しています。
既存商業ホラー作品から抽出した素材は含みません。

アカウント、課金、広告、解析送信、ゲーム内通信はありません。
設定と難易度×言語別の記録は端末内に保存。旧キャンペーンのスコアは別のプロファイルとして保持します。
