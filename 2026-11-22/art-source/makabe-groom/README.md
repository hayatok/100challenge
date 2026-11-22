# 真壁の七三と襟足

真壁専用のメートル単位モデル。金星の客車で耳から上が暗い一塊になっていたため、耳輪を出す生え際、耳の前のもみあげ、後頭部から首へ向かう流れを同じ頭部メッシュ上で作った。櫛を入れる方向は、左の分け目から頭頂を横切り、こめかみと襟足で下に向く。

[CPU比較](comparison.png) の上段は旧モデル、下段は新モデル。左から耳際・後頭部・分け目。両段のカメラと照明は各列で共通。頭部と肌は既存素材を使い、単体形状の比較用に眼球、衣服、ゲームの光学効果を省いた。元のゲーム画面は [車内の真壁](../../evidence/v09/saloon-glass.png)。

## 形状と素材

頭皮は既存の MakeHuman CC0「HeadAdult.obj」を使った。ライセンスと頭部の原典は [キャスト素材記録](../../Game/Assets/Kinsei/Cast/README.md) を参照。髪型、束、毛流れのシェーダーは今回の制作。外部の毛髪テクスチャは使っていない。

- 完成形は9,366頂点、18,288三角形。旧HairAdultは8,960三角形。真壁1人の差分は9,328三角形。
- 閉じた頭皮カバーと110本の細い立体の束を、1メッシュ・1不透明マテリアルにまとめた。ジオメトリの開いた辺・非多様体辺と、土台表側の内向き面は0。追加ライトによるForwardAddと影には追加パスが発生する。
- 耳の上で頭皮の外面をサンプリングし、耳の付け根に当たっていた2箇所を補正した。土台表面の三角形の重心と3辺中点で最小間隙0.115 mm。生え際の縁は0.40～1.12 mm、裏側は1.6 mm頭皮内に収めた。束端は最低0.83 mm土台に入っている。
- UVの縦方向を毛流れとし、接線方向に沿う反射に櫛の束の粗密を加えた。遠距離の細い縞は画面微分で低減する。透過レイヤー、毛束ごとの追加描画、毎フレームの毛髪頂点更新は使用しない。

## 再生成

Python、NumPy、SciPy、Pillowを使用。コマンドは日付フォルダから実行する。

```powershell
python art-source/makabe-groom/build.py Game/Assets/Resources/KinseiCast/HeadAdult.obj Game/Assets/Resources/KinseiMakabe/MakabeGroom.obj --measure art-source/makabe-groom/metrics.json
python art-source/makabe-groom/preview.py Game/Assets/Resources/KinseiCast Game/Assets/Resources/KinseiMakabe/MakabeGroom.obj art-source/makabe-groom/comparison.png
```

CPU比較は形状・毛流れの近似描画で、エディター／配布版のフレームではない。夜の客車、朝の窓際、走行中の輪郭のちらつき、実GPU時間は統合後の確認項目。
