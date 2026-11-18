# リボンラリー！

赤いリボンのナギと5人のライバルが走る、スマホ縦持ちの3D障害物レース。潮風ふ頭では選手の重みで浮き橋が傾く。夕焼けコンテナヤードではクレーンが吊ったコンテナが水路を横切る。その屋根に飛び乗るか、加速を残して外の桟橋を回ろう。

[ブラウザで遊ぶ](https://hayatok.github.io/100challenge/2026-11-18/) · [夕焼けコンテナヤードのプレイ映像（音声あり）](docs/verification/v02-yard.mp4)

## 操作

タイトルの写真を選ぶと、そのコースでレースが始まる。全員が自動で前進する。

| 操作 | スマートフォン | キーボード |
| --- | --- | --- |
| 左右に移動 | コースを左右にドラッグ、または下の矢印を長押し | ← → または A・D |
| ジャンプ | コースを短くタップ、または「ジャンプ」 | スペースまたは ↑ |
| ダイブ | ジャンプ中にもう一度タップ、または「ダイブ」 | 空中でもう一度スペースまたは ↑ |
| 加速 | 地上で「加速」。残り回数はボタンの旗で確認 | Shift |
| ポーズ・再開 | 右上のポーズボタン、続けるときは「再開」 | Esc または P |

加速は1レース2回。頂点付近でダイブすると遠くに届くが、着地後はお腹で滑って減速する。海に落ちると直前の目印から復帰する。音楽・効果音・カメラの動きはポーズ画面で切り替えられる。結果画面からは同じコースに再挑戦したり、別のコースに移ったりできる。

## シーンとモデルを開く

Godot 4.7.2で `game/project.godot` を開く。追走カメラと注視点はメインシーンの `game/HarborRace.tscn` にある。シーンエディタで `game/course/Course.tscn` を開くと潮風ふ頭を、`game/course/Yard.tscn` を開くとコンテナヤードを見渡せる。ヤードの床幅や足場の大きさを変えるときは `game/race/YardLayout.gd` を編集し、`game/course/BuildYard.gd` でシーンを再生成する。

6人の衣装、骨格、走りとダイブの動きは[Blenderの原本](modeling/ribbon-rally.blend)に収録した。音楽と効果音の生成元は `scripts/make_audio.py`。GodotとフォントのライセンスはWeb版に同梱する。

このフォルダで次のコマンドを使える。Linux x86-64では `setup` がエディタも取得する。macOSとWindowsではGodot 4.7.2をインストールしてから実行する。

```sh
npm ci
npm run setup
npm run dev
```

`npm run check` は素材を読み込み、走行・モデル・画面遷移をテストして、Web版を `dist/` に書き出す。`npm run preview` で書き出したゲームを起動できる。

## 原画と試遊記録

- [ナギの原画とモデルの三面比較](modeling/review/nagi-turnaround.webp)と[6人の正面・背面](modeling/review/cast.webp)。ライバル5人の後ろ姿は正面の設定画から補った。
- [加速・ダイブ・立ち上がりのポーズ](modeling/review/sport-motion.webp)と[モデルの計測記録](modeling/README.md)。ナギのリボンは原画と比べて横から見ると少し前に付いている。
- [v0.2の試遊と計測](docs/verification/v0.2.md)、[iPhoneのSafariシミュレーターで走った水路の分岐](docs/verification/v02-yard-safari.jpg)、[ダイブ中の画面](docs/verification/v02-dive-safari.jpg)。
- [初版の潮風ふ頭のプレイ映像](docs/verification/gameplay.mp4)と[原画・ゲーム仕様](docs/game-design.md)、[v0.2の開発計画](docs/v0.2-plan.md)。
