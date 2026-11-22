# 紺谷・浦 v1.4 衣装

衣装の色と形は[GPT Imageの二人の原画](wardrobe.png)、手首とシャツ袖の隙間は[浦の接写原画](ura-cuffs.png)に合わせた。仕立てには既存の頭部とCC0のスーツを使った。[金星の照明で撮影した二人](../../evidence/v14/README.md)

## 2つの初期化フック

KinseiActor.Init は次の順で衣装を組み立てる。

1. UpgradeSkin/BuildSidearm後、MergeSurfaces前: `ApplyHallWardrobe(role, variant);`
2. KinseiWardrobeBinding.Dress直後: `DressHallTailoring(role, variant);`

どちらの処理もホールの紺谷（guard 0）と浦（guard 1）だけに適用する。二階の四人は既存の衣装を着る。

前フックでは個体のcloth/collar/shirt/tieを調整し、紺谷の眼鏡をheadへ生成する。後フックで最終的に表示される `Tailored Navy suit` の所有MaterialとSkinnedMeshを捕まえ、2人専用のアトラスへ置換する。衣装共有元のResourcesメッシュや他個体のMaterialは変更しない。追加MaterialはextraMaterialsへ登録し、追加Meshは既存cleanupに任せる。既存の頭、口、まぶた、目線、動作は保持する。

## 紺谷

角を丸めたフレームを64分割し、半径1.65 mmの八角断面でべっ甲の縁を作った。細い蜜色のブリッジは鼻梁に載り、左右のつるは耳の後ろまで伸びる。湾曲したレンズの専用シェーダーは中心から半径88%まで透明にし、外縁にだけ最大0.028の不透明度で色を重ねる。[ホールの灯りで眼鏡越しに見た紺谷の目](../../evidence/v14/kontani-view-published.png)

実衣装のrest座標から16 mmピッチの青い細線を2048角アトラスへ焼く。袖/肩/胴/背中/脚のUVへ線が載り、腕の動きでは元のスキン重みに従う。原画の暗さをそのままalbedoにせず、舞台の蜂蜜光でも青の中間調が残るRGB(48,59,82)を基準に元の織地陰影を保持する。光らせて黒を持ち上げる方式は使わない。元の布normalを引き継いだ専用KontaniNormalを0.48で併用する。タイ島だけは無地のnormalへ置換する。

## 浦

基準RGB(108,68,72)の桑色へ、元の布の大きな陰影・ポケット・シャツを保持して色を置換する。元の細線を拡散色の低周波化と専用UraNormalで取り除き、細かな織地の凹凸へ置換する。元スキン衣装の独立した襟2島433頂点を特定し、内側の折り、首への取付け、ノッチを残し、外側の葉だけ最大30 mm拡げる。bone/bindpose/weightsは維持する。単純な平板をかぶせる処理は採用しない。

実衣装の胸ポケットは+X側、rest高さ約1.26 m。この位置へ生成り麻の折りチーフを1.2/1.3 mm厚の表裏・側面を持つ2面で追加し、折り山に光が乗るようにする。

暗赤の実タイへ二組の控えた金斜線を焼く。太線3 mm、添え線1.1 mm、組内の中心差5 mm。タイのrest高さ1.276/1.342 m、傾きy=1.25xに配置。別の板をタイの前へ浮かせず、タイの表面と同じ変形・遮蔽に従わせる。

## 手首とカフス

両人の手首では、手の開口の40頂点を前腕側の皮膚とつないだ。シャツ袖の外径は59 × 54 mm、内径は48.4 × 44.4 mm。骨への追従率を手と合わせ、手を上げたときも袖から手首の断面が見えないようにした。[構えと歩行からの接地・継ぎ目の実測](motion-check/README.md)

## 再生成・ライセンス

- `build_wardrobe_maps.py`: seed 1414、Python/Pillow/NumPy。元のフォールバック布用の紺線/桑織地（1024角）とオリジナルべっ甲（256角）。画像の切出しや外部パターンは使用しない。
- `bake_hall_atlases.py`: 既存 `KinseiWardrobe/Single.bytes` と `Navy.jpg` を入力に、実衣装のUV/座標/原画方針からKontaniAtlas/UraAtlasと専用Normal（すべて2048角）、UraLapelFit.bytesを再生成する。元タイの白い柄も含め、タイ島451+272頂点に対応するUVを無地へ置換する。実衣装の既存CC0出典は `art-source/wardrobe/SOURCES.md` に従う。
- `preview_tailoring.py`: Blenderで実際にexport済の衣装データを比較し `tailoring-offline.png` を生成する。これはオフライン衣装検査で、ゲーム内の照明/眼鏡/動き/チーフを検証する画面ではない。

アトラスのmetaはsRGB、Repeat、Trilinear、ミップ有効、異方性4。追加のゲーム依存ライブラリはない。手元の既存Blenderと制作ツールだけを使用する。

## 検証範囲

基本衣装は9,795頂点。浦の襟にはそのうち433頂点を使った。布の縮尺と輪郭の違いはBlenderで確認した。Windows上での照明、人物が動いたときの見え方と記録した解像度は[ホールの実機検証記録](../../evidence/v14/README.md)に記載する。
