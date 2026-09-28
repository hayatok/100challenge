# v0.4 敵キャラクターの品質調整

更新日: 2026-09-28。対象は `src/characters.ts` と `src/character-motion.ts`。目標画像は `art/reference/gameplay-approved-v1.png`、変更前の実画面は `art/verification/v03-enemies.png` と `v03-boss.png` を参照する。

## 採用した表現

実際にゲームが読み込む原作者モデルは **2体**。Rikindle3D の City Zombie（CC0）と Rosswet Mobile の Thin Zombie（CC BY 3.0）である。City のスキン付きシャツ・ズボンを使い、同じ骨格のまま材質の明度模様と体格を変えて、事務員2色・幅広の作業員・大柄な店主ボスに分けた。これは **4体の新規モデルではなく1体からの外観差分** である。Thin は走者として残す。新しい外部モデルやライブラリは加えていない。

v0.3 の Granny は低ポリ調の巨大な髪と前傾姿勢で顔が隠れ、実ゲームでも頭部のテクスチャが破綻したように見えたため、出現枠から外した。Horror Creature は衣服のない変異体で商店街の生活感から外れるため、作業員・ボスへの割当を外した。両ファイルは現時点で `public/assets/characters/` に残るが、v0.4 の読み込み対象ではない。公開物から削除する場合は `THIRD_PARTY_NOTICES.md` と公開ビルドの中身を同時に確認する。

City の衣服テクスチャは赤成分が強く、単純な乗算では黄土色や青灰色の布にならない。材質シェーダーで元画像の明暗を保持しながら色を再マップする。形状やUVは作者のスキン付きメッシュそのものなので、以前試した浮いたエプロン・肩当て・徽章のような独立プリミティブは使わない。個体のマテリアルは4パレットごとに共有し、生成のたびに新規シェーダーを増やさない。

ボスは City の大柄な店主変異体として見せ、死亡時に既存の短い倒れるクリップを選ばせず、腰・腿・膝・胸の骨で約1秒かけて片膝をつき、その後約2.45秒までに前へ崩れる。前フレームの補助回転と腰位置は毎回戻してからミキサーを更新する。死亡中は歩行周期を止め、骨だけが崩れる。`CharacterLibrary.create` と `CharacterMotion.step/target/dispose` の呼び出し契約は維持した。

## 候補調査と選定理由

- [3DAssets.dev Infected site worker](https://3dassets.dev/assets/undead-horde-and-infected-variants-walker-site-worker-60055167) は CC0、アカウントなしで GLB を取得できた。元ページが明記するようにリグ・アニメーションがなく、Blender 試写でも顔と衣装の面が単純で承認画像の造形密度に届かなかったため不採用。ダウンロードした試験ファイルの SHA-256 は `455cf953f9234a672626e22fe8c94266d1f9b4849fd8c276447da7ececce7b49`。配布物へ入れていない。
- [pixelhouse の zombie](https://opengameart.org/content/zombie) は CC BY 3.0、着衣と3本のアニメーションを持つ。作者ZIPをアカウントなしで取得したが、FBX がバージョン6100で、Blender 5.2.1 と既存の Assimp がともに読み込めなかった。取得ZIPの SHA-256 は `062733d16d1ac3146fd82de55ffadb71ab09fcad119c2f8002edae50b9d2a880`。配布物へ入れていない。
- [CDmir の Old Lady](https://opengameart.org/content/old-lady) は CC0 で着衣・リグ付き。元の Blender ファイルは座る動作のみで、試写でも舞台の人物より彫像に近い見え方だったため不採用。取得 Blend の SHA-256 は `02e6acd66a07cdc1fb452516c87e8399b6a4b393b0501050b1b120fcb19e9b27`。配布物へ入れていない。

既存の2体の作者・ライセンス・変換・ハッシュは `CHARACTER_ASSETS.md` と `ALPHA_CHARACTER_ASSETS.md`、配布時の表示は `THIRD_PARTY_NOTICES.md` に記録する。

## 確認と残る差

`npm run check` で28件のコアテスト、lint、型チェック、production build が通過した。GLB2体の既存ボーン名とクリップ名を照合した。WebGL の1440px実画面 `/tmp/nightshift-v04-skin-final.png` では初回の白飛びを修正し、顔と服に陰影が戻った。ボスの膝・接地は通しプレイで評価する。新規に人物をモデリングしたわけではなく、作業員の衣服形状もシャツ・ズボンのままで、承認画像の工事用ヘルメットや店主のエプロンはまだない。**肌とシャツの色・質感の分離、顔の精細さは次版の課題**。写実度と人数は承認画像へ届いていない可能性があり、静止画と通しプレイで評価する。
