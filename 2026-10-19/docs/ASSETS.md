# 素材と出典

第2版の魔女と敵3種は、組み込みのimage_genでこのゲーム向けに生成した透過PNGです。実行時は`game/assets/art/witch-r2.png`、`hound-r2.png`、`charger-r2.png`、`archer-r2.png`を使います。保存した画像を目視で確認し、ミップマップを有効にして縮小表示します。生成時のプロンプトは[art-prompts.json](art-prompts.json)に保存しています。

石畳の`garden-r2.svg`、月、魔法の印、庭園の地紋は編集可能なSVGまたはGodotの2D描画です。初版の魔女と敵のSVGは原稿として残しています。効果音と静かな夜の音楽はゲーム内で合成したPCMです。実行中に画像生成や外部通信は行いません。

日本語フォントは既存の`2026-10-14/game/assets/fonts/NotoSansCJKjp-Medium.otf`を変更せずコピーし、同じフォルダのSIL Open Font License 1.1を同梱しています。素材のSHA-256は`assets-manifest.json`に記録します。

Godot 4.7.2はMIT Licenseです。全文は`docs/licenses/GODOT-LICENSE.txt`。Web出力には`credits.html`、Godotのライセンス、フォントのOFLを同梱します。

`docs/reference/play-layout.svg`は初版の配置見本です。第2版の画面比較は`docs/verification/`の実スクリーンショットで行い、設計用画像と実プレイの記録を区別します。
