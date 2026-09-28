# アルファ版音源（2026-09-28）

アルファ版は完成済みループ音楽と実録銃声・打撃のサンプルを使用する。WebAudio の発振器は撃破／被弾時の短い低域スウィープのみ。ゲームプレイ時の音の好みや手触りは、実ブラウザで別途確認する。

## 配布音源と権利

| 配布ファイル | 元素材 | 著作者・配布元 | ライセンス | 加工 |
| --- | --- | --- | --- | --- |
| `darkness-road.ogg` | `darkness_road_remake_bpm165_0.ogg` | MintoDog / [OpenGameArt](https://opengameart.org/content/darkness-roadremeke) | CC0 | 変更なし。165 BPM、128 秒のループ |
| `shot-1.mp3` ～ `shot-3.mp3` | `sounds/cz.wav` in `sounds.zip` | Vincent Sevedge / [OpenGameArt: Gunshot Sounds](https://opengameart.org/content/gunshot-sounds) | **CC BY 3.0** | 実録 CZ-52 の 3 発を各 0.54 秒に切り出し、EQ、コンプレッサー、フェード、音量調整、MP3 化 |
| `hit.ogg` | `impactPunch_medium_003.ogg` | Kenney / [Impact Sounds](https://kenney.nl/assets/impact-sounds) | CC0 | コピー |
| `body.ogg` | `impactPunch_heavy_001.ogg` | Kenney / 同上 | CC0 | コピー |
| `metal.ogg` | `impactMetal_heavy_002.ogg` | Kenney / 同上 | CC0 | コピー |
| `bell.ogg` | `impactBell_heavy_000.ogg` | Kenney / 同上 | CC0 | コピー |
| `glass.ogg` | `impactGlass_heavy_001.ogg` | Kenney / 同上 | CC0 | コピー |

**銃声の表記差異:** OpenGameArt の掲載ページは CC0 と表示するが、ダウンロード ZIP 内 `sounds/creativecommons.txt` は「Copyright (c) 2009 Vincent Sevedge」「Creative Commons Attribution 3.0 Unported License」と明記する。このため配布物を CC BY 3.0 として扱い、上記著作者、[ライセンス](https://creativecommons.org/licenses/by/3.0/)、加工内容を記載する。この音声ファイルは著作者による本ゲームの推奨・承認を意味しない。

Kenney の ZIP 内 `License.txt` は CC0 と明記。音楽の掲載ページも CC0 を明記。いずれもログイン不要で直接取得できる。素材の権利情報の確認日は 2026-09-28。

## 再現と整合性

`python3 scripts/audio/build_audio.py /path/to/sounds.zip /path/to/kenney_impact-sounds.zip /path/to/darkness_road_remake_bpm165_0.ogg` で生成。`ffmpeg` が必要。元アーカイブはゲームに同梱しない。上記リンクから直接取得した元ファイルの SHA-256:

```text
sounds.zip                              5b3960083a94e18ee47bc84376615a476debc884b18f25b93ea4b6ab3f278e4f
kenney_impact-sounds.zip                029d734af1582474edf3a694d1b0cebc97c1c152f2f39fa34d4c2bafc5de77f8
darkness_road_remake_bpm165_0.ogg       b683349a07ab6193198133d8e3c5e706c7d406f86a5c16391e4f100803e35a67
```

配布ファイルの SHA-256:

```text
bell.ogg           94b8bb5f2d43ab65e4bcc32b28562416e9bc2c51d9fd4be1e333660ee52f977f
body.ogg           f92f5cb6ba4ff2766497292ffd90865654317eeca976f5652e0708dbdcdc0dd9
darkness-road.ogg  b683349a07ab6193198133d8e3c5e706c7d406f86a5c16391e4f100803e35a67
glass.ogg          58686e0e562612cc566791844a10e269f8d1921f4766c14ba43976fd0a429f4e
hit.ogg            2d7c719c05999e0532f4384e1018e04cd916db715140bf16dee2dff3f820e908
metal.ogg          b914c8f1eb7c0f34bb165d7c77f4be0351f6be0660c13c53e65424e262e2c093
shot-1.mp3         47d5f550aef0b537c5c98c0c83cde0b19e69f37661ede5f2249f287f553ec01d
shot-2.mp3         9612f7cc37fd44d7f25da6a37dacadc4631c31387f464e2446fbfd66dd05fa9e
shot-3.mp3         3c380dd2a1b04bf513ed14d4232c1a110c04c47147242cc00f2abef1adedc409
```

## 実装の音響設計

`GameAudio.load(onProgress?)` が音源を先読み・デコードし、`unlock()` がユーザー操作で AudioContext を再開する。正打 `shot()` は実録銃声 3 種を交互に再生し、27 ms 後に着弾を置く。撃破 `kill(combo, kind?)` は打撃・金属・ガラスを段階的に重ね、上位段階では短い低域スウィープを足す。`tier(level)`、`transition(stage)`、`boss()`、`victory()` は状態専用の合図。BGM は 165 BPM の原曲ループで、コンボ 0～4 に合わせローパスの開度を次拍から変える。銃撃の反応は拍を待たない。

音楽と効果音は別ゲイン。マスター 0.7 とコンプレッサーでピークを管理し、効果音は同時 20 ボイスまで。連打時は個々の銃声ゲインを下げる。`stop()` は効果音を止めて BGM の位置を保存し、再開時に同じ位置から再生する。`stop(false)` は結果画面向けに効果音の余韻を残す。
