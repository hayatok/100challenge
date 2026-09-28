# アルファ版の敵キャラクター素材

確認日: 2026-09-28 (Asia/Tokyo)。元ファイルは作者の公開ページから無料・アカウント登録なしで取得した。配布するのは変換済みGLBのみ。元ZIP/FBX/Blendはビルドに含めない。既存の街の男性ゾンビは [CHARACTER_ASSETS.md](CHARACTER_ASSETS.md) を参照。

| 実行時ファイル | 造形・動作 | 作者・元ページ | 利用条件 |
| --- | --- | --- | --- |
| `public/assets/characters/thin-zombie.glb` | 青白い裸身、痩せた体型。歩行2種、走行、待機、攻撃2種、被弾、死亡を収録。 | Rosswet Mobile, [Thin Zombie / Awake Zombie Asset](https://opengameart.org/content/thin-zombie-awake-zombie-asset) | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) |
| `public/assets/characters/zombie-granny.glb` | ドレスと大きな髪型の老婦人。歩行を収録。 | Petrov_the_blind, [3d Zombie grandma - walking rigged](https://petrov-the-blind.itch.io/3d-zombie-grandma) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| `public/assets/characters/horror-creature.glb` | 赤白まだらの皮膚を持つ人型の変異体。歩行、走行、待機を収録。 | City Building Game Art, [3D Horror Game Monster](https://opengameart.org/content/3d-horror-game-monster) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |

## Web配布条件と表示するクレジット

[CC BY 3.0の公式条件](https://creativecommons.org/licenses/by/3.0/)では、改変とWeb配布を商用を含めて認める代わりに、作品名、作者、出典、ライセンスへのリンク、変更の明記が必要。Thin Zombieについて、公開するゲームの `THIRD_PARTY_NOTICES.md` など利用者が見られるクレジットへ次を載せる。作者からの指定名は **Rosswet Mobile**。作者による本作の推奨・関与を示唆しない。

> Thin Zombie [Awake Zombie Asset] by Rosswet Mobile (submitted by dogchicken), [source](https://opengameart.org/content/thin-zombie-awake-zombie-asset), licensed under [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/). Modified for this game: Blender source converted to GLB, bundled texture reconnected, selected animations exported, and model scale adjusted.

GrannyとHorror Game Monsterは作者ページで[CC0](https://creativecommons.org/publicdomain/zero/1.0/)と明記されており、クレジット義務はないが、出典を上の表に残す。Grannyのitch.ioページは「Name your own price」だが、`No thanks, just take me to the downloads` から£0・ログインなし・メール入力なしで作者ZIPを取得した。ストアへの登録・購入は行っていない。Unity/Godot/Unrealのログインが必要なストアは使っていない。

## 加工と実データ

- `scripts/assets/convert_thin_zombie.py`: 元Blendの既存アクションから8本をGLBにまとめ、同梱PNGをPBRのベースカラーへ接続した。GLBは1.78 MB、スキン1体、テクスチャ1枚、高さ約1.80 m。脚元は原点より約0.032 m高い。
- `scripts/assets/convert_zombie_granny.py`: 元FBXの歩行アクションを残し、原寸3.53 mから1.76 mへ変換。8材質の共通アトラスを1画像にまとめ、約85,000面を約22%へ間引いた。GLBは3.95 MB、スキン1体、画像1枚、歩行クリップ1本。やや低ポリ調の顔・服で、既存の男性や痩身ゾンビとは異なる輪郭。
- `scripts/assets/convert_horror_creature.py`: 作者の `Poses.zip` 内のFBXから歩行・待機・走行を1本のGLBに統合し、同梱のAlbedo画像を接続した。GLBは4.41 MB、スキン1体、画像1枚、高さ約1.85 m。作者ページは攻撃動作も挙げているが、今回使った `Poses.zip` のFBXからは攻撃クリップを確認できず、GLBには入れていない。
- `src/characters.ts`: `loadCharacterLibrary()` が4体（既存の街のゾンビを含む）を読み、`create(kind,id)` がスキン付き個体と動作クリップを返す。`office` は街の男性とGrannyを交互、`runner` はThin、`worker` と `boss` はCreature。戻り値に実寸 `height` と必須 `walk`、存在する場合の `idle/attack/hit/death` を含む。各個体は足元がY=0になるよう配置する。ボスの倍率、攻撃・死亡クリップのない素材への演技補完はゲーム側で扱う。

Blender 5.2.1 LTSを `--background --factory-startup` で起動して変換した。ユーザーの開いているBlenderシーンには触れていない。GLBを再読込して形状・テクスチャ・スキン・クリップ名を確認し、Blenderで静止レンダリングした。ゲーム内の歩行接地、前後の向き、照明下での読みやすさ、攻撃・死亡のつながりはブラウザでの実操作確認が必要。特にGrannyは写実より低ポリ調、Creatureは衣服のない変異体に見えるため、アルファ版のゾンビ表現として採用するか実画面で評価する。

## 取得元とハッシュ

再変換時は以下の作者配布ZIPを `/tmp/nightshift-thin/`、`/tmp/nightshift-granny/Zombie Granny/`、`/tmp/nightshift-monster/Poses/` にそれぞれ展開する。署名付きの一時ダウンロードURLは永続リンクとして記録しない。

| 元ZIP | 安定した取得元 | SHA-256 |
| --- | --- | --- |
| `new_thin_zom.zip` | [OpenGameArtの直接ファイル](https://opengameart.org/sites/default/files/new_thin_zom.zip) | `ba9a8d2a444f36b77f838251103f2c9c3a3d570db3bf1e10fb38b80f4f480b40` |
| `Zombie Granny.zip` | [作者のitch.ioページ](https://petrov-the-blind.itch.io/3d-zombie-grandma) | `5da021d602acd1fbf65ecec4e88d23702e5ea544226f062106b18c7370eb0c01` |
| `Poses.zip` | [OpenGameArtの直接ファイル](https://opengameart.org/sites/default/files/Poses.zip) | `10b7f947b64a6e1cf4f845800f8417d91e830f6df56c24a03922065df2cf0af3` |

| 変換済みGLB | SHA-256 |
| --- | --- |
| `thin-zombie.glb` | `612e5467a0486fd51b52b79ef693db4ba8656c8ba93fa0fbbf1062cbbb303021` |
| `zombie-granny.glb` | `92b25fdb6cd88335c93be7fb9068ec86817d8a93a59f15a5fee63830b338defa` |
| `horror-creature.glb` | `4ca15841b017ec8bbd26d8a0de58a47024a217e56b40db69508dc7c03fc58fc4` |
