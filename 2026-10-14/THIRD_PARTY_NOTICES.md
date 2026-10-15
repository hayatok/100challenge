# 全力退勤：クレジット

ゲーム内の3Dモデルは、このアプリの制作スクリプトでBlender 4.3.2を使って作成し、GLBとして配布しています。漫画表示、粒子の動き、効果音とBGMはアプリのコードで生成しています。コンセプトアート、画面モックとモデルの3視点参考画像は画像生成ツールによる制作資料で、実行時のテクスチャに含めていません。

モデル内の判子などの文字もNoto Sans CJK JPからメッシュ化しています。同フォントのライセンスをWeb配布へ同梱します。

## Godot Engine 4.6.3

Godot Engine contributors / Juan Linietsky / Ariel Manzur。MIT License。

エンジン本体と組み込みライブラリの通知は [GODOT-LICENSE.txt](docs/licenses/GODOT-LICENSE.txt) に保存しています。Web配布では `licenses/GODOT-LICENSE.txt` として同梱します。

## Noto Sans CJK JP

Noto Fonts / Adobe。日本語の表示に `NotoSansCJKjp-Medium.otf` を使用しています。SIL Open Font License 1.1。

v0.5の大きい見出しには、Noto Sans CJK JP Black 2.004から必要な文字を抽出して改名した `TaikinComic-Black.otf` を使用しています。変更はサブセット化とファミリー名・PostScript名の改名で、原本の著作権とライセンス情報を保持しています。出典とSHA-256は [DISPLAY_FONT.json](game/assets/fonts/DISPLAY_FONT.json)、再生成は `npm run assets:font`（PythonのfontToolsが制作時だけ必要）。通常の起動・CI・配布にfontToolsは不要です。

ライセンス全文は [LICENSE.txt](game/assets/fonts/LICENSE.txt)。Web配布では `licenses/NOTO-OFL.txt` として同梱します。
