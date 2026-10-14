# 全力退勤：アセット改稿 v0.4

ユーザーの依頼は、ゲーム内の3Dオブジェクトごとに完成イメージを約3視点で生成し、その画像を基準にモデリングをやり直すこと。丸い、少し曲がった玩具の造形で、ばかばかしさとコミカルな統一感を作る。

## 制作順と基準

1. 現行の実画面とアセットを棚卸しする。
2. 主役の3視点を生成し、共通の色・形・素材を定める。
3. 家具・破壊物・背景と小物について、各オブジェクトの3視点を生成する。
4. 画像を見てからBlenderで形を作り、GLBと制作ソースを保存する。
5. Godotへ取り込み、実画面・動き・衝突範囲・描画負荷を確認する。
6. 通しプレイとCIを通し、公開済みのGitHub Pagesを更新する。

完成イメージは `art/assets/v0.4/`、Blender制作スクリプトは `scripts/modeling/`、実行用GLBは `game/assets/models/`、制作ソースは `art/models/`、実画面は `docs/verification/v0.4/`。生成画像はモデルの参考資料であり、ゲームのスクリーンショットとは区別する。

## 棚卸しと画像の対応

| シート | 3視点を用意する対象 | 造形の笑い |
| --- | --- | --- |
| 01 主役 | 会社員 | 必死な大きい口、厚い頬、寝癖、巨大な靴と曲がったID |
| 02 乗り物 | オフィスチェア、消火器 | 腫れたような座面、踏ん張る五本脚、太いホースと大きいレバー |
| 03 破壊物 | コピー用紙箱、書類の塔、書類ワゴン | ふくらんだ箱、ばか高い書類、荷物で反る棚 |
| 04 家具 | 机、キャビネット、PCとキーボード | 厚い天板、曲がった脚、ふくらむ引き出し、大きいキー |
| 05 同僚 | 同僚 | 大騒ぎでも無表情、眠そうな目、コーヒーに集中 |
| 06 小物 | 猫マグ、巨大ホチキス、植物 | 猫の耳と口、大きな歯のホチキス、少量の四角い葉 |
| 07 出口 | エレベーター、時計 | ゴールらしい祝福、定時を強く示す時計 |
| 08 オフィス | 壁・窓モジュール、床と案内矢印 | 玩具の縁、夕日、整理された大胆な色面 |
| 09 演出素材 | 紙片、噴射の粉、小さな立方体 | 曲がる紙、丸い粉、少量の角のあるアクセント |

同じ対象の配置違いと色違いは一つのモデルから作る。最初の操作・コース・加点ルールに沿うサイズで作り、見た目の誇張は動ける進路を優先して調整する。

## 統一するルール

- 「角が丸い、おもちゃのオフィス」。単純な球の寄せ集めより、一つにつながる頭、髪、天板や座面のシルエットを重視する。
- 主役は白シャツ、朱赤のネクタイと消火器、青緑の椅子、濃紺のズボン。眉・口・大きい靴で遠くから笑いが読めるようにする。
- 朱赤、青緑、生成り、濃紺、暖かい黄を共通の色にし、マゼンタと水色は小さいアクセントにする。
- 家具は厚い縁と丸い角。破壊物は偏った重心、紙の層、膨らんだ荷物で違いを作る。
- ボクセル感は一部の植物と粒子へ絞る。人物、顔、座面と消火器には滑らかな曲線を使う。
- 3視点は同じ比率と部品で、正面・側面・背面の形が説明できるものにする。
- 頭、表情、腕、脚、ネクタイなどの可動部をモデルのノードとして残す。背景と固定小物は素材と色をまとめて描画する。

## 参考画像・モデル・実際の3視点

参考画像の生成条件は [generation.json](../art/assets/v0.4/generation.json)、モデル一覧と上限は [models.json](../scripts/modeling/models.json)。以下の実視点は、Blenderの参考レンダーではなくGodotで読み込んだGLBを描画したもの。

| 対象 | 3視点の参考画像 | GLB / Blender原本 | 実GLBの正面・側面・背面 | 三角形 |
| --- | --- | --- | --- | ---: |
| 主役の会社員 | [参考シート](../art/assets/v0.4/01-employee.png) | [GLB](../game/assets/models/employee.glb) / [Blender](../art/models/employee.blend) | [正面](verification/v0.4/models/employee-front.png) / [側面](verification/v0.4/models/employee-side.png) / [背面](verification/v0.4/models/employee-back.png) | 14,486 |
| オフィスチェア | [参考シート](../art/assets/v0.4/02-chair-extinguisher.png) | [GLB](../game/assets/models/chair.glb) / [Blender](../art/models/chair.blend) | [正面](verification/v0.4/models/chair-front.png) / [側面](verification/v0.4/models/chair-side.png) / [背面](verification/v0.4/models/chair-back.png) | 4,988 |
| 消火器 | [参考シート](../art/assets/v0.4/02-chair-extinguisher.png) | [GLB](../game/assets/models/extinguisher.glb) / [Blender](../art/models/extinguisher.blend) | [正面](verification/v0.4/models/extinguisher-front.png) / [側面](verification/v0.4/models/extinguisher-side.png) / [背面](verification/v0.4/models/extinguisher-back.png) | 3,540 |
| コピー用紙箱 | [参考シート](../art/assets/v0.4/03-breakables.png) | [GLB](../game/assets/models/paper_box.glb) / [Blender](../art/models/paper_box.blend) | [正面](verification/v0.4/models/paper_box-front.png) / [側面](verification/v0.4/models/paper_box-side.png) / [背面](verification/v0.4/models/paper_box-back.png) | 1,196 |
| 書類の塔 | [参考シート](../art/assets/v0.4/03-breakables.png) | [GLB](../game/assets/models/paper_tower.glb) / [Blender](../art/models/paper_tower.blend) | [正面](verification/v0.4/models/paper_tower-front.png) / [側面](verification/v0.4/models/paper_tower-side.png) / [背面](verification/v0.4/models/paper_tower-back.png) | 2,624 |
| 書類ワゴン | [参考シート](../art/assets/v0.4/03-breakables.png) | [GLB](../game/assets/models/paper_cart.glb) / [Blender](../art/models/paper_cart.blend) | [正面](verification/v0.4/models/paper_cart-front.png) / [側面](verification/v0.4/models/paper_cart-side.png) / [背面](verification/v0.4/models/paper_cart-back.png) | 3,996 |
| 机 | [参考シート](../art/assets/v0.4/04-furniture-computer.png) | [GLB](../game/assets/models/desk.glb) / [Blender](../art/models/desk.blend) | [正面](verification/v0.4/models/desk-front.png) / [側面](verification/v0.4/models/desk-side.png) / [背面](verification/v0.4/models/desk-back.png) | 3,374 |
| キャビネット | [参考シート](../art/assets/v0.4/04-furniture-computer.png) | [GLB](../game/assets/models/cabinet.glb) / [Blender](../art/models/cabinet.blend) | [正面](verification/v0.4/models/cabinet-front.png) / [側面](verification/v0.4/models/cabinet-side.png) / [背面](verification/v0.4/models/cabinet-back.png) | 2,858 |
| PC・キーボード・マウス | [参考シート](../art/assets/v0.4/04-furniture-computer.png) | [GLB](../game/assets/models/computer.glb) / [Blender](../art/models/computer.blend) | [正面](verification/v0.4/models/computer-front.png) / [側面](verification/v0.4/models/computer-side.png) / [背面](verification/v0.4/models/computer-back.png) | 3,968 |
| 眠そうな同僚 | [参考シート](../art/assets/v0.4/05-colleague.png) | [GLB](../game/assets/models/colleague.glb) / [Blender](../art/models/colleague.blend) | [正面](verification/v0.4/models/colleague-front.png) / [側面](verification/v0.4/models/colleague-side.png) / [背面](verification/v0.4/models/colleague-back.png) | 8,796 |
| 猫マグ | [参考シート](../art/assets/v0.4/06-desk-toys.png) | [GLB](../game/assets/models/cat_mug.glb) / [Blender](../art/models/cat_mug.blend) | [正面](verification/v0.4/models/cat_mug-front.png) / [側面](verification/v0.4/models/cat_mug-side.png) / [背面](verification/v0.4/models/cat_mug-back.png) | 2,198 |
| ワニのホチキス | [参考シート](../art/assets/v0.4/06-desk-toys.png) | [GLB](../game/assets/models/stapler.glb) / [Blender](../art/models/stapler.blend) | [正面](verification/v0.4/models/stapler-front.png) / [側面](verification/v0.4/models/stapler-side.png) / [背面](verification/v0.4/models/stapler-back.png) | 2,300 |
| 植物 | [参考シート](../art/assets/v0.4/06-desk-toys.png) | [GLB](../game/assets/models/plant.glb) / [Blender](../art/models/plant.blend) | [正面](verification/v0.4/models/plant-front.png) / [側面](verification/v0.4/models/plant-side.png) / [背面](verification/v0.4/models/plant-back.png) | 2,297 |
| 出口のエレベーター | [参考シート](../art/assets/v0.4/07-exit-clock.png) | [GLB](../game/assets/models/elevator.glb) / [Blender](../art/models/elevator.blend) | [正面](verification/v0.4/models/elevator-front.png) / [側面](verification/v0.4/models/elevator-side.png) / [背面](verification/v0.4/models/elevator-back.png) | 3,846 |
| 17時の時計 | [参考シート](../art/assets/v0.4/07-exit-clock.png) | [GLB](../game/assets/models/clock.glb) / [Blender](../art/models/clock.blend) | [正面](verification/v0.4/models/clock-front.png) / [側面](verification/v0.4/models/clock-side.png) / [背面](verification/v0.4/models/clock-back.png) | 2,280 |
| 壁と窓 | [参考シート](../art/assets/v0.4/08-office-modules.png) | [GLB](../game/assets/models/window_module.glb) / [Blender](../art/models/window_module.blend) | [正面](verification/v0.4/models/window_module-front.png) / [側面](verification/v0.4/models/window_module-side.png) / [背面](verification/v0.4/models/window_module-back.png) | 2,436 |
| 床と案内 | [参考シート](../art/assets/v0.4/08-office-modules.png) | [GLB](../game/assets/models/floor_module.glb) / [Blender](../art/models/floor_module.blend) | [正面](verification/v0.4/models/floor_module-front.png) / [側面](verification/v0.4/models/floor_module-side.png) / [背面](verification/v0.4/models/floor_module-back.png) | 1,216 |
| 飛ぶ紙片 | [参考シート](../art/assets/v0.4/09-fx-objects.png) | [GLB](../game/assets/models/fx_paper.glb) / [Blender](../art/models/fx_paper.blend) | [正面](verification/v0.4/models/fx_paper-front.png) / [側面](verification/v0.4/models/fx_paper-side.png) / [背面](verification/v0.4/models/fx_paper-back.png) | 410 |
| 噴射の粉 | [参考シート](../art/assets/v0.4/09-fx-objects.png) | [GLB](../game/assets/models/fx_powder.glb) / [Blender](../art/models/fx_powder.blend) | [正面](verification/v0.4/models/fx_powder-front.png) / [側面](verification/v0.4/models/fx_powder-side.png) / [背面](verification/v0.4/models/fx_powder-back.png) | 420 |
| 立方体のアクセント | [参考シート](../art/assets/v0.4/09-fx-objects.png) | [GLB](../game/assets/models/fx_cube.glb) / [Blender](../art/models/fx_cube.blend) | [正面](verification/v0.4/models/fx_cube-front.png) / [側面](verification/v0.4/models/fx_cube-side.png) / [背面](verification/v0.4/models/fx_cube-back.png) | 176 |

20モデル合計67,405三角形、GLB合計1,928,716バイト（約1.84MiB）。各モデルは1素材。主役の表情・手足は13グループ、椅子と床は各2グループ、その他は1グループにまとめた。

## 作り直す手順

通常のゲーム開発には追跡済みGLBを使うためBlenderは不要。モデルの再制作はBlender 4.3.2とPython 3を使う。スクリプトの座標はGodotのX右・Y上・前-Z、寸法は全幅。色はglTF仕様に沿ったlinear頂点色で保存する。各文字の向きは3視点で確認する。

```bash
cd 2026-10-14
npm run assets:build
npm run check
godot --path game --script res://tools/render_assets.gd
```

`BLENDER_BIN` でBlenderを指定できる。最後のコマンドはネイティブの描画画面が必要で、実GLBの3方向を `docs/verification/v0.4/models/` へ保存する。

## 実画面での調整

- GLBのlinear頂点色はGodot Compatibilityのアルベドへ渡す前にsRGBへ一度変換。肌・布・木・椅子の色が必要以上に暗くなる問題を直し、モデルごとに変換済みメッシュを共有する。
- 顔を見せるため、着席した主役は肩越しに振り返る。成功時は左腕だけを上げ、消火器で目や口を隠さない。
- プレイカメラを少し近づけ、暖色の照明に白い環境光を足す。モデルの3視点レンダーには2×MSAAを使う。ゲームではクラウドのWeb描画で大きな負荷が出たため、既定のMSAAを使わない。
- 案内帯は床の背景タイルから分離し、元の曲がるコースに沿って配置する。遠景で見えない床タイルの8mmベベルを省き、45枚の床から34,560三角形を削減。静的な模型は16mの区画ごとにまとめ、破壊物は個別に隠せるように残す。

改稿前は [タイトル](verification/v0.4/before-title.png) / [プレイ](verification/v0.4/before-play.png)。改稿後の [タイトル](verification/v0.4/after-title.png) / [プレイ](verification/v0.4/after-play.png) は実際に起動したネイティブ版。ブラウザの通しプレイと制約は [VERIFICATION.md](VERIFICATION.md) に記録する。
