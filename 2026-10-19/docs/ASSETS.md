# 素材と出典

第2版の魔女と敵3種は、組み込みのimage_genでこのゲーム向けに生成した透過PNGです。`game/assets/art/witch-r2.png`、`hound-r2.png`、`charger-r2.png`、`archer-r2.png`を使います。一度ドット絵へ移した戦闘描画も、今回この原画へ戻し、部位ごとのメッシュ変形で動かしています。保存した画像を目視で確認し、ミップマップを有効にして縮小表示します。生成時のプロンプトは[art-prompts.json](art-prompts.json)に保存しています。

石畳の`garden-r2.svg`、月、魔法の印、庭園の地紋は編集可能なSVGまたはGodotの2D描画です。初版の魔女と敵のSVGは原稿として残しています。効果音と静かな夜の音楽はゲーム内で合成したPCMです。実行中に画像生成や外部通信は行いません。

日本語フォントは既存の`2026-10-14/game/assets/fonts/NotoSansCJKjp-Medium.otf`を変更せずコピーし、同じフォルダのSIL Open Font License 1.1を同梱しています。素材のSHA-256は`assets-manifest.json`に記録します。

Godot 4.7.2はMIT Licenseです。全文は`docs/licenses/GODOT-LICENSE.txt`。Web出力には`credits.html`、Godotのライセンス、フォントのOFLを同梱します。

`docs/reference/play-layout.svg`は初版の配置見本です。第2版の画面比較は`docs/verification/`の実スクリーンショットで行い、設計用画像と実プレイの記録を区別します。

## 本編の追加素材

ボス3体は`boss-thorn.png`、`boss-mirror.png`、`boss-bell.png`、背景画は`campaign-keyart.png`です。組み込みのimagegenでこのゲーム向けに生成しました。透過の有無と保存画像を確認し、生成時のプロンプトは[art-prompts-campaign.json](art-prompts-campaign.json)、寸法とハッシュは[検証記録](verification/campaign/art-source.json)に残します。ボスのPNGは現在の戦闘にも使い、部位ごとのメッシュ変形で動かしています。背景画は引き続きタイトルで使います。

見出しは[Zen Old Mincho Boldの公式配布](https://github.com/google/fonts/tree/6c4ff7159f6296ebd06b92d8010b086fcb795409/ofl/zenoldmincho)から取得し、変更せず同梱しています。SIL Open Font License 1.1は`game/assets/fonts/ZEN-OFL.txt`。元のコミットとファイルのSHA-256は[font-source.json](verification/campaign/font-source.json)に記録します。

章別3曲とボス戦1曲の音楽は`game/assets/audio/theme-*.wav`。外部の録音素材を使わず、`scripts/generate-audio.py`で音を合成します。32拍のフレーズに和音、鐘、旋律を重ね、PCMのループとして保存しています。音の生成条件とハッシュは[audio-source.json](verification/campaign/audio-source.json)を参照してください。効果音は`soundscape.gd`内の合成で、音量と停止に従います。

読み込み画面も作品の藍色、骨白、金の役割色を使います。文字と主操作のコントラストを保つため、共通UIの明るい面色から変更しています。ゲーム内の見出しは明朝体、本文はNoto Sans CJK JP、数字は読み分けられる配置と字間を使います。

共有の白い円は`white-disc.svg`としてコードで作成した。影、小さい粒子、円の塗りに同じテクスチャを使い、毎フレームの図形の生成を減らしている。床と障害物の絵は既存の形と配色から作り、章ごとの描画を保持する。

## ドット絵の原稿と反応

`game/assets/art/pixel-actors-*.svg`は、魔女、通常敵6種、ボス3種のオリジナル素材です。既存画像の加工や外部素材のコピーは行わず、`scripts/generate-pixel-actors.py`に格子上の部品と配色を定義しました。脚、腕、本、翼、弓、盾、炎、枝、鏡片、鐘舌の位置をフレームごとに変え、各36フレームを一枚に並べています。通常は64px、ボスは96pxのセルです。Python標準ライブラリだけでSVGを再生成できます。

`pixel-fx.svg`は火花、破片、砂煙、魔法陣など10図柄のオリジナルSVGです。整数の輪郭を一枚のアトラスに並べ、同じ描画リソースを繰り返し使います。現在は火花と破片の`pixel-fx.svg`だけnearestを指定します。以前の人物アトラスは原稿として残しています。

命中、撃破、足音、防護、第二形態の短い音も`soundscape.gd`内で合成します。外部の録音は使わず、再生間隔と音量を分けて密度を抑えます。音楽を始める状態管理は本編と同じです。

動作フレームを並べた画像はネイティブ描画の配置見本、Webのキー入力で記録した画面と映像は実操作の証拠として区別します。検証と素材のSHA-256は[モーションの記録](verification/MOTION.md)を参照してください。

## 今回の手描き素材

三章の地形は`terrain-painted-r3.png`、障害物は`scenery-painted-r3.png`です。コウモリは`bat-painted-r3.png`、守衛は`sentinel-painted-r3.png`、鬼火は`creatures-painted-r3.png`の右端を使います。最初の敵シートではコウモリと守衛が横に重なったため、この2種を個別に生成し直しました。シートの左と中央は描画に使いません。

魔法6種と遺物12種は`items-painted-r3.png`、章の印と報酬は`rewards-painted-r3.png`、開封後の宝箱は`chest-open-painted-r3.png`です。全て組み込みimagegenでこの作品向けに生成しました。外部の素材パックは導入していません。画像へ名前や説明を焼き込まず、Godotの文字と状態表示を重ねます。

生成プロンプトと原本の保存先は[art-prompts-r3.json](art-prompts-r3.json)、同梱原本の寸法・透過・SHA-256は[art-source.json](verification/art-upgrade/art-source.json)に記録します。庭園の床は明るい花びらと小石を除くようimagegenで編集し、編集前の原本も`docs/reference/terrain-r3-source.png`に残しました。同梱する画像の画素はローカルで加工せず、実際の輪郭に合わせた領域をGodotで切り出します。各キャラクターの36姿勢は1枚の原画を変形する描画資源であり、36枚の生成画像ではありません。画像は起動前に同梱し、実行中の外部通信は追加していません。
