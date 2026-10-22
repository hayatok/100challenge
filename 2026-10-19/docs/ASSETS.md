# 素材と出典

第2版の魔女と敵3種は、組み込みのimage_genでこのゲーム向けに生成した透過PNGです。実行時は`game/assets/art/witch-r2.png`、`hound-r2.png`、`charger-r2.png`、`archer-r2.png`を使います。保存した画像を目視で確認し、ミップマップを有効にして縮小表示します。生成時のプロンプトは[art-prompts.json](art-prompts.json)に保存しています。

石畳の`garden-r2.svg`、月、魔法の印、庭園の地紋は編集可能なSVGまたはGodotの2D描画です。初版の魔女と敵のSVGは原稿として残しています。効果音と静かな夜の音楽はゲーム内で合成したPCMです。実行中に画像生成や外部通信は行いません。

日本語フォントは既存の`2026-10-14/game/assets/fonts/NotoSansCJKjp-Medium.otf`を変更せずコピーし、同じフォルダのSIL Open Font License 1.1を同梱しています。素材のSHA-256は`assets-manifest.json`に記録します。

Godot 4.7.2はMIT Licenseです。全文は`docs/licenses/GODOT-LICENSE.txt`。Web出力には`credits.html`、Godotのライセンス、フォントのOFLを同梱します。

`docs/reference/play-layout.svg`は初版の配置見本です。第2版の画面比較は`docs/verification/`の実スクリーンショットで行い、設計用画像と実プレイの記録を区別します。

## 本編の追加素材

ボス3体は`boss-thorn.png`、`boss-mirror.png`、`boss-bell.png`、背景画は`campaign-keyart.png`です。組み込みのimagegenでこのゲーム向けに生成しました。透過の有無と保存画像を確認し、生成時のプロンプトは[art-prompts-campaign.json](art-prompts-campaign.json)、寸法とハッシュは[検証記録](verification/campaign/art-source.json)に残します。ボスは元画像の縦横比を保って描きます。

見出しは[Zen Old Mincho Boldの公式配布](https://github.com/google/fonts/tree/6c4ff7159f6296ebd06b92d8010b086fcb795409/ofl/zenoldmincho)から取得し、変更せず同梱しています。SIL Open Font License 1.1は`game/assets/fonts/ZEN-OFL.txt`。元のコミットとファイルのSHA-256は[font-source.json](verification/campaign/font-source.json)に記録します。

章別3曲とボス戦1曲の音楽は`game/assets/audio/theme-*.wav`。外部の録音素材を使わず、`scripts/generate-audio.py`で音を合成します。32拍のフレーズに和音、鐘、旋律を重ね、PCMのループとして保存しています。音の生成条件とハッシュは[audio-source.json](verification/campaign/audio-source.json)を参照してください。効果音は`soundscape.gd`内の合成で、音量と停止に従います。

読み込み画面も作品の藍色、骨白、金の役割色を使います。文字と主操作のコントラストを保つため、共通UIの明るい面色から変更しています。ゲーム内の見出しは明朝体、本文はNoto Sans CJK JP、数字は読み分けられる配置と字間を使います。

共有の白い円は`white-disc.svg`としてコードで作成した。影、小さい粒子、円の塗りに同じテクスチャを使い、毎フレームの図形の生成を減らしている。床と障害物の絵は既存の形と配色から作り、章ごとの描画を保持する。
