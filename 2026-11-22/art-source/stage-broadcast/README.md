# 金星の舞台と実況卓

舞台奥の意匠は[俯瞰の設定画](../club-two-views/stage-overlook.png)と[肩越しの設定画](../club-two-views/stage-shoulder.png)を参照した。既存舞台の比較用撮影は[指揮画面](../../evidence/v06/tv-map-stage.png)と[舞台の肩越し](../../evidence/v06/amber-stage.png)。画像は看板に貼り込まず、扇板・縁・字・ガラス・幕を別の三角形で組んでいる。

[CPU形状図](geometry.jpg)の左は客席側の俯角10度、右は指揮カメラと同じ俯角58.57度で正投影したもの。実際の発光、ベルベットの陰影、前景の人物と卓はWindows版で確認する。図は同じ頂点と面から深度判定で描いた。

- 九枚の押し出し扇板のうちわ骨の間に草花の彫り目を配置。27個の乳白球には一個ずつ真鍮の二段口金を組んだ。框の15灯は高さ84 mm、約398 mm間隔。各灯の発光には共有材質を使用する。
- 金文字は各文字の高さ910 mm、表の厚さ40 mm。舞台奥の基準点は世界座標 (−5, 2.99, 5.34) m。正面を客席と上方に36度傾け、文字の穴を抜いて側壁と八本の支柱を設けた。舞台のマイク根元は (−5, .48, 3.4) m、ピアノは舞台右に残る。袖幕は左右のひだと上部の三連の垂れで構成した。
- 実況卓は (−1.90, 0, 1.05) m、幅720 mm、奥行400 mm、天板上面890 mm。操作面は (−1.35, 0, .70) m の係員を向く。立会人の足までは卓中心から1.42 m。赤い呼出球と監視管、舞台の框灯と扇縁の明るさは World.SetStageBroadcast(bool live) で切り替える。監視管の試験図は既存の KinseiDistrictArt/relay-test を流用。
- 看板、額縁、幕、框灯を合計12,488三角形、7材質で既設の静的バッチに渡す。実況卓は別。追加のカメラ、毎フレームのメッシュ更新はない。実行時のドロー数はカメラ・影パスに依存する。

実況係は卓に着くと、両足を止め、左手の親指と人差し指で、管面から遠いつまみに付いた幅9 mmの指掛けを挟む。0.65秒から1.22秒までに指掛けが68度回り、真壁がマイクを開けるようになる。係員は1.82秒で手を引く。係員から見て右の管面には、待機時に試験図を出す。放送中は舞台のカメラの映像に切り替わり、赤い送出灯が点く。[手の設計画](../broadcast-listeners/desk-hand.png)・[実況卓の実機画像](../../evidence/v13/voice-end-air.png)。

## 再生成

リポジトリルートで次を実行する。Pythonに numpy、Pillow、fonttools、shapely、mapbox-earcut が必要。

```powershell
python 2026-11-22/art-source/stage-broadcast/build.py 2026-11-19-2/Game/Assets/Resources/UI/NotoSansJP.ttf 2026-11-22/Game/Assets/Resources/KinseiStageBroadcast --proof 2026-11-22/art-source/stage-broadcast/geometry.jpg
```

- 新作の形状、彫刻模様、口金、配色と組立は本作専用の設計。既存の velour_velvet 材質は本作の従来のライセンス表に従う。
- 字形のみ Noto Sans JP、SIL Open Font License 1.1。[ライセンス全文](NotoSansJP-OFL.txt)。書体 SHA-256 は B884B21256C0679BF8AA055BA7D5960231CD07EDAD83802F0AF6B2D0F444EB13。
- StageSign.bytes は E80FF1BC9DBE01C5C4F3F8830BDD23850FDC002F00729BF0B94E78D5A38AB977、EtchedLeaves.jpg は CD24DD9823878C9AAF51D20FA6C26B405D8CD121DA7A48F7C741C940CE65B363（SHA-256）。
