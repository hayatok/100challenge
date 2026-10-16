# 箱庭日本のアートと地理

## 新しい描画

旧配置パズルのタイル・建物SVGを再利用せず、`app/src/renderer.js` にCanvas2Dの箱庭を新規制作した。全景は実際の日本列島の輪郭へ12の架空町を配置し、町の拡大は不規則な紙の地面に家、田畑、学校、工場、水道、商店を置く。マス目・配置可能タイル・勝敗・予算の図形は持たない。

海 `#d8e9e7`、陸 `#c8d9aa`、輪郭 `#42584b`、朱屋根 `#b85744`、淡い屋根 `#d47b5b`、木材 `#c9ad7e`、クリーム壁 `#f2e7c9`、樹木 `#759b67` / `#4b795b`、川 `#8bbcc0`。印刷した博物館の紙模型のように、薄い輪郭、自然な面の明暗、足元だけの淡い影で統一する。家の窓・玄関、庇と商品、工場の鋸屋根と煙突、学校の時計と旗、高架水槽、米俵、田の畝、樹木の幹を描き分ける。

人、通学人影、車、バス、列車、帆船、工場の煙、波と木の揺れは呼出元の時計で動く。人物や建物の数、人物の同一性、史実と原値は描画側で変えない。草木・山・川・鉄道・船・乗用車は作者が作った背景であり、実際の路線やその町の史実の復元ではない。建物形状の年による差も模型の演出である。

## 地理の出典

Natural Earth公式リポジトリの1:50m admin-0 countriesから `ADMIN=Japan` を抽出した。全34ポリゴンと全リングを保持し、座標だけ小数5桁へ丸めた。依存追加・形状の間引き・手作業での国土の描き直しは行わない。

- 公式データ：[nvkelso/natural-earth-vector](https://github.com/nvkelso/natural-earth-vector)
- 取得ファイル：[ne_50m_admin_0_countries.geojson](https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_admin_0_countries.geojson)
- ライセンス：[Natural Earth Terms of Use](https://www.naturalearthdata.com/about/terms-of-use/)。2026-10-16に一次資料でpublic domainを確認。
- 取得元SHA-256：`3e458fc036ad0a66411f2c1e6cac49c5d7bfb81cb1123bc513b22511a2b7fdeb`
- 抽出後SHA-256：`99d09c80bd40769cd970de09ebd091da53bfaf34c04cffc1c1db26cd81d808dc`

地図は経緯度の単純な平面投影で、経度方向へ `cos(36°)` を掛ける。主な表示範囲は東経125〜147度・北緯24〜46度周辺に合わせ、遠方の離島の一部は画面の外に出る。ソースGeoJSONから離島を削除してはいない。面積・距離・人口密度を測る地図ではない。

**現在の日本列島の地形輪郭を参照しており、1900年その他の年の政治領域、国境の変遷、領有の主張を示す歴史地図ではない。** 政府統計ではない。12地域の町の中心、山並み、川、建物の位置は作者設定であり、地域人口・実際の施設・地形を推計していない。再利用用帰属は `app/assets/map-attribution.txt` に記録し、静止カバー `app/assets/japan-cover.svg` も同じ輪郭と自作図形を使う。

## モデルから見た目への対応

全国の原値と観測年を守るのは `model.js`。描画はモデルが作った `snapshot.world` と各町の `visual` を使う。

| 信号 | 拡大画面で見えるもの | 留意点 |
| --- | --- | --- |
| population | `world.people` の架空住民の数と歩行 | 出生死亡・人物の運命を全国値から抽選しない |
| industry | `farm` の田畑と畝、`factory` の工場と煙 | 農業と製造業の模型。全産業の比率ではない |
| housing | `house` の軒数、`lit=false` の暗い窓 | 空き家の模型配置は作者設定 |
| water | `water` の高架水槽と給水管 | 電化率・水道全体の普及率へ変換しない |
| education | `school` の校舎、`visual.students` の学校前の通学群 | 通学群は匿名模型で、追跡する架空家系から分離 |
| rice | `rice` 1個に米俵を1俵 | 供給純食料の縮尺模型。摂取量・購入量ではない |
| prices | 商店の「指数 XX.X」札 | 円や商品の価格として表示しない |
| bus | `world.vehicles` のバス | 輸送人員を作者の台数へ縮尺した模型で実車数ではない |

全景では住宅2軒を1つの小さな家へ縮め、通学群も2人影を1人影へまとめる。町の拡大では `world.buildings` の建物を描き、通学群もモデル数を描く。町の拡大は人・建物を奥行き順に並べ、追跡対象は足元の楕円と頭上の朱色の印で識別する。各町の人はモデルの `from` / `to` 間を動き、選択で架空人物のIDを親へ返す。全国統計を町ごとの実測値と呼ばない。

## API・操作・文字

`createRenderer(canvas, { geometry, onPlaceSelect, onPersonSelect, onViewChange })` を名前付きexportし、`{ render, resize, destroy }` を返す。

- `render(snapshot, elapsedSeconds, { view:'japan'|'place', placeId, selectedPersonId, reducedMotion })`。呼出元のrAFで実行する。内部にタイマーを持たない。
- `resize()`。CanvasのCSSサイズと端末比率へ合わせる。描画倍率は2倍まで。
- `destroy()`。クリックとpointermoveの登録を外す。
- 全景の町・地域名はクリックで `onPlaceSelect(id)` と `onViewChange('place', id)`。町の追跡可能な人は `onPersonSelect(id)`。

Canvas内の文字は海名、地域名、町名、店の指数札だけ。観察の案内はHTMLの説明にまとめ、Canvas底部へ重ねない。全景の地名は紙色の面と墨色の字、選択地域は朱の字と町の楕円。ラベルの衝突と親UIの右上切替領域を避け、動く船や列車より前面に描く。日本海の文字は年表示と重ならないよう左中央の高さ40%に置く。HTMLの見出し、統計、再生・停止・速度、出典、人物記録は親UIが担当し、共通 `--ui-*`、16px/1.6の本文、44px操作面、2px輪郭、3pxフォーカスを使う。Canvasの小さな絵だけを唯一の操作手段としない。

`reducedMotion=true` では描画の時計を0に固定する。停止・フォーカス喪失・速度変更では親が時計の進行を管理する。外部フォント、外部画像、画像生成、追加npm依存を含まない。

## 単体確認

2026-10-16：Node構文チェックと、実model snapshotの1900/1955/2000/2026年×全景/拡大の8通りをCanvasコマンド記録アダプタで通した。静止描画をSVG・PNG化し、輪郭、工場、学校、米俵、水道、通学群、町と地域名を目視確認した。確認中に建物座標の乱数相関を発見し、モデル担当がhashの攪拌を修正した。カバーSVGもPNG化して目視した。

この記録は静止図形・APIの単体確認であり、ブラウザのCanvas実描画、端末幅、実際の停止・移動・追跡・入力、音や全体の観察体験の確認を代用しない。主担当が統合画面で確認する。
