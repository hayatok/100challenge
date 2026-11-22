# 金星の実況卓　筐体と送出つまみ

[設計原画](../broadcast-listeners/desk-hand.png)では黒い琺瑯の地に真鍮の操作部が浮き、指が触れる位置だけ金色が明るい。改修前のWindows版でも、[指掛けに触れる左手](../../evidence/v14/rotation-basedial.png)、[手を引いた後](../../evidence/v14/release-basedial.png)、[送出後の管面](../../evidence/v14/monitor-basedial.png)を同じ二つのカメラで確認した。

## 面ごとに選んだ原画

|原画|ゲーム内での割付|
|---|---|
|[琺瑯A](originals/enamel-a.png)|前板。点状の塗り欠けが下の折り返しに集まる向きで全面を1回貼った。|
|[琺瑯B](originals/enamel-b.png)|上蓋と左右の返し。右端の明るい線を裁ち、奥行き方向にUVを合わせた。|
|[真鍮A](originals/brass-a.png)|直径46 mmの二つのつまみの正面。盤の旋削中心とUVの円心を重ね、外の濃い円は裁ち落とした。|
|[真鍮B](originals/brass-b.png)|つまみの周面。中央帯を左右に反転して端をつなぎ、指が触れる表側の列に明るい帯を割り付けた。|

原画4点はローカルComfyUI（2c75dc1b379a59e0880619d029607af5169a62ef）のMOSS-Imageで生成した。設定画は目視参照。各モデル・サンプラーの[実行グラフ](originals/graph-template.json)と[実際の正負プロンプト、seed、prompt ID、寸法、出力SHA-256](originals/runs.json)を収録した。再送信する場合はグラフの4／5番の text、6番の width／height、7番の seed、9番の filename_prefix を各記録に合わせる。

## 形状と操作点

筐体は幅560 × 高さ160 × 奥行190 mm。上蓋と前板の境に2.5 mm幅の溝を設け、端を複数段の面で折り返した。正面のねじ4本は直径7.2 mm。頭を二つの金属面に割り、溝から暗い底が見える。管面にはパッキンと幅約0.8 mmの磨き縁を添えた。ガラス中央は既存の湾曲した中継管面が映像を受ける。

各つまみの周面には36本、深さ0.75 mmの縦溝がある。送出つまみ本体と幅9 mmの白い指掛けは同一の軸で68度回る。つまみ中心の世界座標は (−1.9216, 0.9893, 0.8516) m。指掛けの中央は軸のローカル (0, 0.012, 0.020) m、両側のつまむ面はそこから左右4.5 mm。外装の差し替えに伴う手・カメラの目標座標の変更は0 mm。

[二視点のCPU形状図](console-geometry.jpg)は左からCで見る操作面（垂直画角43度）、送出後の管面（38度）。完成メッシュの表面、UV、指掛けの向きを確認するため、追加部品だけを描いた。手、送出映像、ランプ、卓板と舞台照明はWindows版の記録を参照する。

## 再生成

Python、NumPy、Pillowで次を実行する。build.pyは原画のハッシュを照合し、1024角のsRGBアトラスと8部材の頂点・法線・UV・三角形を書き出す。6,180三角形のうち送出つまみと白い指掛けの2部材が可動。残りはワールドの既存の静的バッチに入る。

```powershell
python 2026-11-22/art-source/broadcast-console/build.py
python 2026-11-22/art-source/broadcast-console/preview.py
```

出力先は Game/Assets/Resources/KinseiBroadcastConsole。Console.bytes のSHA-256は 7fa6a6741b8711470975ac663fc3fc35a4e97571b8fe442f3d0bdd0cb32331bd、Finish.jpg は fd1045d9886035b660112e776485ae393e92f579d44912e7658fce64b54a3324。表面模様は生成原画、形状とUVは本作用に制作した。金属度・平滑度はUnity Standard材質で設定した美術値。
