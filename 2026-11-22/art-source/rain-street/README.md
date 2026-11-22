# 雨上がりの金星通り

GPT Imageで作った[照明と靴の原画](street-at-shoe-level.png)では、手前の靴が起こす波、舗装の山に残る乾いた粒、庇の電球が水面に映る位置を比較できる。[原画に使った指示](street-prompt.txt)

もう一枚の[受像機の原画](street-receiver.png)は、店主と常連が閉店後に歌手の姿を見守る場面。濡れた筐体、管面の中の舞台灯、道に返る筐体の明かりを一緒に検討するために作った。[原画に使った指示](receiver-prompt.txt)

路面には3枚、受像機には2枚の表面原本を使う。画像は1024角。金星の看板や通行人の姿は、その場でUnityのカメラが描画する。

|原本|Unityに渡す値|生成記録|
|---|---|---|
|[舗装の骨材](Asphalt.png)|幅26 cmの表面。盛り上がった粒の高さを明るさから取り、水の縁を割る。|[Asphalt.json](Asphalt.json)|
|[舗装のくぼみ](Basin.png)|黒い水だまりと、先に乾いて明るくなった島を分ける。|[Basin.json](Basin.json)|
|[細かなさざ波](Ripple.png)|幅12 cmの水面。左右と上下の傾きを別々の色成分にする。着地の輪は靴の位置から別に描く。|[Ripple.json](Ripple.json)|
|[象牙色の琺瑯](Enamel.png)|受像機と切替器のケース。端の丸みと、塗膜から点々と見える地金を近くで見る。|[Enamel.json](Enamel.json)|
|[スピーカーの織布](Grille.png)|金色の保護桟の奥に張った濃茶の布。横糸が縦糸より明るい。|[Grille.json](Grille.json)|

[make_surfaces.py](make_surfaces.py)はMOSS-Imageの5回のComfyUI実行を再現する。[prepare.py](prepare.py)は原本のSHA-256を照合し、路面の反復する端を合わせてゲーム用の画像を作る。

[美術補遺37～39頁](../Kinsei-Art-Supplement.pdf#page=22)に、GPT Imageの原画2点とMOSS素材原本5点を収録した。実機写真3点は同じWindows版の配布ZIP（SHA-256 `4e6a1eef3a0d9ce8eabceb23a4e2cd774f3d5da32096dbe7a16499214167aba9`）を使用した。

|頁|Windows実機の図版|読み取れるもの|
|---|---|---|
|37|[金星前の路面](../../evidence/v16/water-pixel1080.png)|舗装の上に映った受像機の下縁と選局器。|
|38|[選局器の逆像に重なる脚](../../evidence/v16/second3-pixel1080.png)|水面に映った赤茶のズボンの二筋。誌面は部分拡大。靴先だけの鏡像は判別しづらい。|
|39|[受像機のC視点](../../evidence/v16/dial-pixel1080.png)|金星の放送、管面下のつまみ、スピーカーの保護桟、チャンネル表示。|

[二人が水際へ走る全景](../../evidence/v16/feet2-pixel1080.png)と[同じ視点の直前の画面](../../evidence/v16/feet3-pixel1080.png)では、反射に脚が重なる前の選局器の形も確認できる。

[図版別の出典目録](../Kinsei-Art-Supplement.sources.json)には元画像のSHA-256、撮影画像の切り出し範囲、MOSSの実行IDとseedを記載した。
