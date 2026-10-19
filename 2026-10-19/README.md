# 残響の魔女

2秒前の位置と攻撃を再現する残像と、夜の庭園で大群を倒す3分の見下ろし2Dサバイバル。Sol maxでゲーム本体を実装した試作です。

## 遊び方

- WASDまたは矢印キーで移動。攻撃は自動です。
- 経験値を拾ってレベルアップし、数字1〜3またはクリックで強化を選びます。選択中は時間が止まります。
- 雷と月輪を強化して、3分間生き残ればクリア。HPがゼロになると敗北です。
- Escでポーズ。フォーカスを外した場合も停止し、明示操作で再開します。
- 本体は白い帽子と実線の輪、残像は淡い青と点線の輪。被弾するのは本体だけです。
- PCのキーボード操作が対象です。タッチ操作は未対応です。

## 開発

Node.js 24、Godot 4.7.2とWeb出力用テンプレートを使います。JavaScriptの追加依存はありません。

```sh
npm ci
npm run setup
npm run check
npm run preview
```

ブラウザで http://127.0.0.1:4197/ を開きます。`npm run dev`はGodotエディタ、`npm run play`はネイティブ起動です。`GODOT_BIN`でGodot 4.7.2の実行ファイルを指定できます。macOSでは既存のGodot.app、Linux x64では公式アーカイブを使います。新規ダウンロードは公式SHA-512と照合します。

## 検証資料

仕様は[docs/SPEC.md](docs/SPEC.md)、画面と素材の方針は[docs/ART_DIRECTION.md](docs/ART_DIRECTION.md)。配置見本の[docs/reference/play-layout.svg](docs/reference/play-layout.svg)は設計用であり、実際のプレイ画面ではありません。検証結果と実画面は[docs/verification/RESULTS.md](docs/verification/RESULTS.md)へ記録します。

Web上の`window.echoWitchSnapshot`は検証用の状態読取です。ゲームの時刻やHPを変える機能はありません。ブラウザ検証には別途PlaywrightとChromiumが必要です。`npm run qa:browser`で通常速度の3分プレイと画面・停止・リトライを検査します。Playwrightを別の場所に置いている場合は、`PLAYWRIGHT_MODULE`にその`index.mjs`、`CHROMIUM_BIN`にブラウザの実行ファイルを指定してください。

素材とフォントの出典は[docs/ASSETS.md](docs/ASSETS.md)と`credits.html`を参照してください。
