# 金星の専属歌手と伴奏者

針音堂の[『夜の椿』と『三人の乾杯』](../printworks/README.md)を衣装の基準にした。歌手の暗いボルドーのバイアスドレスは襟元に三段の折り返しを作り、裾には金糸の細い縁を通した。髪には赤い椿の花櫛、耳には真珠を二粒ずつ付けた。ピアニストは象牙色のディナージャケットと濃紺のパンツを着る。

[衣装と手の制作時の寄り](fitting.jpg)は実際に読み込む頭部・髪・衣装・手をBlenderに配置した素材確認。撮影用の楽器は実寸の簡略模型を用い、ゲーム画面はアプリの evidence に収録する。

## 素材と加工

- 歌手の頭部は [MakeHuman core の固定版](https://github.com/makehumancommunity/makehuman/tree/a8bc2d54ff0ac92e78ff71431b1023eda42bf482/makehuman/data)。CC0 の female average muscle / average weight と Asian female young / old を使用した。若年64%、老年36%の形状を混合し、頬の厚みと顎先を別に調整した。瞼の開口から眼球位置を合わせ、肌のUV上に眉を描いた。
- 肌は OnlyTheGhosts の [Young Eurasian Female](https://www.makehumancommunity.org/node/1578)（CC0）。[元の素材記録](skin-source.json)を添付した。顔・首と手だけを既存UVから切り出した。
- 歌手のウェーブ、椿の花櫛、真珠、ドレス、編み目と金糸の画像は本作のために制作した。服を11本の既存ボーンにウェイト付けし、髪飾りとイヤリングは頭に追従させた。伴奏者の衣装は [既存のToigo製スーツ](../wardrobe/SOURCES.md)の上衣とズボンをUV領域で染め分けた。伴奏者の頭部・髪・手、角膜と虹彩は[既存のキャスト原型](../cast/README.md)を利用した。
- 歌手の息継ぎと口の開閉、ピアニストの手、椅子からの離席と退避は本作用に制作した手続きアニメーション。1コーラス16小節・四分音符76 BPMのワルツの再生時刻を受け取る。伴奏の指先は実際の鍵盤の上面を目標にし、メッシュから測った屈曲後の指先と手首のずれを引いて肘を解く。退避時の歩きは既存のキャスト歩行を使う。

## 再制作と寸法確認

頭部用の元ファイルとターゲットの取得方法は[住民の制作記録](../residents/README.md)を参照。head.py の引数は base.obj、ターゲットのディレクトリ、human_parts.json、展開済み skins01/skins、出力先、作業用 heads.json。これをキャストの build_human_parts.py で1段細分化して OBJ に書き出す。coiffure.py と gown.py は出力ディレクトリ、brows.py は同じ出力ディレクトリを2回、dinner_jacket.py は KinseiWardrobe と出力ディレクトリを取る。出力後は Unity のインポート設定を含む .meta を保持する。

reach.py に Game/Assets/Resources/KinseiAudio/StageScore.json を渡すと、鍵盤の上面が8 mm動く両端、上体の揺れ、左右の指先オフセットの幅を含めて距離を計算する。全16小節で肩から手首までの最大距離は左30.5 cm、右35.5 cm。マイク把持は22.2 cm。腕の上限は52.0 cm、左右の着鍵点は最も近いときも21.0 cm離れる。首とカウル襟の隙間は寄り撮影後、襟の下に生地を足して閉じた。これらの値は実寸の幾何計算。舞台での外見と状態遷移はWindowsプレイヤーで確認する。

CPUでの衣装検査は Blender のバックグラウンドモードで fitting.py を呼び、Game/Assets/Resources、KinseiStage、既存の出力ディレクトリをこの順に渡すと再撮影できる。
