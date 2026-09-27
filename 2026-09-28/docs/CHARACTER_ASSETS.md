# 人物・一人称の手と銃の素材

取得・確認日: 2026-09-28 (Asia/Tokyo)。下記3点は作者が公開した元ファイルから取得し、アカウント登録・購入なしで使用できる。GLBはBlender 5.2.1 LTSを `--background --factory-startup` で起動して変換した。ユーザーのBlenderシーンには触れていない。

| 用途 | 作者・元ページ | ライセンス | 実行時ファイル | 内容 |
| --- | --- | --- | --- | --- |
| ゾンビ | Rikindle3D, [Male City Zombie](https://opengameart.org/content/male-city-zombie-ready-for-use-in-game-engines) | CC0 | `public/assets/characters/zombie.glb` | スキン付き人物、66骨、PBR画像6枚、11動作 |
| ハンドガン | loafbrr_1, [Pistol](https://opengameart.org/content/pistol-5) | CC0 | `public/assets/weapons/pistol.glb` | 銃身・スライド・ハンマー・弾倉等の独立メッシュ8個、PBR画像3枚 |
| 一人称用の腕 | para, [fps arms (rigged only)](https://opengameart.org/content/fps-arms-rigged-only) | CC0 | `public/assets/weapons/fps-arms.glb` | 皮膚テクスチャ付きの両腕、スキン・骨格あり、組み込み動作なし |

元の配布ファイルは実際に取得して変換・ハッシュ確認した。公開ビルドへ不要な元ZIP/7z/FBX/Blendは含めず、実行時GLBだけを置く。再変換する場合は下記の作者配布アーカイブを同名フォルダへ解凍してから `scripts/assets/convert_rikindle.py`、`pose_zombie.py`、`convert_pistol.py`、`convert_arms.py` を順に必要に応じて使う。CC0のためクレジット表記は必須ではない。腕の元メッシュ・皮膚はMakeHuman由来と作者が説明しており、[MakeHuman公式ライセンス](https://static.makehumancommunity.org/about/license.html)はコアの図形素材をCC0としている。

| アーカイブの直接取得先 | 解凍先 |
| --- | --- |
| [Male City Zombie.7z](https://opengameart.org/sites/default/files/Male%20City%20Zombie.7z) | `public/assets/characters/rikindle-city-zombie/` |
| [pistolfbxgltftexturesblend_1.zip](https://opengameart.org/sites/default/files/pistolfbxgltftexturesblend_1.zip) | `public/assets/weapons/loafbrr-pistol/` |
| [fps arms.7z](https://opengameart.org/sites/default/files/fps%20arms.7z) | `public/assets/weapons/para-fps-arms/` |

## ゾンビの実データ

- 元ファイル: `InfectedCityMan.fbx` と11の動作FBX。作者ページには歩行、攻撃3種、待機2種、被弾、死亡、走行、叫びが明記されている。テクスチャはBodyとOutfitに各BaseColor、Normal、OcclusionRoughnessMetallicを使用。
- 元ページで作者はテクスチャをMudboxで自身が制作したと回答している。
- GLB内のクリップ名: `Walking`, `Zombie_Walk`, `Zombie_Idle`, `Zombie_Idle2`, `Zombie_Attack`, `Zombie_Attack2`, `Zombie_Attack3`, `Zombie_Reaction_Hit`, `Zombie_Dying`, `Zombie_Running`, `Zombie_Scream`。全クリップに骨格用チャンネルが入っていることを確認した。
- glTF座標はY上。正面は **+Z**、足元はY≈0、標準姿勢の高さは約1.8m。ゲーム内の敵の向きと大きさは実画面で調整する。
- 元の人物と動作FBXでは骨名の接頭辞がそれぞれ `CityDeadOutfit:` と `mixamorig:` だった。変換時に基礎モデル側の骨名と頂点グループ名を動作側に合わせ、11動作をNLAトラックとして統合した。元の `Zombie_Walk` は両腕が横に広がり、実画面で十字形に見えたため、`pose_zombie.py` で同クリップの上腕と前腕の回転サンプルだけ補正した。脚、骨格の基準姿勢、他の動作は維持している。Three.jsのAnimationMixer再読み込みで、歩行中の手が肩より約0.3〜0.46m前に出て、肘も曲がることを確認した。接地、攻撃・被弾・死亡のつながりはゲーム画面で評価する必要がある。
- 近景での肌・衣装の密度や陰影は承認画像と同水準とは確認できていない。元素材は黒・赤が強い感染者の造形で、承認画像にある青白い顔や普段着の細部に合わせた色調・衣装調整は今後の作業となる。

## 銃と腕の実データ

- 銃の元ZIPには埋め込みテクスチャ付き `Pistol.gltf` があり、これをGLBへ書き出した。銃身、スライド、ハンマー、弾倉等は個別のオブジェクトとして残る。組み込み動作はないため、反動・排莢・スライド動作はゲーム側で付ける。
- 腕の元7zには `new_diff.png`、Blender/FBXのリグと簡単な試験アニメーションが入っている。GLBには素体のスキンとテクスチャを入れ、試験アニメーションは採用していない。銃の握り、手首、黒い袖・手袋はゲーム画面に合わせて調整する。
- 銃と腕は別作者の素材で、現在は共通の握りポーズとして完成していない。承認画像の右下の見え方は、実際に合わせ込んで評価する。

## 元データのSHA-256

| ファイル | SHA-256 |
| --- | --- |
| `rikindle-city-zombie/source.7z` | `2858c0c4968740b372108afc64ba009ef4d0e0425edbb5dc3dc50d46f4d0a661` |
| `zombie.glb` | `8251d673999ebd99d8f3740c844deef05ae7c377eb45813eb6130a05b9ec50b2` |
| `loafbrr-pistol/source.zip` | `3aa9970b4b601fc37a6e6034bfe53f1ebc00fd56cc0a2abb6542abf34e7754f0` |
| `pistol.glb` | `9e27c95402667d4c225ab31d2a5b7efa2f1f55729459788fdfbe92684ab9f4f3` |
| `para-fps-arms/source.7z` | `31f6c7bd5caea8856c4aafca8461f38a3c8bfdd3d8f05c898e403b9475e54562` |
| `fps-arms.glb` | `795606e58d70bf87e1a1cbf304b5f0e5f768168fb10c095c83e62ac43792cffc` |
