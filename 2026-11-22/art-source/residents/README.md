# 澄子と村瀬の頭部

[制作時の寄り画像](portraits.jpg)は上段が澄子、下段が村瀬。各段とも正面、斜め、後頭部を同じ照明で撮影した。Blender 5.3 の CPU Cycles に頭部、髪、目を配置した素材検査画像で、下端は衣装に埋める首の裁断面。

## 原典

- 頭部は MakeHuman の [core base.obj と macrodetails](https://github.com/makehumancommunity/makehuman/tree/a8bc2d54ff0ac92e78ff71431b1023eda42bf482/makehuman/data) を使用した。元メッシュと3件の target は CC0。肌は OnlyTheGhosts 作 [Old Eurasian Female](https://www.makehumancommunity.org/node/1580) と [Middle Aged Eurasian Female](https://www.makehumancommunity.org/node/1579)。[公式 skins01 CC0 pack](https://files.makehumancommunity.org/asset_packs/skins01/skins01_cc0.zip) のメタデータを [skin-sources.json](skin-sources.json) に抜粋した。
- 元メッシュの UV と顔・首の裁断位置を引き継いでいる。澄子には Asian female old を 86%、村瀬には 24% 混合し、残りを Asian female young とした。両者に universal female young average muscle / average weight の形状を適用した。澄子は口角を左右非対称に上げ、村瀬は眉頭を内側へ下げた。
- 2048 px の肌に原典の頬・小鼻の色むらと瞼の色差を残し、眉毛だけを個別に描いた。顔・首・手の UV だけを抽出した。茶色の虹彩と角膜は既存キャストの眼資産を共用し、2人の個別頭部に合わせて球面の中心を調整した。
- 髪は頭皮を採寸し、澄子の顎先で内巻きになる銀灰色のボブと、村瀬の後頭部で髪を束ねたシニヨンを制作した。毛流れを色、断面、先端の透過に分けて表現した。

## 再制作

1. リンク先の MakeHuman 固定版から base.obj と macrodetails の asian-female-young.target、asian-female-old.target、universal-female-young-averagemuscle-averageweight.target を取得する。skins01 を展開する。
2. Python、NumPy、Pillow で heads.py に順に base.obj、target のディレクトリ、Game/Assets/Kinsei/Cast/Source/human_parts.json、展開した skins ディレクトリ、出力ディレクトリ、作業用 heads.json を渡す。
3. 既存の Game/Assets/Kinsei/Cast/build_human_parts.py の subdivision / OBJ export を heads.json に対して実行する。書き出し時の前方軸は Y、上方軸は Z。既存キャストのメートル単位と同じ。
4. hair.py に出力ディレクトリを渡す。brows.py には同じ出力ディレクトリを2回渡す。スキンに眉を重ねるため、再実行時は手順2で肌を再生成する。
