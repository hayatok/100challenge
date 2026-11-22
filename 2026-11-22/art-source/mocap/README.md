# 歩行と走行のモーションキャプチャ

Carnegie Mellon University Graphics Lab の被験者16の光学マーカーを使用した。The data used in this project was obtained from mocap.cs.cmu.edu. The database was created with funding from NSF EIA-0196217.

- [大学の利用条件](https://mocap.cs.cmu.edu/) はゲームを含む商用製品への収録を許可し、変換形式を含むデータ自体の転売を禁止している。[FAQ](https://mocap.cs.cmu.edu/faqs.php) には複製、加工、再配布の許諾がある。
- [公式の試技一覧](https://mocap.cs.cmu.edu/search.php?subjectnumber=16)。[16_16.c3d 歩行](https://mocap.cs.cmu.edu/subjects/16/16_16.c3d) と [16_35.c3d ジョギング](https://mocap.cs.cmu.edu/subjects/16/16_35.c3d) を使用。SHA256 は順に ca7969100f047f5f57e7de6221f548efe0a35e0ada5288f6d1621cac1a9ae1f3、46215b4bafc12c9d37911e4a56099dbd667696fdbf1d191bec0d10adc0f8b0bf。

120 Hz の記録から、歩行はファイル先頭を0とする110–256フレーム、走行は45–142フレームを切り出した。走行では右踵の周期を使い、左踵が前に出る95フレームを位相0に合わせた。骨盤を基準に、肩・肘・手首、踵・足首・つま先の位置から屈伸・前後傾と進行方向の変位を算出した。両端の姿勢差を周期両端の14%で吸収し、64点の線形補間テーブルにした。歩行の一周期は1.217秒、1.241 m、ジョギングは0.808秒、2.281 m。ゲームでは移動した距離に合わせて位相を進め、歩幅は既存の俳優・ゲーム速度に合わせる。左右の脚は個別に収録した足首の軌道へIKで合わせる。停止時は既存ポーズへの減衰、歩行と走行の切替には0.2秒の補間を使用する。

再生成はPython、NumPy、ezc3d 1.7.2で行う。C3D 2本を同じフォルダに保存し、以下をアプリの日付フォルダで実行する。

```sh
python art-source/mocap/extract.py PATH_TO_C3D Game/Assets/Resources/KinseiMotion/Cycles.json
python art-source/mocap/check_contact.py Game/Assets/Resources/KinseiMotion/Cycles.json
```

接地比較は定速直進の幾何学モデル。左右別に、歩行位相11.5〜40.5%、走行12〜21.5%（ロック解除の補間を除く）で、靴底ターゲットの地面に対する前後変位幅を測定した。旧式は歩行43.72 mm、走行34.27 mm、新式の固定接地点は左右とも0.00 mm。標準体型の矢状面上で脚長超過は0.00 mm。これは接地制約の目標値で、Unityの最終メッシュを実測した滑り量ではない。方向転換、停止遷移、非均一スケールの体型、左右軸の誤差はこの計算の対象外。
