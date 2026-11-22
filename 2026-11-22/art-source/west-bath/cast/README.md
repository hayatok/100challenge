# 西橋の三人・v1.5

[文子・喜一・瀬尾の衣装原画](../residents-and-seo.png)から生地、髪、履物、手荷物を決めた。[西の湯の原画](../bath-frontage.png)に描いた店先の照明で、三人が橋のどちら側にいるかを見分けられるようにした。

## 実装と役

`KinseiActor.WestBath.cs` と本体の3箇所だけを接続する。

- UpgradeSkin呼出しを `UpgradeWestSkin(boss,makabe,kaji,variant)` に置換。対象外役は従来処理を呼ぶ。
- 最終衣装のDress後に `DressWestBath(role,variant)`。
- Pose最終に `PoseWestBath(state,speed)`。

文子 `west-fumiko`: 既存Sumikoの詳細女性頭部/肌/眼（Asian female old 86%とOld Eurasian Female肌）を継承。髪は短いパーマ形状へ置換して灰色の巻きを混ぜる。深緑の前立て・貼りポケット付きカーディガンと生成り丸首、暗い茶灰パンツ。体格を91/92/91%へ。右手に実編み目と空洞を持つ籐の湯籠。タオルの朱線、石鹸箱、蓋付き茶瓶を入れる。

喜一 `west-kiichi`: Elderの詳細頭部/肌、銀白の髪。茶の実スキン作業着は背広の襟/タイを除き、開襟、釦、胸と腰の貼りポケットを追加。炭灰のパンツ、わずかに幅が広い体格。左手に内側/巻いた紺の縁まで造形した薄青琺瑯洗面器と折りタオル。

瀬尾 `seo`: Adultの詳細頭部、灰の混じる髪、少し大きい体格。元Doubleのスキンを使いオリーブ炭のダブル前合わせを維持。タイの独立島528頂点を非表示化した専用cut、中央のシャツ喉元を開き、シャンパン色と首の肌を出す。従来Singleの上にダブルを貼る方式ではない。

## 持ち方・接続

持ち物は手首へ固定して回転させるだけではなく、歩行/停止の最終Poseで片腕を外側の運搬位置へReachPalmし、IKが実際に達成した掌を取り直す。その掌へ持ち手の実local gripを一致させる。`TransformVector`を使うので非一様体格scaleでも持ち手と掌のずれを蓄積しない。文子の既存指curlは78%のまま。喜一は一般curlを使わず、本人のimport済み左手だけへ追加した「琺瑯の縁を内外から挟む指」shapeを100%にする。既存の歩行/idleの他の腕と脚は維持する。

文子は右側、籠の低い本体は腿より外側へ。喜一は左前方、洗面器の後端を腹の前へ置く。歩行のごく弱い揺れは持ち手を支点にし、停止時は減衰する。既存1.4のFitHallCuffsを専用スキンにも使い、肌と袖口の連続性を維持する。

## 制作データ・出典

`build_cast.py`（Python/NumPy/Pillow、seed1515）が既存 `KinseiWardrobe/Single.bytes`, `Double.bytes`, `Navy.jpg`, `Rust.jpg` とnormalからCut/Cloth/Normalを再生成する。元衣装はMargaret ToigoのMakeHuman Community CC0衣装。元の出典とライセンスは `../../wardrobe/SOURCES.md`、人物頭部/肌は既存cast/residentsの出典に従う。追加の籐/織地/テリー/銀髪はオリジナルの数式/形状。

`generation.json` に頂点/三角形/除去島数を記録。最終Cutは文子/喜一12174tri、瀬尾9066tri。UVとbone weightsを継承する。cloth/normalは2048角、テリー/銀髪は512角。normalはlinear NormalMapとして明示的metaを付けた。

## 検証の区分

原画、既存Skin/実衣装バインド/袖接続/ReachPalm/cleanupの実装を確認し、生成器を実行、binary寸法とindex/count整合を確認。新衣装はbody配下に置き既存mesh cleanupへ、MaterialはextraMaterialsへ登録。

Windows版での歩行、荷物を持つ手、玄関の照明と指揮画面を[西橋の実機記録](../../../evidence/v15/README.md)で比較できる。


## 喜一の外周把持の修正と計測

初版は掌の抽象点を器に当て、指が中央タオルへ開いて器が浮いて見えた。最終候補は手前左45度の紺縁（local -0.11667262, 0.087, +0.11667262 m）を基準に、親指を内側へ対向させ、4指を外壁へ垂らして末節を曲げた。手首・掌と体格、文子とv1.4の手は変更していない。器の本体を脇前方へ寄せ、歩行中も実際の手の接点へ追従させる。

`kiichi-hand-study.json` はEditorで実import・1.4袖フィット後に採取した本人のneutral手表面。`fit_basin_grip.py` は採用した指形状を再現する。`preview_basin_grip.py` をBlenderで実行すると前/横の形状検査画像を再生成できる。オフライン画像はゲーム内撮影ではなく、最終C#の補正定数を含んだ形状確認。

Editor限定 `KinseiActor.ProbeWestKiichiRim` は現在の実bone、BakeMesh後の指、持ち物のtransform/非一様scaleを使う。結果は `kiichi-rim-runtime-metrics.json`。歩行位相の単位は1周期=0〜1。idle 1点と、歩行0 / 0.125 / 0.250 / 0.375 / 0.500 / 0.625 / 0.750 / 0.875の8分割を測った。

- 親指表面〜紺縁の基準断面: 0.226〜0.227 mm。接点は基準円の内側0.754 mm。
- 4指表面〜基準断面: 0.116 mm。接点は外側2.615 mm。
- 手側の把持支点〜器側支点: 最大0.000123 mm。

断面距離は半径165 mmの縁の中心円と2.7 mm断面半径に対して実指頂点から測った値。表示メッシュは64分割/8角断面のため、円断面との差が約0.2 mmある。この数値を画面での接触確認の代用にはしない。最終nativeの前/横の確認は実機記録を参照する。Editor export/probeと計測専用データはPlayerへ含まれない。
